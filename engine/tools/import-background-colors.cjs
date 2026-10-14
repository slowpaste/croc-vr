'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {texturePack}=require('./asset-codecs.cjs');
const root=process.argv[2],file=path.join(root,'manifest.json'),m=JSON.parse(fs.readFileSync(file));
m.backgroundColors=[];
for(const t of m.textures.filter(x=>/^TB\d\d\.BIN$/.test(x.name))){
 const e=m.entries.find(x=>x.name===t.name),raw=fs.readFileSync(path.join(root,e.file));
 if(crypto.createHash('sha256').update(raw).digest('hex')!==e.sha256)throw Error('Background provenance mismatch');
 const d=texturePack(raw);if(d.extras.length!==3)throw Error('Missing original background RGB bytes');
 // Native25738 flags1/2 read RGB triples to 80074a14/80074a18. 3b6e8
 // applies the first to framebuffer clear; 3b6f8/22338 recolor solid dome faces.
 const bytes=d.extras.flatMap(x=>[x&255,x>>>8]);
 m.backgroundColors.push({name:t.name,clear:bytes.slice(0,3),dome:bytes.slice(3,6),sourceSha256:e.sha256});
}
fs.writeFileSync(file,JSON.stringify(m));console.log('Imported original RGB pairs for',m.backgroundColors.length,'backgrounds');
