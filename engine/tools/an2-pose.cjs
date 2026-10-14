'use strict';
function transform(bytes){
  if(bytes.length!==32)throw Error('Invalid AN2 transform span');
  // Native18710 stores record+22 (transform+18), then treats it as signed scale.
  return {matrix:Array.from({length:9},(_,i)=>bytes.readInt16LE(i*2)),scale:bytes.readInt16LE(18),position:Array.from({length:3},(_,i)=>bytes.readInt32LE(20+i*4))};
}
function pose(record,models){
  if(record.header.length!==24)throw Error('Invalid AN2 camera header');
  const parts=[];
  const add=part=>{
    // Retail186xx iterates records, not unique model IDs. OUTRO and CRYSD
    // draw many separate instances of the same Gobbo/prop model.
    if(!Number.isInteger(part.id)||part.id<0||part.id>=models.length)throw Error('Invalid AN2 model index');
    parts.push(part);
  };
  for(const bytes of record.matrices){
    if(bytes.length!==36)throw Error('Invalid AN2 rigid record');
    add({id:bytes.readUInt32LE(),...transform(bytes.subarray(4))});
  }
  for(const group of record.groups){
    if(!models[group.id]||group.vectorCount!==models[group.id].vertices.length||group.vectors.length!==group.vectorCount*8)throw Error('AN2 vertex count disagrees with model');
    const vertices=Array.from({length:group.vectorCount},(_,i)=>Array.from({length:4},(_,j)=>group.vectors.readInt16LE(i*8+j*2)));
    add({id:group.id,...transform(group.transform),vertices});
  }
  const camera={position:Array.from({length:3},(_,i)=>record.header.readInt32LE(i*4)),word12:record.header.readUInt32LE(12),angles:Array.from({length:3},(_,i)=>record.header.readInt16LE(16+i*2)),projectionDistance:record.header.readUInt16LE(22)};
  return {tag:record.tag,end:record.end,camera,parts};
}
module.exports={transform,pose};
