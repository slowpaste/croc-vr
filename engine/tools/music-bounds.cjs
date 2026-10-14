'use strict';
const {checked}=require('./asset-codecs.cjs');
function musicBounds(bytes){
  checked(bytes);
  if(bytes.length!==288||bytes.readUInt32LE(0)!==280)throw Error('Invalid original music length table');
  return {endSectorOffsets:Array.from({length:70},(_,index)=>bytes.readUInt32LE(4+index*4))};
}
module.exports={musicBounds};
function bootstrapMusicBounds(bytes){
  if(bytes.length<292||bytes.readUInt32LE(0)!==bytes.length-8||bytes.readUInt32LE(4)+8<292||bytes.readUInt32LE(4)+8>bytes.length||bytes.readUInt32LE(8)!==284)throw Error('Invalid original bootstrap music block');
  return {endSectorOffsets:Array.from({length:70},(_,index)=>bytes.readUInt32LE(12+index*4))};
}
module.exports.bootstrapMusicBounds=bootstrapMusicBounds;
