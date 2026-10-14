'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {splitSector}=require('./xa-rounding-profile.cjs');
const {sector}=require('./xa-audio.cjs');
test('diagnostic rules distinguish positive predictor rounding with separate histories',()=>{
  const raw=Buffer.alloc(2352);raw.fill(255,1,11);raw[15]=2;
  Buffer.from([1,1,0x64,0x41]).copy(raw,16);raw.copy(raw,20,16,20);
  for(let group=0;group<18;group++)raw.fill(0x1c,24+group*128,40+group*128);
  const summed={history:[[1,0],[1,0]]},split=[[1,0],[1,0]];
  const original=sector(raw,summed).pcm,alternate=splitSector(raw,split);
  assert.equal(original.readInt16LE(0),1);assert.equal(alternate.readInt16LE(0),0);
  assert.deepEqual(summed.history,[[1,1],[1,1]]);assert.deepEqual(split,[[0,0],[0,0]]);
});
