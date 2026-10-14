'use strict';
const fs=require('node:fs'),path=require('node:path');
const {inspectCutscene,readCutsceneStream}=require('./cutscene-sectors.cjs');
const {record}=require('./an2-records.cjs'),{pose}=require('./an2-pose.cjs');
function exportSad(disc,target,modelAsset){
  if(!modelAsset||modelAsset.name!=='SAD00.MOD')throw Error('Missing original SAD model');
  const models=JSON.parse(fs.readFileSync(path.join(target,modelAsset.file))).models;
  const sourcePath='/CUTS/SAD.AN2',source=inspectCutscene(disc,sourcePath),stream=readCutsceneStream(disc,sourcePath),bytes=stream.bytes;
  const frames=[];let offset=0;
  while(offset<bytes.length){
    const raw=record(bytes,offset),frame=pose(raw,models);
    frame.stream={endByteOffset:raw.nextOffset,requiredSectorCount:stream.dataSectorOffsets[Math.ceil(raw.nextOffset/2048)-1]+1};
    frames.push(frame);offset=raw.nextOffset;
    if(raw.end)break;
  }
  if(!frames.length||!frames.at(-1).end||!bytes.subarray(offset).every(x=>x===0))throw Error('Unterminated or trailing nonzero SAD animation stream');
  const file='resources/cutscene-SAD.json';
  const roomFile='resources/cutscene-SAD-room-lighting.json';
  const roomRaw=fs.readdirSync(path.join(target,'raw')).find(name=>/^\d+-MP084_00\.MAP$/.test(name));
  if(!roomRaw)throw Error('Missing original SAD room lighting');
  fs.writeFileSync(path.join(target,roomFile),JSON.stringify(require('./cutscene-room-lighting.cjs').roomLighting(fs.readFileSync(path.join(target,'raw',roomRaw)))),{flag:'wx'});
  fs.writeFileSync(path.join(target,file),JSON.stringify({schema:1,source,model:modelAsset.name,frames}),{flag:'wx'});
  return {name:'SAD',file,model:modelAsset.file,sourcePath,rawSha256:source.rawSha256,records:frames.length,roomLighting:roomFile};
}
function exportSequence(disc,target,prefix,modelAssets){
  if(!/^[A-Z]+$/.test(prefix)||!Array.isArray(modelAssets)||!modelAssets.length)throw Error('Invalid cutscene sequence binding');
  const sourcePath='/CUTS/'+prefix+'.AN2',source=inspectCutscene(disc,sourcePath),stream=readCutsceneStream(disc,sourcePath);
  const parts=[];let offset=0;
  for(const [index,asset] of modelAssets.entries()){
    if(!asset||asset.name!==prefix+String(index).padStart(2,'0')+'.MOD')throw Error('Cutscene part/model ordering mismatch');
    const models=JSON.parse(fs.readFileSync(path.join(target,asset.file))).models,frames=[];
    while(offset<stream.bytes.length){
      const raw=record(stream.bytes,offset),frame=pose(raw,models);
      const sector=stream.dataSectorOffsets[Math.ceil(raw.nextOffset/2048)-1];
      if(!Number.isInteger(sector))throw Error('Cutscene record exceeds source sector map');
      frame.stream={endByteOffset:raw.nextOffset,requiredSectorCount:sector+1};
      frames.push(frame);offset=raw.nextOffset;
      if(raw.end)break;
    }
    if(!frames.length||!frames.at(-1).end)throw Error('Unterminated cutscene part');
    parts.push({model:asset.file,name:asset.name,frames});
  }
  if(!stream.bytes.subarray(offset).every(x=>x===0))throw Error('Trailing nonzero cutscene data or missing model parts');
  const file='resources/cutscene-sequence-'+prefix+'.json';
  fs.writeFileSync(path.join(target,file),JSON.stringify({schema:1,source,sourcePath,parts}),{flag:'wx'});
  return {name:prefix,file,sourcePath,rawSha256:source.rawSha256,parts:parts.length,records:parts.reduce((sum,part)=>sum+part.frames.length,0)};
}
function exportAllSequences(disc,target,manifest,tables){
  const unique=new Map();
  for(const scene of tables.gameOver.sequenceScenes.records)unique.set(scene.prefix,scene.modelCount);
  const bindings=Array.from(unique,([prefix,count])=>({prefix,assets:Array.from({length:count},(_,index)=>manifest.models.find(model=>model.name===prefix+String(index).padStart(2,'0')+'.MOD'))}));
  for(const binding of bindings){
    if(binding.assets.some(asset=>!asset))throw Error('Missing sequence model: '+binding.prefix);
    if(fs.existsSync(path.join(target,'resources/cutscene-sequence-'+binding.prefix+'.json')))throw Error('Sequence output already exists: '+binding.prefix);
  }
  return bindings.map(binding=>exportSequence(disc,target,binding.prefix,binding.assets));
}
module.exports={exportSad,exportSequence,exportAllSequences};
