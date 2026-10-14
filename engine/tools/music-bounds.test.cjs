'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {musicBounds}=require('./music-bounds.cjs');
test('music bounds reject truncated/checksum-invalid data',()=>{assert.throws(()=>musicBounds(Buffer.alloc(287)));const bad=Buffer.alloc(288);bad[0]=1;assert.throws(()=>musicBounds(bad));});
test('both original music catalogs retain all70 source end offsets',{skip:!process.env.CROC_CONTENT},()=>{const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));assert.equal(m.musicBounds.length,2);for(const record of m.musicBounds){const e=m.entries.find(x=>x.name===record.name),raw=fs.readFileSync(path.join(root,e.file)),data=musicBounds(raw);assert.deepEqual(data,JSON.parse(fs.readFileSync(path.join(root,record.file))));for(let index=0;index<70;index++)assert.equal(data.endSectorOffsets[index],raw.readUInt32LE(4+index*4));}});
