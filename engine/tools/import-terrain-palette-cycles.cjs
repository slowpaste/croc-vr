'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {texturePack}=require('./asset-codecs.cjs');
const {atlas,sample,color555,png}=require('./texture-atlas.cjs');
const root=process.argv[2],manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),changed=[],skipped=[];
for(const entry of manifest.textures.filter(x=>/^TK\d\d_(TRK|ENM)\.BIN$/.test(x.name))){
 const source=manifest.entries.find(x=>x.name===entry.name),raw=fs.readFileSync(path.join(root,source.file));
 if(crypto.createHash('sha256').update(raw).digest('hex')!==source.sha256)throw Error('Original texture checksum mismatch');
 const texture=texturePack(raw);if(!texture.paletteCycles.length)continue;
 const current=JSON.parse(fs.readFileSync(path.join(root,entry.file))),base=atlas(texture);
 if(base.width!==current.width||base.height!==current.height||JSON.stringify(base.polygons)!==JSON.stringify(current.polygons))throw Error('Palette atlas binding changed: '+entry.name);
 const patches=[];
 for(const group of texture.paletteCycles){
  const overlaps=texture.animations.some(a=>a.page===0&&group.palette>=a.y&&group.palette<a.y+a.height&&group.ranges.some(r=>r.start<a.x+a.width&&r.end>=a.x))||texture.polygons.some(poly=>{
   if(poly.word1!==group.palette)return false;
   const mode=(poly.word0>>>8)&15,shift=mode===0?2:mode===1?1:0;
   const left=(poly.word0&3)*64+(Math.min(...poly.uv.map(p=>p[0]))>>>shift),right=(poly.word0&3)*64+(Math.max(...poly.uv.map(p=>p[0]))>>>shift),top=Math.min(...poly.uv.map(p=>p[1])),bottom=Math.max(...poly.uv.map(p=>p[1]));
   return texture.animations.some(a=>a.page===((poly.word0&255)>>>2)&&left<a.x+a.width&&right>=a.x&&top<a.y+a.height&&bottom>=a.y);
  });
  if(overlaps){skipped.push(entry.name+':palette'+group.palette);continue;}
  const used=new Set();for(const range of group.ranges){for(let i=range.start;i<=range.end;i++){if(used.has(i))throw Error('Overlapping palette cycle ranges');used.add(i);}}
  for(const range of group.ranges){
   if(range.start>range.end||range.end>255)throw Error('Invalid original palette range');
   const affected=new Map();
   for(let id=0;id<texture.polygons.length;id++){
    const poly=texture.polygons[id],mode=(poly.word0>>>8)&15;if(mode>1||poly.word1!==group.palette)continue;
    const page=(poly.word0&255)>>>2,baseX=(poly.word0&3)*64;
    const minU=Math.min(...poly.uv.map(p=>p[0])),maxU=Math.max(...poly.uv.map(p=>p[0])),minV=Math.min(...poly.uv.map(p=>p[1])),maxV=Math.max(...poly.uv.map(p=>p[1]));
    const ax=Math.floor(base.polygons[id].uv[2][0]*base.width)-poly.uv[0][0]+minU;
    const ay=Math.floor(base.polygons[id].uv[2][1]*base.height)-poly.uv[0][1]+minV;
    for(let y=-1;y<=maxV-minV+1;y++)for(let x=-1;x<=maxU-minU+1;x++){
     const u=minU+Math.max(0,Math.min(maxU-minU,x)),v=minV+Math.max(0,Math.min(maxV-minV,y));
     const packed=texture.pages[page].readUInt16LE((v*256+baseX+(u>>>(mode===0?2:1)))*2),index=(packed>>>((u&(mode===0?3:1))*(mode===0?4:8)))&(mode===0?15:255);
     if(index>=range.start&&index<=range.end)affected.set((ay+y)*base.width+ax+x,index);
    }
   }
   if(!affected.size||range.start===range.end)continue;
   const positions=[...affected.keys()],left=Math.min(...positions.map(p=>p%base.width)),right=Math.max(...positions.map(p=>p%base.width)),top=Math.min(...positions.map(p=>Math.floor(p/base.width))),bottom=Math.max(...positions.map(p=>Math.floor(p/base.width)));
   const width=right-left+1,height=bottom-top+1,frames=range.end-range.start+1,pixels=Buffer.alloc(width*height*frames*4),rectangles=[];
   for(let y=top;y<=bottom;y++)for(let x=left;x<=right;x++)if(affected.has(y*base.width+x)){
    const start=x;while(x<right&&affected.has(y*base.width+x+1))x++;
    const prior=rectangles.find(r=>r.x===start-left&&r.width===x-start+1&&r.y+r.height===y-top);if(prior)prior.height++;else rectangles.push({x:start-left,y:y-top,width:x-start+1,height:1});
   }
   for(let frame=0;frame<frames;frame++)for(const [position,index]of affected){
    const rotated=range.start+(index-range.start+frame)%frames,word=texture.pages[0].readUInt16LE((group.palette*256+rotated)*2),rgba=color555(word),x=position%base.width-left,y=Math.floor(position/base.width)-top;
    for(let c=0;c<4;c++)pixels[((frame*height+y)*width+x)*4+c]=rgba[c];
   }
   const image=entry.image.replace(/\.png$/,`-palette-${group.palette}-${range.start}-${range.end}.png`);fs.writeFileSync(path.join(root,image),png(width,height*frames,pixels));
   patches.push({palette:group.palette,start:range.start,end:range.end,delay:range.delay,frames,width,height,x:left,y:top,rectangles,image,paletteCycle:true,interval:1});
  }
 }
 delete current.paletteCyclePatches;fs.writeFileSync(path.join(root,entry.file),JSON.stringify(current));
 const file=entry.image.replace(/\.png$/,'-palette-cycles.json');fs.writeFileSync(path.join(root,file),JSON.stringify({schema:1,sourceSha256:source.sha256,patches}));
 manifest.paletteCycleTextures=(manifest.paletteCycleTextures||[]).filter(x=>x.name!==entry.name).concat({name:entry.name,file,sourceSha256:source.sha256});
 changed.push({name:entry.name,file,patches:patches.length,images:patches.map(x=>x.image)});
}
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest));
console.log(JSON.stringify({changed:changed.map(x=>({name:x.name,patches:x.patches})),skipped}));
