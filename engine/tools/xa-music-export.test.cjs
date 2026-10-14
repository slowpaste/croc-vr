'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Disc}=require('./disc.cjs'),{state,sector}=require('./xa-audio.cjs');
test('all70 original music streams have consistent PCM WAV headers and source spans',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,index=JSON.parse(fs.readFileSync(path.join(root,'music/index.json')));
  assert.equal(index.streams.length,70);assert.equal(index.emphasisApplied,false);assert.equal(index.loopBoundsApplied,false);
  for(const stream of index.streams){const fd=fs.openSync(path.join(root,stream.file),'r');try{const header=Buffer.alloc(44);fs.readSync(fd,header,0,44,0);assert.equal(header.toString('ascii',0,4),'RIFF');assert.equal(header.readUInt16LE(22),2);assert.equal(header.readUInt32LE(24),37800);assert.equal(header.readUInt32LE(40),stream.decodedBytes);assert.equal(fs.fstatSync(fd).size,stream.decodedBytes+44);assert.equal(stream.frames,stream.sectors*2016);assert.equal(stream.lastSector-stream.firstSector,(stream.sectors-1)*8);assert.equal(stream.logical,(stream.pack-1)*7+stream.channel);}finally{fs.closeSync(fd);}}
  for(const stream of index.streams){const raw=fs.readFileSync(path.join(root,stream.compressedFile));assert.equal(raw.length,stream.sectors*2352);assert.equal(crypto.createHash('sha256').update(raw).digest('hex'),stream.sourceSha256);}
});
test('a complete exported music channel matches independent source-sector decode and hash',{skip:!process.env.CROC_CONTENT||!process.env.CROC_BACKUP},()=>{
  const root=process.env.CROC_CONTENT,index=JSON.parse(fs.readFileSync(path.join(root,'music/index.json'))),stream=index.streams[0],disc=new Disc(process.env.CROC_BACKUP),fd=fs.openSync(path.join(root,stream.file),'r');
  try{const decoder=state(),raw=Buffer.alloc(2352),pcm=Buffer.alloc(8064),hash=crypto.createHash('sha256');for(let n=0;n<stream.sectors;n++){const lba=stream.sourceLba+stream.firstSector+n*8;assert.equal(fs.readSync(disc.fd,raw,0,2352,lba*2352),2352);const decoded=sector(raw,decoder);hash.update(raw);assert.equal(fs.readSync(fd,pcm,0,8064,44+n*8064),8064);assert.ok(pcm.equals(decoded.pcm));}assert.equal(hash.digest('hex'),stream.sourceSha256);}finally{fs.closeSync(fd);disc.close();}
});
