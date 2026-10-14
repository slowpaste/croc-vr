'use strict';
const {mapData}=require('./asset-codecs.cjs');
function roomLighting(bytes){
 const source=mapData(bytes,false,true).sourceLighting;
 const tail=Buffer.from(source.tail),lightMatrix=[],colorMatrix=Array(9).fill(0);
 // Native20804..20994: three direction rows and RGB columns shifted by4.
 for(let light=0;light<3;light++){
  for(let axis=0;axis<3;axis++)lightMatrix.push(tail.readInt16LE(light*12+axis*2));
  for(let channel=0;channel<3;channel++)colorMatrix[channel*3+light]=tail[light*12+8+channel]<<4;
 }
 return {source,lightMatrix,colorMatrix,ambientBytes:[source.finalWord&255,(source.finalWord>>>8)&255,(source.finalWord>>>16)&255],textureBase:[128,128,128],staticWorld:true};
}
module.exports={roomLighting};
