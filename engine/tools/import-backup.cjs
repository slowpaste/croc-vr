/* SPDX-License-Identifier: GPL-2.0-only */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Disc,directory}=require('./disc.cjs');
const {modelPack,mapData,checked,texturePack}=require('./asset-codecs.cjs');
const {atlas,animationPatches}=require('./texture-atlas.cjs');
const {wad}=require('./wad-codecs.cjs');
const {decode}=require('./asl-codec.cjs');
const {linkArchive}=require('./resource-linker.cjs');
const {exportWadAudio}=require('./import-audio.cjs');
const {runtimeTables}=require('./runtime-tables.cjs');
const {demo}=require('./demo-codec.cjs');
const {exportMusic}=require('./import-xa-music.cjs');
const {musicBounds}=require('./music-bounds.cjs');
const {levelNames}=require('./level-names.cjs');
const {exportSad,exportAllSequences}=require('./import-cutscene.cjs');
const {exportSadAudio,exportAllSequenceAudio}=require('./cutscene-audio.cjs');
function sha(data){return crypto.createHash('sha256').update(data).digest('hex');}
async function importBackup(source,out){
  const target=path.resolve(out);
  const project=path.resolve(__dirname,'..');
  for(const forbidden of ['game','build','.git','dist']){
    const root=path.join(project,forbidden).toLowerCase();
    if(target.toLowerCase()===root||target.toLowerCase().startsWith(root+path.sep))throw Error('Imported content must be outside source and release directories');
  }
  if(fs.existsSync(target))throw Error('Output already exists. Select a new directory; imports never overwrite content.');
  const disc=new Disc(source);
  try{
    const archive=disc.file('/CROCFILE.1'),entries=directory(disc.file('/CROCFILE.DIR'),archive.length);
    const sourceHash=crypto.createHash('sha256');
    for await(const chunk of fs.createReadStream(source))sourceHash.update(chunk);
    fs.mkdirSync(target,{recursive:true});
    fs.mkdirSync(path.join(target,'raw'));fs.mkdirSync(path.join(target,'models'));fs.mkdirSync(path.join(target,'maps'));fs.mkdirSync(path.join(target,'textures'));fs.mkdirSync(path.join(target,'resources'));fs.mkdirSync(path.join(target,'audio'));
    const manifest={schema:1,sourceSha256:sourceHash.digest('hex'),volume:disc.volume,sourceBytes:disc.bytes,entries:[],models:[],maps:[],textures:[],resources:[],wads:[],character:{},unsupported:[]};
    const allMaps=[];
    try{
      const tables=runtimeTables(disc.file('/CROC.EXE'));
      manifest.runtimeTables='resources/runtime-tables.json';
      fs.writeFileSync(path.join(target,manifest.runtimeTables),JSON.stringify(tables),{flag:'wx'});
    }catch(err){manifest.unsupported.push({name:'runtime-tables',reason:err.message});}
    function writeMap(e,bytes,key,name,embedded=false) {
      const data=mapData(bytes,embedded),file='maps/'+key+'.json';
      if(!/^MP\d{3}_\d{2}\.MAP$/.test(name))throw Error('Unexpected logical map name');
      fs.writeFileSync(path.join(target,file),JSON.stringify(data),{flag:'wx'});
      manifest.maps.push({id:e.id,name,file,title:data.title,style:data.style,tracks:data.tracks.length,entities:data.entities.length});
      allMaps.push({name,data});
    }
    for(const e of entries){
      const bytes=archive.subarray(e.offset,e.offset+e.size);
      const key=String(e.id).padStart(4,'0')+'-'+e.name;
      fs.writeFileSync(path.join(target,'raw',key),bytes,{flag:'wx'});
      manifest.entries.push({...e,file:'raw/'+key,sha256:sha(bytes)});
      if(e.name==='EXCLUDE.WAD'){
        const file='resources/level-names.json';
        fs.writeFileSync(path.join(target,file),JSON.stringify(levelNames(bytes)),{flag:'wx'});
        manifest.levelNames={file,sourceSha256:sha(bytes)};
      }
      if(['MUSIC.BIN','MAGMUS.BIN'].includes(e.name)){
        const file='resources/'+key+'.json';
        fs.writeFileSync(path.join(target,file),JSON.stringify(musicBounds(bytes)),{flag:'wx'});
        (manifest.musicBounds??=[]).push({name:e.name,file,sourceSha256:sha(bytes)});
      }
      if(e.name.endsWith('.DEM')){
        const file='resources/'+key+'.json';
        fs.writeFileSync(path.join(target,file),JSON.stringify(demo(bytes)),{flag:'wx'});
        (manifest.demos??=[]).push({name:e.name,file,sourceSha256:sha(bytes),frames:900});
      }
      if(/^TK\d+_(TRK|ENM)\.BIN$/.test(e.name)||/^TB\d+\.BIN$/.test(e.name)||['FONT.BIN','FRONTEND.BIN','STILLGOH.BIN','INTRO.BIN','INTROJIG.BIN','OUTRO.BIN'].includes(e.name)){
        try{
          const parsed=texturePack(bytes),data=atlas(parsed,{preserveMask:true,...(e.name==='FRONTEND.BIN'?{dynamicU:{188:128,189:128}}:{})}),file='textures/'+key+'.json',image='textures/'+key+'.png',maskImage='textures/'+key+'-mask.png';
          fs.writeFileSync(path.join(target,image),data.image,{flag:'wx'});
          fs.writeFileSync(path.join(target,maskImage),data.maskImage,{flag:'wx'});
          const patches=animationPatches(parsed).map(({image:bytes,...metadata},index)=>{
            const patchFile='textures/'+key+'-animation-'+index+'.png';
            fs.writeFileSync(path.join(target,patchFile),bytes,{flag:'wx'});
            return {...metadata,image:patchFile};
          });
          fs.writeFileSync(path.join(target,file),JSON.stringify({width:data.width,height:data.height,image,maskImage,polygons:data.polygons,uvConvention:data.uvConvention,pageLengths:parsed.pageLengths,animationCount:parsed.animationCount,animationPatches:patches}),{flag:'wx'});
          manifest.textures.push({id:e.id,name:e.name,file,image,maskImage,polygons:data.polygons.length,animationCount:parsed.animationCount});
        }catch(err){manifest.unsupported.push({id:e.id,name:e.name,reason:err.message});}
      }
      if(e.name.endsWith('.MOD')){
        try{
          const data=modelPack(bytes),file='models/'+key+'.json';
          fs.writeFileSync(path.join(target,file),JSON.stringify(data),{flag:'wx'});
          manifest.models.push({id:e.id,name:e.name,file,count:data.models.length,flags:data.flags});
        }catch(err){manifest.unsupported.push({id:e.id,name:e.name,reason:err.message});}
      }
      if(e.name.endsWith('.MAP')){
        try{
          writeMap(e,bytes,key,e.name);
        }catch(err){manifest.unsupported.push({id:e.id,name:e.name,reason:err.message});}
      }
      if(/^MAP\d+\.WAD$/.test(e.name)){
        try {
          const payload=checked(bytes);
          if(payload.readUInt32LE(0)!==bytes.length-8)throw Error('Map WAD size mismatch');
          for(let p=4,part=0;p<payload.length;part++){
            if(p+4>payload.length)throw Error('Truncated embedded map');
            const length=payload.readUInt32LE(p)+8;
            if(length<16||p+length>payload.length)throw Error('Invalid embedded map extent');
            const level=Number(e.name.match(/^MAP(\d+)/)[1]);
            const name='MP'+String(level).padStart(3,'0')+'_'+String(part).padStart(2,'0')+'.MAP';
            writeMap(e,payload.subarray(p,p+length),key+'-'+part,name);
            p+=length;
          }
        }catch(err){manifest.unsupported.push({id:e.id,name:e.name,reason:err.message});}
      }
      if(e.name.endsWith('.WAD')&&!/^MAP\d/.test(e.name)){
        try{
          if(e.name==='EXCLUDE.WAD'){
            const music=require('./music-bounds.cjs').bootstrapMusicBounds(bytes),file='resources/bootstrap-music.json';
            fs.writeFileSync(path.join(target,file),JSON.stringify(music),{flag:'wx'});
            manifest.bootstrapMusic={owner:e.name,file,sourceOffset:8,sourceLength:284,sourceSha256:sha(bytes.subarray(8,292))};
          }
          const decoded=wad(bytes),chunkRecords=[],audioRecords=exportWadAudio(bytes,decoded,key,target);
          for(const chunk of decoded.chunks){
            const record={owner:e.name,type:chunk.type,offset:chunk.offset,length:chunk.length};
            if(chunk.type==='audio-header')Object.assign(record,audioRecords.find(a=>a.offset===chunk.offset));
            if(['model','animation','unknown-table','model-redirect'].includes(chunk.type)){
              if(chunk.type==='unknown-table')record.sha256=sha(bytes.subarray(chunk.offset,chunk.offset+chunk.length));
              record.file='resources/'+key+'-'+chunk.offset+'.json';
              fs.writeFileSync(path.join(target,record.file),JSON.stringify(chunk.data),{flag:'wx'});
            }
            if(chunk.type==='strategy'){
              const program=decode(bytes.subarray(chunk.offset,chunk.offset+chunk.length));
              if(program.invalidTargets.length)throw Error('Strategy has invalid control-flow targets');
              record.file='resources/'+key+'-'+chunk.offset+'.strategy.json';
              fs.writeFileSync(path.join(target,record.file),JSON.stringify(program),{flag:'wx'});
            }
            if(chunk.type==='map')writeMap(e,bytes.subarray(chunk.offset,chunk.offset+chunk.length),key+'-'+chunk.offset,e.name.replace('.WAD','.MAP'),true);
            manifest.resources.push(record);chunkRecords.push(record);
          }
          manifest.wads.push({id:e.id,name:e.name,chunks:chunkRecords.length,soundBytes:decoded.soundBytes});
        }catch(err){manifest.unsupported.push({id:e.id,name:e.name,reason:err.message});}
      }
    }
    const bytesByName=name=>{const e=entries.find(e=>e.name===name);if(!e)throw Error('Archive resource missing: '+name);return archive.subarray(e.offset,e.offset+e.size);};
    const linked=linkArchive(bytesByName,allMaps),resourceIndex=new Map(manifest.resources.map(r=>[r.owner+':'+r.offset,r]));
    function cleanBindings(list){return list.map(({program,...b})=>({...b,...resourceIndex.get(b.owner+':'+b.offset)}));}
    const globalBindings=cleanBindings(linked.bootstrap),controllers=Object.fromEntries(Object.entries(linked.controllers).map(([name,c])=>[name,{...c,assets:cleanBindings(c.assets)}]));
    manifest.linkage={definitions:linked.definitions,bootstrap:globalBindings,controllers,rooms:{},unresolvedRooms:linked.unresolvedRooms};
    for(const [name,room]of Object.entries(linked.rooms)){
      const owner=name.replace('.MAP','.WAD');
      manifest.linkage.rooms[name]={...room,assets:cleanBindings(room.assets),camera:room.cameraOffset===null?null:resourceIndex.get(owner+':'+room.cameraOffset).file,terrain:resourceIndex.get(owner+':'+room.terrainOffset).file,background:resourceIndex.get(owner+':'+room.backgroundOffset).file};
    }
    manifest.character.model=globalBindings.find(b=>b.name==='CROC.MOD').file;
    manifest.character.animations=Object.fromEntries(controllers.normal.assets.filter(b=>b.kind===4&&b.name.startsWith('CROC')).map(b=>[b.name,b.file]));
    manifest.audioSamples=manifest.resources.filter(r=>r.type==='audio-header'&&r.audio).length;
    manifest.frontendTitle={texture:'FRONTEND.BIN',models:['CROCC.MOD','CROCROC.MOD'].map(name=>manifest.models.find(model=>model.name===name))};
    if(disc.sectorSize===2352){
      manifest.cutscenePoses=[exportSad(disc,target,manifest.models.find(m=>m.name==='SAD00.MOD'))];
      manifest.cutsceneSequences=exportAllSequences(disc,target,manifest,JSON.parse(fs.readFileSync(path.join(target,manifest.runtimeTables))));
      manifest.cutsceneRooms=require('./import-sequence-rooms.cjs').exportRooms(target,manifest,JSON.parse(fs.readFileSync(path.join(target,manifest.runtimeTables))));
      manifest.cutsceneAudio=[exportSadAudio(disc,target)];
      manifest.cutsceneSequenceAudio=exportAllSequenceAudio(disc,target,manifest.cutsceneSequences,manifest.cutsceneAudio[0]);
      manifest.credits=require('./import-credits.cjs').exportCredits(target,manifest);
      manifest.creditsFonts=require('./import-credits-fonts.cjs').exportFonts(disc,target,manifest);
      exportMusic(disc,target);manifest.musicIndex='music/index.json';
    }
    fs.writeFileSync(path.join(target,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
    fs.writeFileSync(path.join(target,'LOCAL-CONTENT.txt'),'Generated locally from the selected backup. Not part of the engine or distributable build. No PlayStation BIOS or executable is extracted. Archive BIN/WAD resources can include original strategy bytecode; the new engine does not execute it.\n');
    return manifest;
  }finally{disc.close();}
}
if(require.main===module){
  const [source,out]=process.argv.slice(2);
  if(!source||!out){console.error('Usage: node tools/import-backup.cjs <bin-or-iso> <new-local-content-directory>');process.exitCode=1;}
  else importBackup(source,out).then(m=>console.log(JSON.stringify({entries:m.entries.length,modelPacks:m.models.length,models:m.models.reduce((n,p)=>n+p.count,0),maps:m.maps.length,textures:m.textures.length,wads:m.wads.length,resources:m.resources.length,characterAnimations:Object.keys(m.character.animations||{}).length,unsupported:m.unsupported}))).catch(e=>{console.error(e.message);process.exitCode=1;});
}
module.exports={importBackup};
