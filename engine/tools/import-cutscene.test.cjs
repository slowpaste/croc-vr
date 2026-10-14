const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {Disc}=require('./disc.cjs'),{readCutsceneStream}=require('./cutscene-sectors.cjs'),{record}=require('./an2-records.cjs'),{pose}=require('./an2-pose.cjs');
test('private exported SAD poses match every source record',{skip:!process.env.CROC_BACKUP||!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,manifest=JSON.parse(fs.readFileSync(root+'/manifest.json'));
  const asset=manifest.cutscenePoses.find(x=>x.name==='SAD');
  const exported=JSON.parse(fs.readFileSync(root+'/'+asset.file)),models=JSON.parse(fs.readFileSync(root+'/'+asset.model)).models;
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const stream=readCutsceneStream(disc,asset.sourcePath),bytes=stream.bytes;let offset=0;
    assert.equal(exported.frames.length,asset.records);assert.equal(asset.records,291);
    assert.equal(exported.source.rawSha256,asset.rawSha256);
    for(const frame of exported.frames){
      const raw=record(bytes,offset),{stream:availability,...decoded}=frame;
      assert.deepEqual(decoded,pose(raw,models));
      assert.equal(availability.endByteOffset,raw.nextOffset);
      assert.equal(availability.requiredSectorCount,stream.dataSectorOffsets[Math.ceil(raw.nextOffset/2048)-1]+1);
      offset=raw.nextOffset;
    }
    assert.ok(exported.frames.at(-1).end);
  }finally{disc.close();}
});

test('all exported sequences retain every original model instance, part boundary and sector onset',{skip:!process.env.CROC_BACKUP||!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,manifest=JSON.parse(fs.readFileSync(root+'/manifest.json')),disc=new Disc(process.env.CROC_BACKUP);
  try{
    assert.equal(manifest.cutsceneSequences.length,21);
    for(const entry of manifest.cutsceneSequences){
      const exported=JSON.parse(fs.readFileSync(root+'/'+entry.file)),stream=readCutsceneStream(disc,entry.sourcePath);let offset=0,frames=0;
      assert.equal(exported.parts.length,entry.parts);
      for(const part of exported.parts){
        const models=JSON.parse(fs.readFileSync(root+'/'+part.model)).models;
        assert.ok(part.frames.at(-1).end,part.name);
        for(const frame of part.frames){
          const raw=record(stream.bytes,offset),{stream:availability,...decoded}=frame;
          assert.deepEqual(decoded,pose(raw,models),part.name+' byte '+offset);
          assert.equal(availability.endByteOffset,raw.nextOffset);
          assert.equal(availability.requiredSectorCount,stream.dataSectorOffsets[Math.ceil(raw.nextOffset/2048)-1]+1);
          offset=raw.nextOffset;frames++;
        }
      }
      assert.equal(frames,entry.records);
      assert.ok(stream.bytes.subarray(offset).every(value=>value===0),entry.name);
    }
    const ending=JSON.parse(fs.readFileSync(root+'/'+manifest.cutsceneSequences.find(entry=>entry.name==='OUTRO').file));
    assert.deepEqual(ending.parts.map(part=>part.frames.length),[261,191,193,131,189,141,391]);
    assert.ok(ending.parts[0].frames[0].parts.length>new Set(ending.parts[0].frames[0].parts.map(part=>part.id)).size);
  }finally{disc.close();}
});
