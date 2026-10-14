'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function prepare(content,baseFile,out,diagnosticScene=null){
 if(fs.existsSync(out))throw Error('Use a new staging directory');
 const local=JSON.parse(fs.readFileSync(path.join(content,'manifest.json'))),remote=JSON.parse(fs.readFileSync(baseFile,'utf8').replace(/^\uFEFF/,''));
 if(local.sourceSha256!==remote.sourceSha256)throw Error('Native content source differs');
 if(diagnosticScene!==null){
  const scene=Number(diagnosticScene),tables=JSON.parse(fs.readFileSync(path.join(content,local.runtimeTables)));
  const record=tables.gameOver?.sequenceScenes?.records?.[scene];
  if(!Number.isInteger(scene)||!record)throw Error('Invalid diagnostic scene');
  local.cutsceneSequenceCaches=local.cutsceneSequenceCaches.filter(entry=>entry.scene_id===scene);
  local.cutsceneSequences=local.cutsceneSequences.filter(entry=>entry.name===record.prefix);
  local.cutsceneSequenceAudio=local.cutsceneSequenceAudio.filter(entry=>entry.name===record.prefix);
 }
 // Source identity permits reuse, but runtime bindings must come from the
 // current import rather than a previously installed manifest.
 Object.assign(remote,local);
 const files=new Set([local.runtimeTables]);
 // This output is launched as standalone content, so retain room scripts,
 // bootstrap resources and gameplay sounds as well as cinematic directories.
 for(const directory of ['resources','audio']){
  const source=path.join(content,directory);
  if(!fs.existsSync(source))continue;
  for(const entry of fs.readdirSync(source,{withFileTypes:true})){
   if(entry.isFile())files.add(directory+'/'+entry.name);
  }
 }
 for(const key of ['cutscenePoses','cutsceneMeshes','cutsceneBackgroundMeshes','cutsceneAudio','cutsceneCompositor']){
  if(!Array.isArray(local[key])||!local[key].length)throw Error('Missing cutscene resources: '+key);
  remote[key]=local[key];
  for(const item of local[key]){
   if(item.file)files.add(item.file);
   if(item.compressedFile)files.add(item.compressedFile);
   if(item.roomLighting)files.add(item.roomLighting);
   if(key.includes('Meshes'))for(const mesh of JSON.parse(fs.readFileSync(path.join(content,item.file))).files){files.add(mesh.file);if(mesh.sky_file)files.add(mesh.sky_file);}
   if(key==='cutsceneCompositor')for(const frame of JSON.parse(fs.readFileSync(path.join(content,item.file))).frames)for(const stage of frame.passes){if(stage.kind==='opaque')for(const mesh of Object.values(stage.meshes))files.add(mesh.file);else files.add(stage.mesh.file);}
  }
 }
 const intro=local.textures.find(item=>item.name==='INTRO.BIN');
 if(!intro)throw Error('Missing original INTRO atlas');
 remote.textures=remote.textures.filter(item=>item.name!=='INTRO.BIN').concat([intro]);
 files.add(intro.file);files.add(intro.image);
 if(intro.maskImage)files.add(intro.maskImage);
 // Multipart opening/endings and credits need their complete resource bindings.
 function references(value){
  if(typeof value==='string'){
   if(/^(resources|audio|maps|models|textures|options|music)\//.test(value))files.add(value);
   return;
  }
  if(Array.isArray(value)){for(const item of value)references(item);return;}
  if(!value||typeof value!=='object')return;
  for(const [key,item] of Object.entries(value)){
   if(['file','image','maskImage','compressedFile','roomLighting'].includes(key)&&typeof item==='string'&&/^(resources|audio|maps|models|textures|options|music)\//.test(item))files.add(item);
   else references(item);
  }
 }
 for(const key of ['models','maps','textures','cutsceneRooms','cutsceneSequences','cutsceneSequenceAudio','cutsceneSequenceCaches','credits']){
  if(!Array.isArray(local[key])||!local[key].length)throw Error('Missing campaign cinematic bindings: '+key);
  remote[key]=local[key];references(local[key]);
 }
 if(!local.creditsFonts)throw Error('Missing credits fonts');
 remote.creditsFonts=local.creditsFonts;references(local.creditsFonts);
 let musicStreams=[];
 if(local.musicIndex){
  files.add(local.musicIndex);
  const music=JSON.parse(fs.readFileSync(path.join(content,local.musicIndex)));
  if(!Array.isArray(music.streams)||!music.streams.length)throw Error('Missing original music streams');
  musicStreams=music.streams;references(music);
 }
 for(const entry of local.textures){
  const atlas=JSON.parse(fs.readFileSync(path.join(content,entry.file)));
  references(atlas.animationPatches||[]);
 }
 for(const entry of local.cutsceneSequenceCaches){
  const cache=JSON.parse(fs.readFileSync(path.join(content,entry.file)));
  if(cache.scene_id!==entry.scene_id||cache.fingerprint!==entry.fingerprint)throw Error('Sequence cache identity differs');
  references(cache);
 }
 for(const entry of local.cutsceneSequenceImages||[]){
  files.add(entry.file);
  const cache=JSON.parse(fs.readFileSync(path.join(content,entry.file)));
  if(cache.scene_id!==entry.scene_id||cache.fingerprint!==entry.fingerprint)throw Error('Image cache identity differs');
  for(const part of cache.parts)for(const frame of part.frames){
   if(path.basename(frame.file)!==frame.file)throw Error('Invalid movie image payload path');
   files.add(path.posix.dirname(entry.file)+'/'+frame.file);
  }
 }
 references(remote);
 const staged=[];
 for(const file of files){
  if(path.isAbsolute(file)||file.split(/[\\/]/).includes('..'))throw Error('Unsafe content path');
  const bytes=fs.readFileSync(path.join(content,file));
  staged.push({file,size:bytes.length,sha:crypto.createHash('sha256').update(bytes).digest('hex')});
 }
 const stagedHashes=new Map(staged.map(item=>[item.file,item.sha]));
 for(const stream of musicStreams){
  if(!stagedHashes.has(stream.file)||!stagedHashes.has(stream.compressedFile)||stagedHashes.get(stream.compressedFile)!==stream.sourceSha256)throw Error('Original music payload missing or hash differs');
 }
 fs.mkdirSync(out,{recursive:true});
 for(const item of staged){const target=path.join(out,item.file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(content,item.file),target,fs.constants.COPYFILE_EXCL);}
 const manifest=Buffer.from(JSON.stringify(remote));
 fs.writeFileSync(path.join(out,'manifest.json'),manifest,{flag:'wx'});
 staged.push({file:'manifest.json',size:manifest.length,sha:crypto.createHash('sha256').update(manifest).digest('hex')});
 fs.writeFileSync(path.join(out,'sha256.txt'),staged.map(item=>item.sha+'  '+item.file).join('\n')+'\n',{flag:'wx'});
 return {files:staged.length,bytes:staged.reduce((n,item)=>n+item.size,0)};
}
if(require.main===module)console.log(JSON.stringify(prepare(...process.argv.slice(2))));
module.exports={prepare};
