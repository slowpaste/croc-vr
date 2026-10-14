'use strict';
// Diagnostic comparison only. Split-product rule follows DuckStation's
// CDROM::DecodeXAADPCMChunks; summed rule is the current export/native decoder.
const fs=require('node:fs'),path=require('node:path');
const {state,sector}=require('./xa-audio.cjs');
function splitSector(raw,history){
  const pcm=Buffer.alloc(8064),coefficients=[[0,0],[60,0],[115,-52],[98,-55]];
  for(let group=0;group<18;group++)for(let unit=0;unit<8;unit++){
    const at=24+group*128,parameter=raw[at+4+unit];
    const [positive,negative]=coefficients[parameter>>>4],shift=12-(parameter&15),channel=unit&1;
    for(let sample=0;sample<28;sample++){
      let nibble=(raw[at+16+(unit>>>1)+sample*4]>>>(channel*4))&15;
      if(nibble>=8)nibble-=16;
      const value=Math.max(-32768,Math.min(32767,(nibble<<shift)+((history[channel][0]*positive)>>6)+((history[channel][1]*negative)>>6)));
      history[channel][1]=history[channel][0];history[channel][0]=value;
      pcm.writeInt16LE(value,((group*112+(unit>>>1)*28+sample)*2+channel)*2);
    }
  }
  return pcm;
}
function profile(root){
  const index=JSON.parse(fs.readFileSync(path.join(root,'music/index.json'),'utf8'));
  let samples=0,different=0,maximum=0,squared=0;
  const channels=[];
  for(const record of index.streams){
    const fd=fs.openSync(path.join(root,record.compressedFile),'r'),raw=Buffer.alloc(2352);
    const summed=state(),split=[[0,0],[0,0]];let channelDifferent=0;
    try{for(let i=0;i<Math.min(200,record.sectors);i++){
      if(fs.readSync(fd,raw,0,2352,i*2352)!==2352)throw Error('Truncated source sidecar');
      const reference=sector(raw,summed).pcm,alternate=splitSector(raw,split);
      for(let offset=0;offset<8064;offset+=2){
        const delta=Math.abs(reference.readInt16LE(offset)-alternate.readInt16LE(offset));
        samples++;squared+=delta*delta;maximum=Math.max(maximum,delta);
        if(delta){different++;channelDifferent++;}
      }
    }}finally{fs.closeSync(fd);}
    channels.push({logical:record.logical,differentSamples:channelDifferent});
  }
  return {schema:1,source:'Original private XA sidecars; up to 200 sectors/channel',summedRule:'FFmpeg/PSX-SPX +32 summed predictor',splitRule:'DuckStation independently shifted predictor products',hardwareConclusion:'unqualified',samples,differentSamples:different,maximumAbsoluteDifference:maximum,rmsDifference:Math.sqrt(squared/samples),channels};
}
if(require.main===module){const result=profile(process.argv[2]);if(process.argv[3])fs.writeFileSync(process.argv[3],JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({...result,channels:undefined}));}
module.exports={splitSector,profile};
