/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {atlas}=require('./texture-atlas.cjs');
const {texturePack}=require('./asset-codecs.cjs');
const zlib=require('node:zlib');

test('Model UV corners select the correct vertical half of an upright atlas',()=>{
  const page=Buffer.alloc(0x20000);
  // Direct-color asymmetric rectangle: red upper row, green lower row.
  for(let x=10;x<=13;x++)for(let y=20;y<=23;y++)page.writeUInt16LE(y<22?31:31<<5,(y*256+x)*2);
  const a=atlas({pages:[page],polygons:[{word0:512,word1:0,uv:[[10,20],[13,20],[10,23],[13,23]]}]});
  const uv=a.polygons[0].uv;
  // Model V0 (bottom) samples the lower image row; V1 samples the upper row.
  assert.deepEqual(uv.map(([u,v])=>[Math.floor(u*a.width),Math.floor(v*a.height)]),[[1,6],[4,6],[1,3],[4,3]]);
  // Existing renderer: normal quad, alternate quad, and triangular corner order.
  assert.deepEqual([1,0,3,2].map(i=>Math.floor(uv[i][1]*a.height)),[6,6,3,3]);
  assert.deepEqual([0,1,2,3].map(i=>Math.floor(uv[i][1]*a.height)),[6,6,3,3]);
  assert.deepEqual([0,2,3].map(i=>Math.floor(uv[i][1]*a.height)),[6,3,3]);
  const compressed=[];
  for(let p=8;p<a.image.length;){
    const length=a.image.readUInt32BE(p);
    if(a.image.toString('ascii',p+4,p+8)==='IDAT')compressed.push(a.image.subarray(p+8,p+8+length));
    p+=length+12;
  }
  const scan=zlib.inflateSync(Buffer.concat(compressed));
  const at=([u,v])=>{
    const x=Math.floor(u*a.width),y=Math.floor(v*a.height),offset=y*(a.width*4+1)+1+x*4;
    return Array.from(scan.subarray(offset,offset+4));
  };
  assert.deepEqual(uv.map(at),[[0,255,0,255],[0,255,0,255],[255,0,0,255],[255,0,0,255]]);
  assert.equal(a.uvConvention,'model-low-v-first');
});

if(process.env.CROC_CONTENT)test('All imported texture UVs match regenerated source rectangles',()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  for(const entry of m.textures){
    const raw=m.entries.find(e=>e.id===entry.id),expected=atlas(texturePack(fs.readFileSync(path.join(root,raw.file))),entry.name==='FRONTEND.BIN'?{dynamicU:{188:128,189:128}}:{});
    const actual=JSON.parse(fs.readFileSync(path.join(root,entry.file)));
    assert.equal(actual.uvConvention,expected.uvConvention,entry.name);
    assert.deepEqual(actual.polygons,expected.polygons,entry.name);
    assert.deepEqual(fs.readFileSync(path.join(root,entry.image)),expected.image,entry.name);
  }
  assert.equal(new Set(m.textures.map(e=>e.id)).size,m.textures.length);
});
