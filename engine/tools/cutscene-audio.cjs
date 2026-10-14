'use strict';
const fs=require('node:fs'),path=require('node:path'),{createHash}=require('node:crypto');
const {inspectCutscene}=require('./cutscene-sectors.cjs'),{state,sector}=require('./xa-audio.cjs'),{wavHeader}=require('./import-xa-music.cjs');
function readSequenceAudio(disc,sourcePath){
  const source=inspectCutscene(disc,sourcePath),entry=disc.files.find(e=>e.path===source.path);
  const raw=[],pcm=[],decoder=state(),offsets=[];let format=null;
  for(let i=0;i<source.sectors;i++){
    const bytes=Buffer.alloc(2352);fs.readSync(disc.fd,bytes,0,2352,(entry.lba+i)*2352);
    if((bytes[18]&4)===0)continue;
    if(bytes[16]!==1||bytes[17]!==2)throw Error('Unexpected cutscene audio channel');
    const decoded=sector(bytes,decoder);
    if(format&&decoded.coding!==format.coding)throw Error('Changing SAD audio coding');
    format=decoded;raw.push(bytes);pcm.push(decoded.pcm);offsets.push(i);
  }
  if(!format||offsets.some((offset,i)=>i>0&&offset-offsets[i-1]!==8))throw Error('Invalid cutscene audio spacing');
  const compressed=Buffer.concat(raw),decoded=Buffer.concat(pcm);
  return {compressed,pcm:decoded,record:{sourcePath:source.path,sourceLba:source.lba,firstSector:offsets[0],lastSector:offsets.at(-1),channel:2,sectors:raw.length,coding:format.coding,channels:format.channels,sampleRate:format.sampleRate,emphasis:format.emphasis,frames:decoded.length/(format.channels*2),rawSha256:createHash('sha256').update(compressed).digest('hex'),pcmSha256:createHash('sha256').update(decoded).digest('hex')}};
}
function readSadAudio(disc){return readSequenceAudio(disc,'/CUTS/SAD.AN2');}
function exportSequenceAudio(disc,target,name){
  if(!/^[A-Z]+$/.test(name))throw Error('Invalid cutscene audio name');
  const audio=readSequenceAudio(disc,'/CUTS/'+name+'.AN2'),compressedFile='audio/cutscene-'+name+'.sectors',file='audio/cutscene-'+name+'.wav';
  fs.writeFileSync(path.join(target,compressedFile),audio.compressed,{flag:'wx'});
  fs.writeFileSync(path.join(target,file),Buffer.concat([wavHeader(audio.pcm.length,audio.record.sampleRate,audio.record.channels),audio.pcm]),{flag:'wx'});
  return {name,...audio.record,compressedFile,file};
}
function exportSadAudio(disc,target){
  const audio=readSadAudio(disc),compressedFile='audio/cutscene-SAD.sectors',file='audio/cutscene-SAD.wav';
  fs.writeFileSync(path.join(target,compressedFile),audio.compressed,{flag:'wx'});
  fs.writeFileSync(path.join(target,file),Buffer.concat([wavHeader(audio.pcm.length,audio.record.sampleRate,audio.record.channels),audio.pcm]),{flag:'wx'});
  return {name:'SAD',...audio.record,compressedFile,file};
}
function exportAllSequenceAudio(disc,target,sequences,sad){
  return sequences.map(entry=>entry.name==='SAD'?sad:exportSequenceAudio(disc,target,entry.name));
}
module.exports={readSadAudio,readSequenceAudio,exportSadAudio,exportSequenceAudio,exportAllSequenceAudio};
