'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Disc}=require('./disc.cjs'),{png,color555}=require('./texture-atlas.cjs');
const disc=new Disc(process.argv[2]);let executable;
try{executable=disc.file('/CROC.EXE');}finally{disc.close();}
const executableSha256=crypto.createHash('sha256').update(executable).digest('hex');
if(executableSha256!=='f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996')throw Error('Unsupported save-icon executable');
const offset=0x8006b5cc-executable.readUInt32LE(24)+2048;
const source=executable.subarray(offset,offset+416);
if(source.length!==416)throw Error('Truncated native save icon');
const palette=Array.from({length:16},(_,i)=>source.readUInt16LE(i*2));
const frames=Array.from({length:3},(_,i)=>Array.from(source.subarray(32+i*128,32+(i+1)*128)));
const data={schema:1,executableSha256,sourceAddress:0x8006b5cc,sourceSha256:crypto.createHash('sha256').update(source).digest('hex'),width:16,height:16,palette,frames};
const bytes=JSON.stringify(data),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
const content=path.resolve(process.argv[3]),relative='options/save-icon-'+sha256+'.json',target=path.join(content,relative);
fs.mkdirSync(path.dirname(target),{recursive:true});
if(fs.existsSync(target)&&fs.readFileSync(target,'utf8')!==bytes)throw Error('Existing icon payload mismatch');
fs.writeFileSync(target,bytes);
const manifestPath=path.join(content,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
if(manifest.schema!==1)throw Error('Invalid content manifest');
manifest.saveIcon={file:relative,sha256,executableSha256};fs.writeFileSync(manifestPath,JSON.stringify(manifest));
const rgba=Buffer.alloc(48*16*4);
for(let frame=0;frame<3;frame++)for(let pixel=0;pixel<256;pixel++){
 const packed=frames[frame][pixel>>1],index=(packed>>((pixel&1)*4))&15;
 const x=frame*16+(pixel&15),y=pixel>>4;
 Buffer.from(color555(palette[index])).copy(rgba,(y*48+x)*4);
}
fs.writeFileSync(path.resolve(process.argv[4]),png(48,16,rgba));
console.log('SAVE_ICON_PUBLISHED:',relative);
