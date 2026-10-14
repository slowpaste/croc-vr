/* SPDX-License-Identifier: GPL-2.0-only
 * Newly implemented bounds-checked parsers. Map field layout informed by
 * CrocUtils (Copyright 2020 Zane van Iperen), libcroc/map_read.c and mapdef.h.
 * Model layout: psx-spx Croc 1 format documentation. No game code is included.
 */
'use strict';
const {sum} = require('./disc.cjs');
class Cursor {
  constructor(bytes) { this.bytes=bytes; this.p=0; }
  take(n) { if (!Number.isSafeInteger(n)||n<0||this.p+n>this.bytes.length) throw Error(`Truncated asset at ${this.p}`); const r=this.bytes.subarray(this.p,this.p+n);this.p+=n;return r; }
  u16() { return this.take(2).readUInt16LE(); }
  i16() { return this.take(2).readInt16LE(); }
  u32() { return this.take(4).readUInt32LE(); }
  i32() { return this.take(4).readInt32LE(); }
  text() { return this.take(this.take(1)[0]).toString('latin1').replace(/\0+$/,''); }
}
function checked(bytes) {
  if (bytes.length < 8 || sum(bytes.subarray(0,-4))!==bytes.readUInt32LE(bytes.length-4)) throw Error('Asset checksum mismatch');
  return bytes.subarray(0,-4);
}
function collisionRecords(c,count){
  if(!Number.isSafeInteger(count)||count<0||count>20000)throw Error('Invalid collision record count');
  const records=[];
  for(let i=0;i<count;i++){
    const offset=c.p,b=c.take(44);
    // Preserve every halfword without assigning unverified geometric semantics.
    records.push({offset,halfwords:Array.from({length:22},(_,j)=>b.readInt16LE(j*2))});
  }
  return records;
}
function modelPack(bytes) {
  const c = new Cursor(checked(bytes));
  const count=c.u16(),flags=c.u16();
  if (!count || count>1024 || flags>1) throw Error('Unsupported model pack header');
  const models=[];
  for (let m=0;m<count;m++) {
    const radius=c.i32()/4096, bounds=[];
    for(let i=0;i<9;i++){bounds.push([c.i16()/4096,c.i16()/4096,c.i16()/4096]);c.take(2);}
    const n=c.u32();
    if(n>65536)throw Error('Too many vertices');
    const vertices=[];
    for(let i=0;i<n;i++){vertices.push([c.i16()/4096,c.i16()/4096,c.i16()/4096]);c.take(2);}
    const sourceNormals=[];
    for(let i=0;i<n;i++)sourceNormals.push([c.i16(),c.i16(),c.i16(),c.i16()]);
    const f=c.u32();
    if(f>100000)throw Error('Too many polygons');
    const faces=[];
    for(let i=0;i<f;i++){
      const b=c.take(20), faceFlags=b[19];
      const indices=[b.readUInt16LE(8),b.readUInt16LE(10),b.readUInt16LE(12)];
      if(faceFlags&8)indices.push(b.readUInt16LE(14));
      if(indices.some(index=>index>=n))throw Error('Polygon vertex index out of bounds');
      faces.push({indices,flags:faceFlags,material:b.readUInt16LE(16),color:[b[16],b[17],b[18]],sourceHeader:Array.from({length:4},(_,j)=>b.readInt16LE(j*2))});
    }
    const collision={counts:[0,0],groups:[[],[]],loaded:true};
    if(flags&1){const x=c.u16(),y=c.u16();collision.counts=[x,y];collision.groups=[collisionRecords(c,x),collisionRecords(c,y)];}
    models.push({radius,bounds,vertices,sourceNormals,faces,collision});
  }
  if(c.p!==c.bytes.length)throw Error(`Unconsumed model bytes: ${c.bytes.length-c.p}`);
  return {flags,models};
}

