'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createHash}=require('node:crypto');
const {demo}=require('./demo-codec.cjs');
test('demo decoder rejects short and trailing input',()=>{assert.throws(()=>demo(Buffer.alloc(3599)));assert.throws(()=>demo(Buffer.alloc(3601)));});
test('all six original recordings retain every input word and source hash',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  assert.equal(m.demos.length,6);
  for(const recording of m.demos){
    const entry=m.entries.find(x=>x.name===recording.name),bytes=fs.readFileSync(path.join(root,entry.file));
    assert.equal(createHash('sha256').update(bytes).digest('hex'),recording.sourceSha256);
    const data=demo(bytes);assert.deepEqual(data,JSON.parse(fs.readFileSync(path.join(root,recording.file))));
    for(let tick=0;tick<900;tick++)assert.equal(data.frames[tick],bytes.readUInt32LE(tick*4));
  }
});
