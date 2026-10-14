/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const {texturePack}=require('./asset-codecs.cjs'),{atlas}=require('./texture-atlas.cjs');
function pixels(file){
 const bytes=fs.readFileSync(file),parts=[];let width,height;
 for(let p=8;p<bytes.length;){const n=bytes.readUInt32BE(p),type=bytes.toString('ascii',p+4,p+8);if(type==='IHDR'){width=bytes.readUInt32BE(p+8);height=bytes.readUInt32BE(p+12);}if(type==='IDAT')parts.push(bytes.subarray(p+8,p+8+n));p+=n+12;}
 const scan=zlib.inflateSync(Buffer.concat(parts)),out=Buffer.alloc(width*height*4);
 for(let y=0;y<height;y++){assert.equal(scan[y*(width*4+1)],0);scan.copy(out,y*width*4,y*(width*4+1)+1,(y+1)*(width*4+1));}
 return {width,height,data:out};
}
test('Imported crystal animation patches reproduce simultaneous native VRAM uploads, including static atlas pixels',{skip:!process.env.CROC_CONTENT},()=>{
 const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
 for(const name of ['TK00_ENM.BIN','TK05_ENM.BIN']){
  const entry=m.textures.find(e=>e.name===name),source=m.entries.find(e=>e.id===entry.id),original=texturePack(fs.readFileSync(path.join(root,source.file))),metadata=JSON.parse(fs.readFileSync(path.join(root,entry.file)));
  const actual=pixels(path.join(root,entry.image)),pages=original.pages.map(page=>Buffer.from(page));
  const patches=metadata.animationPatches.map(s=>({...s,sheet:pixels(path.join(root,s.image))}));
  assert.ok(patches.length>0);assert.equal(original.animations[0].frames,8);
  for(let tick=1;tick<=24;tick++){
   for(const animation of original.animations)if(tick%Math.max(1,animation.interval)===0){
    const frame=(Math.floor(tick/Math.max(1,animation.interval))-1)%animation.frames;
    for(let y=0;y<animation.height;y++)animation.data.copy(pages[animation.page],((animation.y+y)*256+animation.x)*2,(frame*animation.height+y)*animation.width*2,(frame*animation.height+y+1)*animation.width*2);
   }
   for(const patch of patches)if(tick%Math.max(1,patch.interval)===0){
    const frame=(Math.floor(tick/Math.max(1,patch.interval))-1)%patch.frames;
    for(const r of patch.rectangles)for(let y=0;y<r.height;y++)patch.sheet.data.copy(actual.data,((patch.y+r.y+y)*actual.width+patch.x+r.x)*4,((frame*patch.height+r.y+y)*patch.width+r.x)*4,((frame*patch.height+r.y+y)*patch.width+r.x+r.width)*4);
   }
   assert.deepEqual(actual.data,atlas({...original,pages}).rgba,name+' tick '+tick);
  }
 }
});
