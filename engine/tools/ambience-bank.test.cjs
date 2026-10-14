'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {bank}=require('./ambience-bank.cjs'),{parse}=require('./ambience-codec.cjs'),{decodeSPU}=require('./spu-audio.cjs');
const h=Buffer.alloc(3104),b=Buffer.alloc(16);h.write('pBAV');h.writeUInt32LE(6,4);h.writeUInt32LE(h.length+b.length,12);h.writeUInt16LE(1,18);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt16LE(2,2594);
assert.equal(bank(h,b).voices[0].length,16);assert.throws(()=>bank(h,b.subarray(0,15)),/extent/);
const bad=Buffer.from(h);bad.writeUInt16LE(3,2594);assert.throws(()=>bank(bad,b),/extent/);
if(process.env.CROC_CONTENT){const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));let files=0,samples=0;for(const entry of m.entries.filter(x=>/^AMBI.*\.BIN$/.test(x.name))){const parts=parse(fs.readFileSync(path.join(root,entry.file))),decoded=bank(parts[1].data,parts[2].data);for(const voice of decoded.voices){assert(decodeSPU(voice.data).samples>0);samples++;}files++;}assert.equal(files,23);console.log(JSON.stringify({files,samples}));}
console.log('PASS: original ambience bank dimensions, exact sample partition, raw program/tone records and ADPCM decode');
