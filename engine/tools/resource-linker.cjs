/* SPDX-License-Identifier: GPL-2.0-only */
const {decode}=require('./asl-codec.cjs'),{wad,templates}=require('./wad-codecs.cjs');
class Linker {
  constructor(definitions,cache=new Map()){
    this.definitionList=definitions;this.definitions=new Map(definitions.map(d=>[d.name,d]));this.cache=new Map(cache);this.bindings=[];
  }
  begin(owner,bytes){this.owner=owner;this.bytes=bytes;this.chunks=wad(bytes).chunks;this.cursor=0;this.bindings=[];}
  next(type,name){
    const chunk=this.chunks[this.cursor];
    if(!chunk||chunk.type!==type)throw Error(`${this.owner}: expected ${type} ${name}, found ${chunk?.type} at ${chunk?.offset}, index ${this.cursor}`);
    this.cursor++;return chunk;
  }
  bind(kind,name,force=false){
    const key=([2,5].includes(kind)?'model':kind)+':'+name.toUpperCase();
    if(!force&&this.cache.has(key))return this.cache.get(key);
    const type={1:'strategy',2:'model',3:'audio-header',4:'animation',5:'model'}[kind];
    if(!type)return {kind,name,deferred:true};
    const chunk=this.next(type,name),binding={kind,name,owner:this.owner,offset:chunk.offset,type};
    this.bindings.push(binding);this.cache.set(key,binding);
    if(kind===1){
      const program=decode(this.bytes.subarray(chunk.offset,chunk.offset+chunk.length));
      if(program.invalidTargets.length)throw Error('Script has invalid branch targets');
      binding.program=program;
      for(const ref of program.references){
        if(ref.kind===1)this.spawn(ref.name);
        else if([2,3,4,5].includes(ref.kind))this.bind(ref.kind,ref.name);
      }
    }
    return binding;
  }
  spawn(name){
    // The retail lookup compares the requested prefix in table order; it does
    // not require the definition's next character to be a terminator.
    const d=this.definitionList.find(d=>d.name.startsWith(name));
    if(!d)throw Error(`No strategy definition for ${name}`);
    return this.bind(1,d.file);
  }
  bootstrap(owner,bytes){
    this.begin(owner,bytes);
    for(let i=0;i<4;i++)this.next('metadata','bootstrap table');
    this.bind(2,'CRYSTAL1.MOD');this.bind(2,'CROC.MOD');
    for(const name of ['SELECT','START','BON_BEEP','CRYS','DEATHFX','SEEDRED'])this.bind(3,name,true);
    for(const name of ['SmashBlock','PlatformDead','NormalDoor','Crystal','HitCloud','SkidCloud','CrystalSpark','PickUpScatter','DeathFX'])this.spawn(name);
    this.next('unknown-table','bootstrap lookup');
    return this.bindings;
  }
  room(owner,bytes,map){
    this.begin(owner,bytes);
    if(this.chunks[0]?.type==='map')this.next('map','embedded map');
    const player=this.cache.get('1:'+(this.playerFile||'CROC.BIN'));
    for(const ref of (this.menu?[]:player.program.references)){
      if(ref.kind===6&&map.waitAnimation)this.bind(4,'CROCWA'+map.waitAnimation+'.ANI');
      else if(ref.kind===9&&map.waitAnimation)this.bind(3,'CROCWA'+map.waitAnimation);
      else if([7,8].includes(ref.kind)){
        const terms=ref.condition;
        if(terms.length!==3||terms[0].op!==4||terms[1].op!==35||terms[2].op!==18)throw Error('Unsupported preload flag expression');
        if(map.flags&terms[0].value)this.bind(ref.kind===7?4:3,ref.name);
      }
    }
    for(const entity of map.entities)this.spawn(entity.name);
    return this.bindings;
  }
}
function linkArchive(bytesByName,allMaps){
  const exclude=bytesByName('EXCLUDE.WAD'),chunks=wad(exclude).chunks;
  const definitions=templates(exclude.subarray(chunks[1].offset,chunks[1].offset+chunks[1].length));
  const global=new Linker(definitions);global.bootstrap('EXCLUDE.WAD',exclude);
  const bootstrap=global.bindings.map(b=>({...b})),base=new Map(global.cache),controllers={};
  for(const [profile,owner,actor,file]of[['normal','CROC.WAD','Croc','CROC.BIN'],['swim','SWIMCROC.WAD','SwimmingCroc','SWIMCROC.BIN'],['slide','CROCSLID.WAD','CrocSlide','CROCSLDE.BIN']]){
    const loader=new Linker(definitions,base);loader.begin(owner,bytesByName(owner));loader.spawn(actor);
    if(loader.cursor!==loader.chunks.length)throw Error('Core controller has unconsumed resources: '+owner);
    controllers[profile]={actor,file,loader};
  }
  const rooms={},unresolvedRooms={};
  for(const {name,data}of allMaps){
    const owner=name.replace('.MAP','.WAD');let bytes;
    try{bytes=bytesByName(owner);}catch{continue;}
    const profile=[1,11].includes(data.style)?'swim':data.style===22?'slide':'normal',controller=controllers[profile];
    try{
      const menu=Number(name.slice(2,5))>=90;
      const room=new Linker(definitions,menu?base:controller.loader.cache);room.playerFile=controller.file;room.menu=menu;room.room(owner,bytes,data);
      const tail=room.chunks.slice(room.cursor);
      const sceneSuffix=menu&&tail.length===2&&tail.every(c=>c.type==='model');
      if(!sceneSuffix&&(tail.length!==4||tail[0].type!=='model-redirect'||tail.slice(1).some(c=>c.type!=='model')))throw Error('Unexpected room geometry suffix: '+owner);
      rooms[name]={profile,menu,player:menu?null:controller.actor,playerFile:menu?null:controller.file,assets:room.bindings,redirectOffset:sceneSuffix?null:tail[0].offset,cameraOffset:sceneSuffix?null:tail[1].offset,terrainOffset:tail[sceneSuffix?0:2].offset,backgroundOffset:tail[sceneSuffix?1:3].offset};
    }catch(e){unresolvedRooms[name]=e.message;}
  }
  return {definitions,bootstrap,controllers:Object.fromEntries(Object.entries(controllers).map(([k,v])=>[k,{actor:v.actor,file:v.file,assets:v.loader.bindings}])),rooms,unresolvedRooms};
}
module.exports={Linker,linkArchive};
