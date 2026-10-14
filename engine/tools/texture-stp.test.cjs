const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const {texturePack}=require('./asset-codecs.cjs'),{atlas,sampleWord}=require('./texture-atlas.cjs');
function pixels(png){const blocks=[];for(let at=8;at<png.length;){const size=png.readUInt32BE(at);if(png.toString('ascii',at+4,at+8)==='IDAT')blocks.push(png.subarray(at+8,at+8+size));at+=size+12;}return zlib.inflateSync(Buffer.concat(blocks));}
test('INTRO transparency sidecar retains every source STP and zero-color bit',{skip:!process.env.CROC_CONTENT},()=>{
 const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),entry=m.entries.find(e=>e.name==='INTRO.BIN'),source=texturePack(fs.readFileSync(path.join(root,entry.file)));
 const decoded=atlas(source,{preserveMask:true}),baseline=atlas(source),scan=pixels(decoded.maskImage);
 assert.ok(decoded.image.equals(baseline.image));assert.deepEqual(decoded.polygons,baseline.polygons);
 const asset=m.textures.find(e=>e.name==='INTRO.BIN');
 if(asset.maskImage)assert.ok(decoded.maskImage.equals(fs.readFileSync(path.join(root,asset.maskImage))));
 for(let i=0;i<source.polygons.length;i++){
  const poly=source.polygons[i],uv=decoded.polygons[i].uv[2],x=Math.floor(uv[0]*decoded.width),y=Math.floor(uv[1]*decoded.height),minU=Math.min(...poly.uv.map(p=>p[0])),minV=Math.min(...poly.uv.map(p=>p[1])),width=Math.max(...poly.uv.map(p=>p[0]))-minU+1,height=Math.max(...poly.uv.map(p=>p[1]))-minV+1;
  for(let yy=0;yy<height;yy++)for(let xx=0;xx<width;xx++){
   const word=sampleWord(source,poly,minU+xx,minV+yy),at=(y+yy)*(decoded.width*4+1)+1+(x+xx)*4;
   assert.equal(scan[at],word&0x8000?255:0);assert.equal(scan[at+1],word===0?0:255);
  }
 }
});
