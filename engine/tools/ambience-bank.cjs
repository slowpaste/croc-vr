'use strict';
function bank(header,body){
 if(header.length<32||header.toString('ascii',0,4)!=='pBAV'||header.readUInt32LE(4)!==6)throw Error('Unsupported ambience VAB header');
 const programs=header.readUInt16LE(18),tones=header.readUInt16LE(20),samples=header.readUInt16LE(22);
 if(programs>128||tones>programs*16||samples>255)throw Error('Invalid ambience bank dimensions');
 const table=32+128*16+programs*16*32;
 if(header.length!==table+512||header.readUInt32LE(12)!==header.length+body.length)throw Error('Ambience bank extent differs');
 const sizes=Array.from({length:256},(_,i)=>header.readUInt16LE(table+i*2)*8);
 if(sizes[0]!==0||sizes.slice(samples+1).some(x=>x!==0))throw Error('Unsupported ambience sample table padding');
 const voices=[];let offset=0;
 for(let id=1;id<=samples;id++){
  const length=sizes[id];if(!length||length%16||offset+length>body.length)throw Error('Invalid ambience sample extent');
  voices.push({id,offset,length,data:body.subarray(offset,offset+length)});offset+=length;
 }
 if(offset!==body.length)throw Error('Trailing ambience sample body');
 return {version:6,programs,tones,samples,programRecords:Array.from({length:128},(_,i)=>header.subarray(32+i*16,48+i*16)),toneRecords:Array.from({length:programs*16},(_,i)=>header.subarray(2080+i*32,2112+i*32)),voices};
}
module.exports={bank};
