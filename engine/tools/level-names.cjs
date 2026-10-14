'use strict';
// Startup3ec84..3edd0 selects the fourth EXCLUDE block;3efc4 relocates100 pointers.
function levelNames(bytes){
  if(bytes.length<8||bytes.readUInt32LE(0)!==bytes.length-8)throw Error('Invalid startup archive');
  let offset=8;
  for(let i=0;i<3;i++){
    if(offset+4>bytes.length)throw Error('Truncated startup block');
    const length=bytes.readUInt32LE(offset);
    if(length<4||offset+length>bytes.length)throw Error('Invalid startup block');
    offset+=length;
  }
  const length=bytes.readUInt32LE(offset),start=offset+4,end=offset+length;
  if(length<804||end>bytes.length)throw Error('Invalid level-name block');
  const names=[];
  for(let i=0;i<100;i++){
    const pointer=bytes.readUInt32LE(start+i*8),p=start+pointer;
    if(pointer<800||p>=end)throw Error('Level-name pointer outside string area');
    const zero=bytes.indexOf(0,p);
    if(zero<0||zero>=end)throw Error('Unterminated level name');
    names.push(bytes.subarray(p,zero).toString('latin1'));
  }
  return {names,sourceOffset:start,sourceLength:length-4};
}
module.exports={levelNames};
