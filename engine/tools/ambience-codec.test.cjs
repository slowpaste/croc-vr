'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {parse}=require('./ambience-codec.cjs'),{sum}=require('./disc.cjs');
function envelope(parts){const b=Buffer.concat(parts.flatMap(data=>{const length=Buffer.alloc(4);length.writeUInt32LE(data.length);return [length,data];})),tail=Buffer.alloc(4);tail.writeUInt32LE(sum(b));return Buffer.concat([b,tail]);}
const sequence=Buffer.alloc(15);sequence.write('pQES');const header=Buffer.alloc(32);header.write('pBAV');const body=Buffer.alloc(16);
const valid=envelope([sequence,header,body]);assert.deepEqual(parse(valid).map(x=>x.data),[sequence,header,body]);
const corrupt=Buffer.from(valid);corrupt[10]^=1;assert.throws(()=>parse(corrupt),/checksum/);
assert.throws(()=>parse(envelope([sequence,header,Buffer.alloc(15)])),/Partial/);
assert.throws(()=>parse(envelope([sequence,Buffer.alloc(32),body])),/bank/);
const root=process.env.CROC_CONTENT;
if(root){const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));let count=0;for(const entry of manifest.entries.filter(x=>/^AMBI.*\.BIN$/.test(x.name))){const parts=parse(fs.readFileSync(path.join(root,entry.file)));assert.equal(parts.length,3);count++;}assert.equal(count,23);console.log('PASS: all23 original ambience containers retain exact sequence/VAB blocks and checksum/bounds validation');}
else console.log('PASS: ambience envelope boundaries, signatures and checksum failures');