function mapData(bytes,embedded=false,preserveLighting=false) {
  const sizeFooter=embedded&&bytes.length>=10&&bytes.length<=65535&&bytes.readUInt16LE(bytes.length-2)===bytes.length;
  const payload=embedded?(sizeFooter?bytes.subarray(0,-2):bytes):checked(bytes);
  if(payload.readUInt32LE(0)!==(embedded?bytes.length:bytes.length-8))throw Error('Unsupported map size envelope');
  const version=payload.readUInt16LE(4);
  if(![12,20,21].includes(version))throw Error(`Unsupported map version ${version}`);
  // Version 12 has two entity parameter layouts; require a complete parse.
  const variants=version===12?[false,true]:[false];
  let failure;const failures=[];
  for(const variableParams of variants){
    try{
      const c=new Cursor(payload);c.take(8);
      const sourcePath=c.text(),info=c.take(38),title=c.text(),startRotation=c.i16()/4096;
      const dimensions=[info.readUInt16LE(2),info.readUInt16LE(4),info.readUInt16LE(6)];
      const style=info.readUInt16LE(8),tracks=[];
      const count=info.readUInt16LE(36);
      for(let i=0;i<count;i++){
        const position=[c.u16(),c.u16(),c.u16()],rotation=c.i16()/4096,index=c.u16();
        if(version>=21)c.take(4);
        tracks.push({position,rotation,index});
      }
      const entityCount=c.u16(),entities=[];
      if(entityCount>10000)throw Error('Too many entities');
      for(let i=0;i<entityCount;i++){
        const params=[],paramCount=variableParams?c.u16():8;
        if(paramCount>8)throw Error('Invalid entity parameter count');
        for(let n=0;n<paramCount;n++)params.push(c.u32());
        const position=[c.i32()/65536,c.i32()/65536,c.i32()/65536],rotation=[c.i16()/4096,c.i16()/4096,c.i16()/4096];
        const name=c.text();
        if(!name||!/^[\x20-\x7e]+$/.test(name))throw Error(`Invalid entity name at ${c.p}, entity ${i}`);
        const waypoints=[],ways=c.u16();
        if(ways>10000)throw Error('Too many waypoints');
        for(let w=0;w<ways;w++)waypoints.push({position:[c.i32()/65536,c.i32()/65536,c.i32()/65536],value:c.u32()});
        entities.push({name,params,position,rotation,waypoints});
      }
      const doors=[],doorCount=c.u16();
      for(let d=0;d<doorCount;d++)doors.push({position:[c.u16(),c.u16(),c.u16()],level:c.u16(),room:c.u16(),flags:c.u16(),id:c.u16()});
      const pointCount=c.u16(),sourceLighting={pointRecords:[],tail:[],finalWord:0};
      for(let point=0;point<pointCount;point++)sourceLighting.pointRecords.push(Array.from(c.take(24)));
      sourceLighting.tail=Array.from(c.take(36));sourceLighting.finalWord=c.u32();
      if(c.p!==c.bytes.length)throw Error(`Map has trailing data: ${c.bytes.length-c.p} bytes at ${c.p}`);
      return {version,variableParams,sizeFooter,sourcePath,title,dimensions,style,flags:info.readUInt32LE(10),musicTrack:info.readUInt32LE(14),background:info.readUInt32LE(18),effect:info.readUInt32LE(22),waitAnimation:info.readUInt32LE(26),ambience:info.readUInt32LE(30),startRotation,tracks,entities,doors,...(preserveLighting?{sourceLighting}: {})};
    }catch(e){failure=e;failures.push(e.message);}
  }
  failure.message=failures.join(' | ');throw failure;
}
function texturePack(bytes) {
  const c=new Cursor(checked(bytes));
  const envelope=c.u32(),type=c.u16(),extraCount=c.take(1)[0];
  if(![5,6].includes(type)||![0,3].includes(extraCount))throw Error('Unsupported texture header');
  if(envelope!==0&&envelope!==bytes.length-8)throw Error('Invalid texture size envelope');
  const extras=[];for(let i=0;i<extraCount;i++)extras.push(c.u16());
  const count=c.u16(),pageCount=c.u16(),unknownCount=c.u16();
  if(pageCount<1||pageCount>8||count>10000||unknownCount>1024)throw Error('Invalid texture counts');
  const paletteCycles=[];
  for(let i=0;i<unknownCount;i++){
    const palette=c.u16(),items=c.u16(),ranges=[];
    for(let j=0;j<items;j++)ranges.push({start:c.u16(),end:c.u16(),delay:c.u16()});
    paletteCycles.push({palette,ranges});
  }
  const animationCount=c.u16();
  const animations=[];
  for(let i=0;i<animationCount;i++){
    const frames=c.u16(),width=c.u16(),height=c.u16(),interval=c.u16(),x=c.take(1)[0],y=c.take(1)[0],page=c.u16();
    if(!frames||!width||!height||x+width>256||y+height>256||page>=pageCount)throw Error('Invalid animated texture rectangle');
    const data=c.take(frames*width*height*2);
    animations.push({frames,width,height,interval,x,y,page,data});
  }
  const polygons=[];
  for(let i=0;i<count;i++){const b=c.take(12);polygons.push({word0:b.readUInt16LE(0),word1:b.readUInt16LE(2),uv:[[b[4],b[5]],[b[6],b[7]],[b[8],b[9]],[b[10],b[11]]]});}
  const pages=[],pageLengths=[];
  for(let page=0;page<pageCount;page++){
    if(type===5){pages.push(c.take(0x20000));pageLengths.push(65536);continue;}
    const compressed=new Cursor(c.take(c.u32()));
    const words=[];
    while(compressed.p<compressed.bytes.length){
      const token=compressed.u16(),length=(token&0x7fff)+1;
      if(words.length+length>65537)throw Error('Texture decompression exceeds page bound');
      if(token&0x8000){for(let i=0;i<length;i++)words.push(compressed.u16());}
      else {const value=compressed.u16();for(let i=0;i<length;i++)words.push(value);}
    }
    // Retail files include pages short by 15 halfwords; their unused tail is
    // explicitly zero-filled. Preserve lengths in metadata rather than hide it.
    if(words.length<65520||words.length>65537)throw Error(`Unexpected decompressed texture page size: ${words.length} halfwords`);
    const data=Buffer.alloc(0x20000);for(let i=0;i<Math.min(65536,words.length);i++)data.writeUInt16LE(words[i],i*2);
    pages.push(data);
    pageLengths.push(words.length);
  }
  if(c.p!==c.bytes.length)throw Error('Texture has trailing bytes');
  return {type,extras,polygons,pages,pageLengths,animationCount,animations,paletteCycles};
}
module.exports={Cursor,checked,modelPack,mapData,texturePack,collisionRecords};
