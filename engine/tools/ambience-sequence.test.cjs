'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {sequence}=require('./ambience-sequence.cjs'),{parse}=require('./ambience-codec.cjs');
const header=Buffer.alloc(15);header.write('pQES');header.writeUInt32BE(1,4);header.writeUInt16BE(384,8);header.writeUIntBE(625000,10,3);header[13]=4;header[14]=2;
const bytes=Buffer.concat([header,Buffer.from([0,0x90,60,127,0x81,0,60,0,0,255,47,0])]);
const decoded=sequence(bytes);assert.equal(decoded.durationTicks,128);assert.deepEqual(decoded.events[1].data,[60,0]);assert.equal(decoded.events[1].status,144);
assert.throws(()=>sequence(bytes.subarray(0,-1)),/Truncated/);
assert.throws(()=>sequence(Buffer.concat([bytes,Buffer.from([0])])),/trailing/);
if(process.env.CROC_CONTENT){const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));let files=0,events=0;for(const entry of m.entries.filter(x=>/^AMBI.*\.BIN$/.test(x.name))){const data=sequence(parse(fs.readFileSync(path.join(root,entry.file)))[0].data);assert(data.durationTicks>0);files++;events+=data.events.length;}assert.equal(files,23);console.log(JSON.stringify({files,events}));}
console.log('PASS: original ambience tempo/tick timing, channel events, running status and exact terminal boundaries');
