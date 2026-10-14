'use strict';
const {createHash}=require('node:crypto');
function fonts(exe,expectedHash,codes){
 if(createHash('sha256').update(exe).digest('hex')!==expectedHash)throw Error('Credits font executable revision differs');
 const base=exe.readUInt32LE(24),at=address=>address-base+2048,result={small:{},large:{},sourceAddresses:{smallAdvance:0x8006bf3c,smallSprite:0x8006b93c,smallWidth:0x8006c13c,smallHeight:0x8006c29c,largeAdvance:0x8006c75c,largeSprite:0x8006c55c,largeWidth:0x8006c95c}};
 for(const code of new Set(codes)){
  if(!Number.isInteger(code)||code<0||code>=128)throw Error('Unsupported credits glyph code');
  result.small[code]={advance:exe.readInt32LE(at(0x8006bf3c)+code*4),sprite:exe.readInt32LE(at(0x8006b93c)+code*4),width:exe.readUInt16LE(at(0x8006c13c)+code*2),height:exe.readUInt16LE(at(0x8006c29c)+code*2)};
  result.large[code]={advance:exe.readInt32LE(at(0x8006c75c)+code*4)+1,sprite:161+exe.readInt32LE(at(0x8006c55c)+code*4),width:exe.readInt32LE(at(0x8006c95c)+code*4),height:18};
 }
 return result;
}
module.exports={fonts};
