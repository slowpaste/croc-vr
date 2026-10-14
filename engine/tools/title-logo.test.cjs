'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {texturePack,modelPack}=require('./asset-codecs.cjs'),{atlas,sample}=require('./texture-atlas.cjs'),zlib=require('node:zlib');
test('Original title models bind unchanged to the source frontend atlas',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  assert.deepEqual(m.frontendTitle.models.map(x=>x.name),['CROCC.MOD','CROCROC.MOD']);
  assert.equal(m.frontendTitle.texture,'FRONTEND.BIN');
  const entry=m.entries.find(x=>x.name==='FRONTEND.BIN'),texture=m.textures.find(x=>x.name===entry.name);
  const parsed=texturePack(fs.readFileSync(path.join(root,entry.file))),decoded=atlas(parsed,{dynamicU:{188:128,189:128}});
  assert.equal(parsed.polygons.length,435);
  assert.ok(decoded.image.equals(fs.readFileSync(path.join(root,texture.image))));
  const compressed=[];
  for(let at=8;at<decoded.image.length;){const length=decoded.image.readUInt32BE(at);if(decoded.image.toString('ascii',at+4,at+8)==='IDAT')compressed.push(decoded.image.subarray(at+8,at+8+length));at+=length+12;}
  const scans=zlib.inflateSync(Buffer.concat(compressed));
  for(const index of [188,189]){
    const uv=decoded.polygons[index].uv[2],x=Math.floor(uv[0]*decoded.width)+128,y=Math.floor(uv[1]*decoded.height);
    const actual=Array.from(scans.subarray(y*(decoded.width*4+1)+1+x*4,y*(decoded.width*4+1)+1+x*4+4));
    const source=parsed.polygons[index];assert.deepEqual(actual,sample(parsed,source,source.uv[0][0]+128,source.uv[0][1]));
  }
  for(let index=196;index<=201;index++){
    const poly=parsed.polygons[index];assert.equal((poly.word0>>>12)&3,1);
    for(let color=0;color<16;color++){const word=parsed.pages[poly.word1>>>8].readUInt16LE(((poly.word1&255)*256+color)*2);assert.ok(word===0||(word&0x8000)!==0);}
  }
  for(const model of m.frontendTitle.models){
    const raw=m.entries.find(x=>x.name===model.name);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root,model.file))),modelPack(fs.readFileSync(path.join(root,raw.file))));
  }
});
