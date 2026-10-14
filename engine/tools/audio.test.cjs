/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {decodeSPU,wav}=require('./spu-audio.cjs');
test('ADPCM nibbles are signed and decoded low nibble first',()=>{
  const b=Buffer.alloc(16);b[0]=12;b[1]=1;b[2]=0x87;
  const d=decodeSPU(b);assert.equal(d.samples,28);assert.equal(d.pcm.readInt16LE(),7);assert.equal(d.pcm.readInt16LE(2),-8);assert.equal(d.ended,true);
});
test('Predictor history and signed saturation match fixed coefficients',()=>{
  const b=Buffer.alloc(32);b[0]=0;b.fill(0x77,2,16);b[16]=0x10;b[17]=1;b.fill(0x77,18,32);
  const d=decodeSPU(b);assert.equal(d.pcm.readInt16LE(56),32767);
});
test('Loop start and stop flags retain sample positions',()=>{
  const b=Buffer.alloc(48);b[0]=12;b[16]=12;b[17]=4;b[32]=12;b[33]=3;
  const d=decodeSPU(b);assert.equal(d.loopStart,28);assert.equal(d.loopEnd,84);assert.equal(d.repeat,true);
  const w=wav(d);assert.equal(w.toString('ascii',0,4),'RIFF');assert.equal(w.readUInt32LE(40),168);
});
test('Truncated or unsupported blocks are rejected',()=>{
  assert.throws(()=>decodeSPU(Buffer.alloc(15)),/complete/);
  const b=Buffer.alloc(16);b[0]=0x50;assert.throws(()=>decodeSPU(b),/Unsupported/);
});
if(process.env.CROC_CONTENT)test('All WAD audio exports have consistent waveform lengths and provenance',()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),samples=m.resources.filter(r=>r.type==='audio-header');
  assert.equal(m.audioSamples,2633);assert.equal(samples.length,2633);
  const banks=new Map();
  for(const s of samples){if(!banks.has(s.owner)){const entry=m.entries.find(e=>e.name===s.owner);banks.set(s.owner,fs.readFileSync(path.join(root,entry.file)));}const bank=banks.get(s.owner),meta=JSON.parse(fs.readFileSync(path.join(root,s.file)));assert.equal(meta.held,bank.readUInt32LE(s.offset+4));assert.equal(meta.reverb,bank.readUInt32LE(s.offset+8));}
  for(const s of samples){const meta=JSON.parse(fs.readFileSync(path.join(root,s.file))),b=fs.readFileSync(path.join(root,meta.file));assert.equal(b.length,44+meta.samples*2);assert.equal(b.readUInt32LE(24),44100);assert.ok(meta.loopBegin<=meta.loopEnd&&meta.loopEnd<=meta.samples);assert.match(meta.sha256,/^[a-f0-9]{64}$/);}
});
