const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {Disc}=require('./disc.cjs'),{readSadAudio,readSequenceAudio}=require('./cutscene-audio.cjs');
test('original SAD XA sectors retain stereo format and exported PCM',{skip:!process.env.CROC_BACKUP||!process.env.CROC_CONTENT},()=>{
  const disc=new Disc(process.env.CROC_BACKUP),root=process.env.CROC_CONTENT;
  try{
    const source=readSadAudio(disc),manifest=JSON.parse(fs.readFileSync(root+'/manifest.json')),asset=manifest.cutsceneAudio[0];
    assert.equal(source.record.sectors,207);assert.equal(source.record.firstSector,7);assert.equal(source.record.lastSector,1655);
    assert.equal(source.record.channels,2);assert.equal(source.record.sampleRate,37800);assert.equal(source.record.emphasis,false);
    assert.equal(source.record.frames,417312);
    assert.ok(fs.readFileSync(root+'/'+asset.compressedFile).equals(source.compressed));
    assert.ok(fs.readFileSync(root+'/'+asset.file).subarray(44).equals(source.pcm));
    assert.equal(asset.rawSha256,source.record.rawSha256);assert.equal(asset.pcmSha256,source.record.pcmSha256);
  }finally{disc.close();}
});

test('every cinematic retains original stereo XA bytes, continuous predictor history and sector timing',{skip:!process.env.CROC_BACKUP||!process.env.CROC_CONTENT},()=>{
 const root=process.env.CROC_CONTENT,manifest=JSON.parse(fs.readFileSync(root+'/manifest.json')),disc=new Disc(process.env.CROC_BACKUP);
 try{
  assert.equal(manifest.cutsceneSequenceAudio.length,21);
  for(const asset of manifest.cutsceneSequenceAudio){
   const source=readSequenceAudio(disc,asset.sourcePath);
   assert.ok(fs.readFileSync(root+'/'+asset.compressedFile).equals(source.compressed),asset.name);
   assert.ok(fs.readFileSync(root+'/'+asset.file).subarray(44).equals(source.pcm),asset.name);
   assert.equal(asset.firstSector,7);assert.equal(asset.lastSector,7+(asset.sectors-1)*8);
   assert.equal(asset.frames,asset.sectors*2016);assert.equal(asset.channels,2);assert.equal(asset.sampleRate,37800);
   assert.equal(asset.rawSha256,source.record.rawSha256);assert.equal(asset.pcmSha256,source.record.pcmSha256);
  }
 }finally{disc.close();}
});
