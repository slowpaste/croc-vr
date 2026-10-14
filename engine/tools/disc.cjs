'use strict';
const fs = require('node:fs');

function safeName(name) {
  if (!/^[A-Z0-9_][A-Z0-9_.-]{0,63}$/i.test(name) || name.includes('..') || /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)/i.test(name)) {
    throw new Error(`Unsafe file name: ${name}`);
  }
  return name;
}

class Disc {
  constructor(source) {
    this.fd = fs.openSync(source, 'r');
    this.bytes = fs.fstatSync(this.fd).size;
    try {
      const pvd = Buffer.alloc(2048);
      fs.readSync(this.fd, pvd, 0, 2048, 16 * 2048);
      if (pvd.toString('ascii', 1, 6) === 'CD001') this.sectorSize = 2048;
      else this.sectorSize = 2352;
      const descriptor = this.read(16, 2048);
      if (descriptor[0] !== 1 || descriptor[6] !== 1 || descriptor.toString('ascii', 1, 6) !== 'CD001') throw Error('Not a supported ISO9660 data track');
      if (descriptor.readUInt16LE(128) !== 2048) throw Error('Unexpected logical sector size');
      this.volume = descriptor.toString('ascii', 40, 72).trim();
      this.files = [];
      this.walk(descriptor.readUInt32LE(158), descriptor.readUInt32LE(166), '/', new Set());
    } catch (e) { this.close(); throw e; }
  }
  read(lba, length) {
    if (!Number.isSafeInteger(lba) || !Number.isSafeInteger(length) || lba < 0 || length < 0 || length > 256 * 1024 * 1024) throw Error('Invalid read extent');
    if ((lba + Math.ceil(length / 2048)) * this.sectorSize > this.bytes) throw Error('Disc extent is out of bounds');
    const result = Buffer.alloc(length);
    for (let n = 0; n < length; n += 2048) {
      const b = Buffer.alloc(this.sectorSize);
      if (fs.readSync(this.fd, b, 0, b.length, (lba + n / 2048) * this.sectorSize) !== b.length) throw Error('Truncated disc sector');
      let start = 0;
      if (this.sectorSize === 2352) {
        if (b[0] !== 0 || !b.subarray(1,11).every(x => x === 255) || b[11] !== 0) throw Error('Invalid raw-sector sync');
        if (b[15] === 1) start = 16;
        else if (b[15] === 2) {
          if (!b.subarray(16,20).equals(b.subarray(20,24))) throw Error('Mismatched MODE2 subheaders');
          if (b[18] & 0x20) throw Error('FORM2 audio/video sector cannot be read as a FORM1 asset');
          start = 24;
        } else throw Error('Unsupported raw sector mode');
      }
      b.copy(result, n, start, start + Math.min(2048, length - n));
    }
    return result;
  }
  walk(lba, size, prefix, seen) {
    if (seen.has(lba)) throw Error('Directory cycle or duplicate extent');
    if (seen.size > 1024) throw Error('Too many directories');
    seen.add(lba);
    const bytes = this.read(lba, size);
    for (let p = 0; p < size;) {
      const len = bytes[p];
      if (!len) { p = (Math.floor(p / 2048) + 1) * 2048; continue; }
      if (len < 34 || p + len > size || (p % 2048) + len > 2048) throw Error('Invalid ISO directory record');
      const r = bytes.subarray(p, p + len); p += len;
      if (r[32] === 1 && r[33] <= 1) continue;
      if (33 + r[32] > len) throw Error('Truncated ISO name');
      const name = safeName(r.toString('ascii',33,33 + r[32]).replace(/;\d+$/, ''));
      const entry = {path: prefix + name, lba: r.readUInt32LE(2), size: r.readUInt32LE(10), directory: !!(r[25] & 2)};
      if (entry.lba !== r.readUInt32BE(6) || entry.size !== r.readUInt32BE(14)) throw Error('ISO extent endian copies disagree');
      if (r[25] & 0x80) throw Error('Multi-extent files are unsupported');
      this.files.push(entry);
      if (entry.directory) this.walk(entry.lba,entry.size,entry.path + '/',seen);
    }
  }
  file(name) {
    const entry = this.files.find(f => f.path.toUpperCase() === name.toUpperCase());
    if (!entry || entry.directory) throw Error(`Required file missing: ${name}`);
    return this.read(entry.lba,entry.size);
  }
  close() { if (this.fd != null) { fs.closeSync(this.fd); this.fd = null; } }
}

function sum(bytes) { let total = 0; for (const x of bytes) total = (total + x) >>> 0; return total; }
function directory(bytes, archiveSize) {
  if (bytes.length < 8) throw Error('Truncated Croc directory');
  const count = bytes.readUInt32LE(0);
  if (!count || count > 100000 || 8 + count * 24 !== bytes.length) throw Error('Invalid Croc directory length');
  if (sum(bytes.subarray(0,-4)) !== bytes.readUInt32LE(bytes.length-4)) throw Error('Croc directory checksum mismatch');
  const entries = [];
  let end = 0;
  for (let i = 0; i < count; i++) {
    const p = 4 + i * 24;
    const field = bytes.subarray(p,p+12), zero = field.indexOf(0);
    const name = safeName(field.toString('ascii',0,zero < 0 ? 12 : zero));
    if (zero >= 0 && !field.subarray(zero).every(x => x === 0)) throw Error('Nonzero filename padding');
    const size = bytes.readUInt32LE(p+12), offset = bytes.readUInt32LE(p+16);
    if (bytes.readUInt32LE(p+20) !== 0 || offset < end || offset + size > archiveSize) throw Error(`Invalid archive entry ${i} ${name}: offset=${offset}, size=${size}, previousEnd=${end}`);
    end = offset + size;
    entries.push({id:i,name,size,offset});
  }
  return entries;
}

module.exports = {Disc,directory,sum,safeName};
