'use strict';
// Native22874 reads structural pose records;23290 skips the trailing payload.
function record(bytes,offset=0){
  let cursor=offset;
  const take=n=>{
    if(!Number.isSafeInteger(n)||n<0||cursor<0||cursor+n>bytes.length)throw Error('Truncated AN2 record');
    const result=bytes.subarray(cursor,cursor+n);cursor+=n;return result;
  };
  const word=()=>take(4).readUInt32LE();
  const tag=word();
  if(tag>4096)throw Error('Invalid AN2 record tag');
  const header=take(24),matrixCount=word();
  if(matrixCount>1024)throw Error('Invalid AN2 matrix count');
  const matrices=[];
  for(let i=0;i<matrixCount;i++)matrices.push(take(36));
  const groupCount=word();
  if(groupCount>1024)throw Error('Invalid AN2 vector group count');
  const groups=[];
  for(let i=0;i<groupCount;i++){
    const id=word(),transform=take(32),vectorCount=word(),vectors=take(vectorCount*8);
    groups.push({id,transform,vectorCount,vectors});
  }
  const payloadLength=word();
  if(payloadLength>10752)throw Error('Invalid AN2 trailing payload length');
  take(payloadLength);
  return {tag,header,matrices,groups,payloadLength,offset,nextOffset:cursor,end:tag===0};
}
module.exports={record};
