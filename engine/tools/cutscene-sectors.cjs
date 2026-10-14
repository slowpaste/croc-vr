'use strict';
const fs=require('node:fs'),{createHash}=require('node:crypto');
// AN2 files mix FORM1 animation data with FORM2 XA; Disc.file must reject them.
function inspectCutscene(disc,path){
  const entry=disc.files.find(e=>e.path===path);
  if(!entry||entry.directory||entry.size%2048||disc.sectorSize!==2352)throw Error('Invalid raw cutscene extent');
  const channels={},hash=createHash('sha256');
  let header=null;
  for(let i=0;i<entry.size/2048;i++){
    const raw=Buffer.alloc(2352);
    if(fs.readSync(disc.fd,raw,0,2352,(entry.lba+i)*2352)!==2352)throw Error('Truncated cutscene sector');
    if(raw[15]!==2||!raw.subarray(16,20).equals(raw.subarray(20,24)))throw Error('Invalid cutscene subheader');
    hash.update(raw);
    const audio=!!(raw[18]&4),form2=!!(raw[18]&32),data=!!(raw[18]&8);
    if((audio&&!form2)||(data&&form2)||(audio&&data))throw Error('Unexpected cutscene sector mode at '+i);
    const kind=audio?'audio':data?'data':'padding',key=raw[16]+':'+raw[17]+':'+kind;
    const record=channels[key]??={file:raw[16],channel:raw[17],kind,coding:raw[19],sectors:0};
    if(record.coding!==raw[19])throw Error('Changing cutscene channel format');
    record.sectors++;
    if(data&&!header)header=Array.from({length:4},(_,n)=>raw.readUInt32LE(24+n*4));
  }
  return {path,lba:entry.lba,sectors:entry.size/2048,rawSha256:hash.digest('hex'),channels:Object.values(channels),headerWords:header};
}
module.exports={inspectCutscene};
function readCutsceneStream(disc,path,file=1,channel=1){
  inspectCutscene(disc,path);
  const entry=disc.files.find(e=>e.path===path),parts=[],dataSectorOffsets=[];
  for(let i=0;i<entry.size/2048;i++){
    const raw=Buffer.alloc(2352);
    fs.readSync(disc.fd,raw,0,2352,(entry.lba+i)*2352);
    if(raw[16]===file&&raw[17]===channel&&(raw[18]&8)){parts.push(raw.subarray(24,2072));dataSectorOffsets.push(i);}
  }
  return {bytes:Buffer.concat(parts),dataSectorOffsets};
}
function readCutsceneData(disc,path,file=1,channel=1){return readCutsceneStream(disc,path,file,channel).bytes;}
module.exports.readCutsceneData=readCutsceneData;
module.exports.readCutsceneStream=readCutsceneStream;
