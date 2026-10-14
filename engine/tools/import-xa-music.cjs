/* SPDX-License-Identifier: GPL-2.0-only */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Disc}=require('./disc.cjs'),{state,sector}=require('./xa-audio.cjs');
function wavHeader(size,rate,channels){
  const b=Buffer.alloc(44);b.write('RIFF');b.writeUInt32LE(size+36,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(channels,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*channels*2,28);b.writeUInt16LE(channels*2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(size,40);return b;
}
function exportMusic(disc,target,progress=()=>{}){
  if(disc.sectorSize!==2352)throw Error('XA music requires raw2352-sector source');
  const folder=path.join(target,'music');
  if(fs.existsSync(folder))throw Error('Music output already exists; exports do not overwrite it');
  fs.mkdirSync(folder);
  const streams=[];
  for(let pack=1;pack<=10;pack++){
    const source=disc.files.find(x=>x.path===`/PACK${pack}.STR`);
    if(!source||source.size%2048)throw Error('Missing or invalid original music pack');
    const outputs=new Map(),bytes=Buffer.alloc(2352);
    try{
      for(let offset=0;offset<source.size/2048;offset++){
        if(fs.readSync(disc.fd,bytes,0,2352,(source.lba+offset)*2352)!==2352)throw Error('Truncated original music sector');
        if(!bytes.subarray(16,20).equals(bytes.subarray(20,24)))throw Error('Music pack subheaders disagree');
        if((bytes[18]&4)===0)continue;
        const channel=bytes[17];if(bytes[16]!==1||channel<1||channel>7)throw Error('Unexpected original music file/channel');
        if(!outputs.has(channel)){
          const logical=(pack-1)*7+channel,file=`music/xa-${String(logical).padStart(2,'0')}.wav`;
          const fd=fs.openSync(path.join(target,file),'wx');fs.writeSync(fd,Buffer.alloc(44));
          const compressedFile=`music/xa-${String(logical).padStart(2,'0')}.sectors`;
          const out={logical,file,fd,compressedFile,rawFd:null,decoder:state(),hash:crypto.createHash('sha256'),bytes:0,sectors:0,first:offset,last:offset};
          outputs.set(channel,out);out.rawFd=fs.openSync(path.join(target,compressedFile),'wx');
        }
        const out=outputs.get(channel),decoded=sector(bytes,out.decoder);
        if(out.coding!==undefined&&out.coding!==decoded.coding)throw Error('Music coding changed within channel');
        Object.assign(out,{coding:decoded.coding,channels:decoded.channels,sampleRate:decoded.sampleRate,emphasis:decoded.emphasis,last:offset});
        out.hash.update(bytes);fs.writeSync(out.rawFd,bytes);fs.writeSync(out.fd,decoded.pcm);out.bytes+=decoded.pcm.length;out.sectors++;
      }
      if(outputs.size!==7)throw Error('Original pack is missing a music channel');
      for(const [channel,out]of outputs){
        fs.writeSync(out.fd,wavHeader(out.bytes,out.sampleRate,out.channels),0,44,0);fs.closeSync(out.fd);out.fd=null;
        fs.closeSync(out.rawFd);out.rawFd=null;
        streams.push({logical:out.logical,file:out.file,compressedFile:out.compressedFile,sectorBytes:2352,pack,channel,sourcePath:source.path,sourceLba:source.lba,firstSector:out.first,lastSector:out.last,sectors:out.sectors,sourceSha256:out.hash.digest('hex'),coding:out.coding,channels:out.channels,sampleRate:out.sampleRate,emphasis:out.emphasis,frames:out.bytes/(out.channels*2),decodedBytes:out.bytes});
      }
      progress({pack,channels:outputs.size,sectors:source.size/2048});
    }finally{for(const out of outputs.values()){if(out.fd!==null)fs.closeSync(out.fd);if(out.rawFd!==null)fs.closeSync(out.rawFd);}}
  }
  const index={schema:1,emphasisApplied:false,loopBoundsApplied:false,streams};
  fs.writeFileSync(path.join(folder,'index.json'),JSON.stringify(index,null,2),{flag:'wx'});
  return index;
}
if(require.main===module){const [source,target]=process.argv.slice(2);if(!source||!target)throw Error('Usage: import-xa-music.cjs backup existing-private-content');const disc=new Disc(source);try{const index=exportMusic(disc,path.resolve(target),value=>process.stdout.write(JSON.stringify(value)+'\n'));process.stdout.write(JSON.stringify({streams:index.streams.length,decodedBytes:index.streams.reduce((sum,x)=>sum+x.decodedBytes,0)})+'\n');}finally{disc.close();}}
module.exports={exportMusic,wavHeader};
