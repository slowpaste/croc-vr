'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createHash}=require('node:crypto');
const {wad}=require('./wad-codecs.cjs');
test('Original checksummed bootstrap transition triangles export without coordinate changes',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  const entry=m.entries.find(e=>e.name==='EXCLUDE.WAD'),bytes=fs.readFileSync(path.join(root,entry.file));
  const chunk=wad(bytes).chunks.find(c=>c.type==='unknown-table');
  assert.equal(chunk.offset,52256);assert.equal(chunk.length,248);assert.equal(chunk.data.count,10);
  assert.equal(createHash('sha256').update(bytes.subarray(chunk.offset,chunk.offset+chunk.length)).digest('hex'),'46507d8c3889a1d02a4ab59c64bc06aad3d18640c3061aa0937cadba17a7bc9b');
  for(let t=0;t<10;t++)for(let p=0;p<3;p++)for(let a=0;a<2;a++)assert.equal(chunk.data.triangles[t][p][a],bytes.readInt32LE(chunk.offset+4+t*24+p*8+a*4));
  const record=m.resources.find(r=>r.owner===entry.name&&r.offset===chunk.offset);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root,record.file))),chunk.data);
});
