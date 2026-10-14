/* SPDX-License-Identifier: GPL-2.0-only */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{wad}=require('./wad-codecs.cjs'),{decodeSPU,wav}=require('./spu-audio.cjs');
function exportWadAudio(bytes,parsed,prefix,root){
  let position=parsed.soundStart;const records=[];
  for(const chunk of parsed.chunks.filter(c=>c.type==='audio-header')){
    const length=chunk.data.sampleBytes;
    if(position+length>bytes.length)throw Error('SPU sample extent exceeds WAD audio bank');
    const original=bytes.subarray(position,position+length),decoded=decodeSPU(original),image='audio/'+prefix+'-'+chunk.offset+'.wav',file='audio/'+prefix+'-'+chunk.offset+'.json';
    fs.writeFileSync(path.join(root,image),wav(decoded),{flag:'wx'});
    const info={file:image,sampleRate:44100,samples:decoded.samples,loopBegin:decoded.loopStart,loopEnd:decoded.loopEnd,loop:decoded.repeat,headerLoop:chunk.data.loop,held:chunk.data.held,reverb:chunk.data.reverb,sourceOffset:position,sourceBytes:length,sha256:crypto.createHash('sha256').update(original).digest('hex')};
    fs.writeFileSync(path.join(root,file),JSON.stringify(info),{flag:'wx'});records.push({offset:chunk.offset,file,audio:image});position+=length;
  }
  if(position!==bytes.length)throw Error('Unconsumed WAD audio bytes');
  return records;
}
function addAudio(root){
  const m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),dir=path.join(root,'audio');
  if(fs.existsSync(dir))throw Error('Audio output already exists');fs.mkdirSync(dir);
  let count=0;
  for(const entry of m.entries.filter(e=>e.name.endsWith('.WAD')&&!/^MAP\d/.test(e.name))){
    const bytes=fs.readFileSync(path.join(root,entry.file)),parsed=wad(bytes),prefix=String(entry.id).padStart(4,'0')+'-'+entry.name;
    const records=exportWadAudio(bytes,parsed,prefix,root);
    for(const record of records){
      const resource=m.resources.find(r=>r.owner===entry.name&&r.offset===record.offset);Object.assign(resource,record);count++;
      const lists=[m.linkage.bootstrap,...Object.values(m.linkage.controllers).map(c=>c.assets),...Object.values(m.linkage.rooms).map(c=>c.assets)];
      for(const list of lists)for(const binding of list)if(binding.owner===entry.name&&binding.offset===record.offset)Object.assign(binding,record);
    }
  }
  m.audioSamples=count;fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(m,null,2));return count;
}
if(require.main===module){try{console.log('Decoded WAD samples:',addAudio(process.argv[2]));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={addAudio,exportWadAudio};
