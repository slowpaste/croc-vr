/* SPDX-License-Identifier: GPL-2.0-only */
const {Cursor,checked,mapData,collisionRecords}=require('./asset-codecs.cjs');
const {sum}=require('./disc.cjs');
function animation(bytes){
  const c=new Cursor(bytes),speed=c.u16(),triggerCount=c.u16();c.take(4);
  if(![256,512].includes(speed)||triggerCount>128)throw Error('Unsupported animation header');
  const frameCount=c.u32();c.take(4);const vertexCount=c.u32();c.take(4);const boneCount=c.u32();c.take(4);
  if(!frameCount||frameCount>10000||vertexCount>65536||boneCount>1024)throw Error('Invalid animation dimensions');
  const triggers=[];for(let t=0;t<triggerCount;t++)triggers.push(Array.from(c.take(2)));
  c.take((4-(c.p&3))&3);
  const frameInfo=[];for(let f=0;f<frameCount;f++){const b=c.take(24);frameInfo.push(Array.from({length:6},(_,i)=>b.readInt32LE(i*4)));}
  c.take(frameCount*4);
  const vertices=[];
  if(vertexCount){
    for(let f=0;f<frameCount;f++){const b=c.take(vertexCount*4);vertices.push(Array.from({length:vertexCount},(_,i)=>b.readUInt32LE(i*4)));}
    c.take(frameCount*4);
  }
  const bones=[];
  for(let f=0;f<frameCount;f++){
    const row=[];for(let bone=0;bone<boneCount;bone++){const b=c.take(24);row.push(Array.from({length:12},(_,i)=>b.readInt16LE(i*2)));}bones.push(row);
  }
  return {length:c.p,data:{speed,frameCount,vertexCount,boneCount,triggers,frameInfo,vertices,bones}};
}
function embeddedModel(bytes){
  const base=new Cursor(bytes),count=base.u16(),flags=base.u16();base.take(4);
  if(!count||count>1024||flags>1)throw Error('Unsupported embedded model');
  // Optional sparse-model table is distinguished by ordered, bounded indices.
  const options=[true,false];let failure;
  for(const sparse of options){
    try{
      const c=new Cursor(bytes);c.p=8;
      let selected=Array.from({length:count},(_,i)=>i);
      if(sparse){
        const n=c.u32();if(!n||n>count)throw Error('Invalid sparse-model count');
        selected=[];for(let i=0;i<n;i++){const id=c.u16();if(id>=count||(i&&id<=selected[i-1]))throw Error('Invalid sparse-model table');selected.push(id);}
        c.take((4-(c.p&3))&3);
      }
      const headers=[];
      for(let i=0;i<count;i++){
        const b=c.take(104),n=b.readUInt32LE(76),f=b.readUInt32LE(88),x=b.readUInt16LE(96),y=b.readUInt16LE(98);
        if(n>65536||f>100000||x>10000||y>10000)throw Error('Invalid embedded geometry dimensions');
        headers.push({radius:b.readInt32LE()/4096,bounds:Array.from({length:9},(_,k)=>[b.readInt16LE(4+k*8)/4096,b.readInt16LE(6+k*8)/4096,b.readInt16LE(8+k*8)/4096]),n,f,x,y});
      }
      const models=headers.map(h=>({radius:h.radius,bounds:h.bounds,vertices:[],faces:[],collision:{counts:[h.x,h.y],groups:[[],[]],loaded:false}}));
      for(const id of selected){
        const h=headers[id],m=models[id];
        for(let v=0;v<h.n;v++){m.vertices.push([c.i16()/4096,c.i16()/4096,c.i16()/4096]);c.take(2);}c.take(h.n*8);
        for(let f=0;f<h.f;f++){
          const b=c.take(20),indices=[b.readUInt16LE(8),b.readUInt16LE(10),b.readUInt16LE(12)];if(b[19]&8)indices.push(b.readUInt16LE(14));
          if(indices.some(v=>v>=h.n))throw Error('Embedded polygon index outside vertices');
          m.faces.push({indices,flags:b[19],material:b.readUInt16LE(16),color:[b[16],b[17],b[18]]});
        }
        if(flags&1)m.collision.groups=[collisionRecords(c,h.x),collisionRecords(c,h.y)];
        m.collision.loaded=true;
      }
      return {length:c.p,data:{flags,models,selected,sparse}};
    }catch(e){failure=e;}
  }
  throw failure;
}
function wad(bytes){
  // Resource WADs have an eight-byte size/audio header, not a trailing checksum.
  // MAP*.WAD containers use a different envelope and are parsed separately.
  const payload=bytes;
  if(payload.readUInt32LE(0)!==bytes.length-8)throw Error('WAD size mismatch');
  const soundStart=payload.readUInt32LE(4)+8;
  if(soundStart<8||soundStart>payload.length)throw Error('WAD audio extent outside container');
  const chunks=[];let p=8;
  while(p<soundStart){
    const remainder=payload.subarray(p,soundStart),u16=remainder.readUInt16LE(),flags=remainder.readUInt16LE(2),size=remainder.readUInt32LE();
    let parsed,type;
    const pointer=remainder.length>=8?remainder.readUInt32LE(4):0;
    const initialPc=pointer&65535;
    if(size>=8&&!(size&3)&&size<=remainder.length&&initialPc>=3&&initialPc<=8){parsed={length:size,data:{size}};type='strategy';}
    else if([256,512].includes(u16)&&flags<=128&&(pointer===0||(pointer>=0x200000&&pointer<0x300000))){try{parsed=animation(remainder);}catch(e){e.message+=` at WAD offset ${p}`;e.chunks=chunks;throw e;}type='animation';}
    else if(u16>0&&u16<=1024&&flags<=1&&remainder.length>=8&&pointer>=0x200000&&pointer<0x300000){
      try{parsed=embeddedModel(remainder);}catch(e){e.message+=` at WAD offset ${p}`;e.chunks=chunks;throw e;}type='model';
    }else if(remainder.length>=12&&size>=24&&(size&15)===8&&remainder.readUInt32LE(4)<=1&&remainder.readUInt32LE(8)<=1){parsed={length:12,data:{sampleBytes:size-8,held:remainder.readUInt32LE(4),reverb:remainder.readUInt32LE(8),loop:remainder.readUInt32LE(8)}};type='audio-header';}
    else if(size>0&&size<=1024&&8+size*24<=remainder.length&&sum(remainder.subarray(0,4+size*24))===remainder.readUInt32LE(4+size*24)){
      // Source3dd04/3d544: count plus three signed32 X/Y pairs per triangle.
      parsed={length:8+size*24,data:{count:size,triangles:Array.from({length:size},(_,triangle)=>Array.from({length:3},(_,point)=>[remainder.readInt32LE(4+triangle*24+point*8),remainder.readInt32LE(8+triangle*24+point*8)]))}};type='unknown-table';
    }
    else if((size===0||(size&3)||size>remainder.length)&&remainder.length>=256&&remainder.subarray(224,256).every(v=>v===0)){parsed={length:256,data:{values:Array.from(remainder.subarray(0,256))}};type='model-redirect';}
    else if(size>=8&&!(size&3)&&size<=remainder.length){
      const block=remainder.subarray(0,size),version=block.readUInt16LE(4),refEnd=block.readUInt16LE(6)+4;
      if([12,20,21].includes(version)&&block[8]>0&&block[9]===80){parsed={length:size,data:mapData(block,true)};type='map';}
      else if(refEnd<8||refEnd>size){parsed={length:size,data:{size}};type='metadata';}
      else {parsed={length:size,data:{size}};type='strategy';}
    }
    else {const e=Error(`Unrecognized WAD chunk at ${p}: ${remainder.subarray(0,16).toString('hex')}`);e.chunks=chunks;throw e;}
    chunks.push({type,offset:p,...parsed});p+=parsed.length;
  }
  if(p!==soundStart)throw Error('WAD data boundary mismatch');
  return {chunks,soundStart,soundBytes:payload.length-soundStart};
}
function templates(bytes){
  if(bytes.length<40||bytes.readUInt32LE()!==bytes.length||(bytes.length-4)%36)throw Error('Invalid strategy template table size');
  const result=[];
  for(let p=4;p<bytes.length;p+=36){
    const name=bytes.toString('ascii',p,p+24).replace(/\0+$/,''),file=bytes.toString('ascii',p+24,p+32).replace(/\0+$/,'');
    if(!name||!file||!/^[\x20-\x7e]+$/.test(name)||!/^[A-Z0-9_]+$/.test(file))throw Error('Invalid strategy template name');
    result.push({name,file:file+'.BIN',pc:bytes.readUInt16LE(p+32)+4,variableCount:bytes.readUInt16LE(p+34)});
  }
  return result;
}
module.exports={animation,embeddedModel,wad,templates};
