'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {roomLighting}=require('./cutscene-room-lighting.cjs');
function exportRooms(content,manifest,tables){
 const names=new Set();
 for(const scene of tables.gameOver.sequenceScenes.records)for(let index=0;index<scene.modelCount;index++)names.add('MP'+String(scene.level).padStart(3,'0')+'_'+String(scene.firstRoom+index).padStart(2,'0')+'.MAP');
 return Array.from(names,name=>{
  const source=manifest.entries.find(entry=>entry.name===name),bytes=fs.readFileSync(path.join(content,source.file));
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==source.sha256)throw Error('Cutscene room checksum mismatch: '+name);
  const file='resources/cutscene-room-'+name+'.json';
  fs.writeFileSync(path.join(content,file),JSON.stringify(roomLighting(bytes)),{flag:'wx'});
  return {name,file,sourceSha256:source.sha256};
 });
}
function importRooms(content){
 const file=path.join(content,'manifest.json'),manifest=JSON.parse(fs.readFileSync(file)),tables=JSON.parse(fs.readFileSync(path.join(content,manifest.runtimeTables)));
 if(manifest.cutsceneRooms)throw Error('Sequence room lighting already imported');
 manifest.cutsceneRooms=exportRooms(content,manifest,tables);fs.writeFileSync(file,JSON.stringify(manifest));return {rooms:manifest.cutsceneRooms.length};
}
if(require.main===module)console.log(JSON.stringify(importRooms(process.argv[2])));
module.exports={exportRooms,importRooms};
