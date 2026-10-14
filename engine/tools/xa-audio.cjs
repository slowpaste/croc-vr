/* SPDX-License-Identifier: GPL-2.0-only */
'use strict';
// XA block arithmetic checked against FFmpeg libavcodec/adpcm.c xa_decode.
const coefficients=[[0,0],[60,0],[115,-52],[98,-55]];
function state(){return {history:[[0,0],[0,0]]};}
function sector(bytes,decoder){
  if(bytes.length!==2352||bytes[15]!==2||bytes[0]!==0||!bytes.subarray(1,11).every(x=>x===255)||bytes[11]!==0)throw Error('Invalid raw XA sector');
  if(!bytes.subarray(16,20).equals(bytes.subarray(20,24)))throw Error('XA subheader copies disagree');
  const [file,channel,submode,coding]=bytes.subarray(16,20);
  if((submode&0x24)!==0x24)throw Error('Sector is not XA FORM2 audio');
  const layout=coding&3,rate=(coding>>>2)&3,width=(coding>>>4)&3;
  if(layout>1||rate>1||width!==0||(coding&0x80)!==0)throw Error('Unsupported XA coding mode');
  const channels=layout===1?2:1,sampleRate=rate===1?18900:37800,frames=18*28*8/channels;
  const pcm=Buffer.alloc(frames*channels*2);
  for(let group=0;group<18;group++){
    const at=24+group*128;
    if(!bytes.subarray(at,at+4).equals(bytes.subarray(at+4,at+8))||!bytes.subarray(at+8,at+12).equals(bytes.subarray(at+12,at+16)))throw Error('XA sound parameter copies disagree');
    for(let unit=0;unit<8;unit++){
      const parameter=bytes[at+4+unit],filter=parameter>>>4,range=parameter&15;
      if(filter>=coefficients.length||range>12)throw Error('Invalid XA predictor/range');
      const destination=channels===2?(unit&1):0,history=decoder.history[destination];
      const [first,second]=coefficients[filter];
      for(let sample=0;sample<28;sample++){
        const packed=bytes[at+16+(unit>>>1)+sample*4];
        let nibble=(packed>>>((unit&1)*4))&15;if(nibble>=8)nibble-=16;
        let value=nibble*(2**(12-range))+((history[0]*first+history[1]*second+32)>>6);
        value=Math.max(-32768,Math.min(32767,value));history[1]=history[0];history[0]=value;
        const frame=group*(224/channels)+(channels===2?(unit>>>1):unit)*28+sample;
        pcm.writeInt16LE(value,(frame*channels+destination)*2);
      }
    }
  }
  return {file,channel,coding,channels,sampleRate,frames,emphasis:!!(coding&0x40),pcm};
}
module.exports={state,sector};
