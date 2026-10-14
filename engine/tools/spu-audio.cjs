/* SPDX-License-Identifier: GPL-2.0-only */
'use strict';
const filters=[[0,0],[60,0],[115,-52],[98,-55],[122,-60]];
function decodeSPU(bytes){
  if(!bytes.length||bytes.length%16)throw Error('SPU sample must contain complete 16-byte blocks');
  const pcm=Buffer.alloc(bytes.length/16*28*2);let previous=0,older=0,position=0,loopStart=0,loopEnd=0,repeat=false,ended=false;
  for(let p=0;p<bytes.length;p+=16){
    const filter=bytes[p]>>>4,shift=bytes[p]&15,flags=bytes[p+1];
    if(filter>4||shift>12)throw Error(`Unsupported SPU block header ${bytes[p]} at ${p}`);
    if(flags&4)loopStart=position;
    const [a,b]=filters[filter];
    for(let i=0;i<28;i++){
      let value=(bytes[p+2+(i>>>1)]>>>((i&1)*4))&15;if(value&8)value-=16;
      value=((value<<12)>>shift)+((previous*a+older*b+32)>>6);
      value=Math.max(-32768,Math.min(32767,value));pcm.writeInt16LE(value,position*2);position++;older=previous;previous=value;
    }
    if(flags&1){loopEnd=position;repeat=!!(flags&2);ended=true;break;}
  }
  return {pcm:pcm.subarray(0,position*2),samples:position,loopStart,loopEnd:loopEnd||position,repeat,ended};
}
function wav(data,rate=44100){
  const length=data.pcm.length,b=Buffer.alloc(44+length);
  b.write('RIFF');b.writeUInt32LE(36+length,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(length,40);data.pcm.copy(b,44);return b;
}
module.exports={decodeSPU,wav};
