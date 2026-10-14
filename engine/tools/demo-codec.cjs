'use strict';
function demo(bytes){
  if(bytes.length!==3600)throw Error('Original demo recording must contain900 button words');
  return {frames:Array.from({length:900},(_,index)=>bytes.readUInt32LE(index*4))};
}
module.exports={demo};
