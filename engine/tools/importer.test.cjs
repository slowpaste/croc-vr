/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {directory,sum,safeName}=require('./disc.cjs');
const {modelPack,texturePack}=require('./asset-codecs.cjs');
const {sample,color555,atlas}=require('./texture-atlas.cjs');
const {animation}=require('./wad-codecs.cjs');
function checksum(b){b.writeUInt32LE(sum(b.subarray(0,-4)),b.length-4);return b;}
function dir(entries){
  const b=Buffer.alloc(8+entries.length*24);b.writeUInt32LE(entries.length);
  entries.forEach((e,i)=>{const p=4+i*24;b.write(e.name,p,12,'ascii');b.writeUInt32LE(e.size,p+12);b.writeUInt32LE(e.offset,p+16);});
  return checksum(b);
}
test('Archive preserves duplicate names by ordinal without overlap',()=>{
  const entries=directory(dir([{name:'A.MOD',size:4,offset:0},{name:'A.MOD',size:8,offset:4}]),12);
  assert.equal(entries.length,2);assert.notEqual(entries[0].id,entries[1].id);
});
test('Archive rejects corruption, truncation, overlapping and out-of-bounds extents',()=>{
  const good=dir([{name:'A.MOD',size:4,offset:0}]);const bad=Buffer.from(good);bad[8]^=1;
  assert.throws(()=>directory(bad,4),/checksum/);
  assert.throws(()=>directory(good.subarray(0,-1),4),/length/);
  assert.throws(()=>directory(good,3),/Invalid archive/);
  assert.throws(()=>directory(dir([{name:'A.MOD',size:4,offset:0},{name:'B.MOD',size:4,offset:2}]),8),/Invalid archive/);
});
test('Resource paths reject directory traversal and Windows device names',()=>{
  for(const name of ['../A','..','A/B','A\\B','CON.MOD','NUL','C:FILE'])assert.throws(()=>safeName(name));
});
function triangle(){
  const b=Buffer.alloc(160);b.writeUInt16LE(1);b.writeUInt32LE(3,80);b.writeInt16LE(4096,92);b.writeInt16LE(4096,104);b.writeUInt32LE(1,132);
  b.writeUInt16LE(0,144);b.writeUInt16LE(1,146);b.writeUInt16LE(2,148);return checksum(b);
}
test('Model indices are validated after checksum verification',()=>{
  const b=triangle();assert.equal(modelPack(b).models[0].faces.length,1);
  b.writeUInt16LE(3,148);checksum(b);assert.throws(()=>modelPack(b),/index/);
});
test('Texture RLE expansion cannot exceed page bound',()=>{
  const b=Buffer.alloc(35);b.writeUInt16LE(6,4);b.writeUInt16LE(1,9);b.writeUInt32LE(12,15);
  for(let p=19;p<31;p+=4){b.writeUInt16LE(32767,p);b.writeUInt16LE(123,p+2);}
  checksum(b);assert.throws(()=>texturePack(b),/page bound/);
});
test('Palette field addresses a VRAM row for 4-bit and 8-bit textures',()=>{
  const page=Buffer.alloc(0x20000);page.writeUInt16LE(0x4321,30*512);page.writeUInt16LE(31,(84*256+1)*2);
  assert.deepEqual(sample({pages:[page]},{word0:0,word1:84},0,30),[255,0,0,255]);
  page.writeUInt16LE(5,30*512);page.writeUInt16LE(31<<5,(84*256+5)*2);
  assert.deepEqual(sample({pages:[page]},{word0:256,word1:84},0,30),[0,255,0,255]);
  assert.deepEqual(color555(0),[0,0,0,0]);assert.deepEqual(color555(32768),[0,0,0,255]);
  assert.throws(()=>sample({pages:[page]},{word0:259,word1:84},255,30),/crosses/);
});
test('Animation matrices preserve 12 signed halfwords and exact chunk length',()=>{
  const bytes=Buffer.alloc(84);bytes.writeUInt16LE(256);bytes.writeUInt32LE(1,8);bytes.writeUInt32LE(1,24);
  for(let i=0;i<12;i++)bytes.writeInt16LE(i-6,60+i*2);
  const result=animation(bytes);assert.equal(result.length,84);assert.deepEqual(result.data.bones[0][0],Array.from({length:12},(_,i)=>i-6));
  assert.throws(()=>animation(bytes.subarray(0,-1)),/Truncated/);
});
if(process.env.CROC_CONTENT){
  test('Every imported room references valid geometry indices',()=>{
    const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(root+'/manifest.json'));
    const models=new Map(m.models.map(e=>[e.name,JSON.parse(fs.readFileSync(root+'/'+e.file))]));
    assert.equal(m.unsupported.length,0);
    for(const entry of m.maps){
      const room=JSON.parse(fs.readFileSync(root+'/'+entry.file));
      const pack=models.get('TK'+String(room.style).padStart(2,'0')+'_TRK.MOD');
      assert.ok(pack,entry.name);
      for(const tile of room.tracks)assert.ok(tile.index<pack.models.length,entry.name+': '+tile.index);
    }
    const textureEntries=m.entries.filter(e=>/^TK\d+_(TRK|ENM)\.BIN$/.test(e.name)||/^TB\d+\.BIN$/.test(e.name)||['FONT.BIN','FRONTEND.BIN','STILLGOH.BIN','INTRO.BIN','INTROJIG.BIN','OUTRO.BIN'].includes(e.name));
    assert.deepEqual(m.textures.map(e=>e.id).sort((a,b)=>a-b),textureEntries.map(e=>e.id).sort((a,b)=>a-b));assert.equal(m.wads.length,267);
    assert.equal(Object.keys(m.character.animations).length,56);
    const character=JSON.parse(fs.readFileSync(root+'/'+m.character.model));
    for(const [name,file] of Object.entries(m.character.animations)){
      const a=JSON.parse(fs.readFileSync(root+'/'+file));
      assert.equal(a.vertexCount,character.models[0].vertices.length,name);
      assert.equal(a.boneCount,character.models.length-1,name);
      for(const pose of a.bones)for(const bone of pose){
        assert.equal(bone.length,12,name);
        assert.ok(bone.every(v=>Number.isInteger(v)&&v>=-32768&&v<=32767),name);
        // Walk matrices are rotations. Other source poses intentionally include
        // scaled/interpolated transforms; never orthonormalize imported matrices.
        if(name==='CROCWALK.ANI')for(let row=0;row<3;row++)assert.ok(Math.abs(Math.hypot(...bone.slice(row*3,row*3+3))/4096-1)<0.01,name);
      }
    }
    // Validate the geometry actually referenced by all source rooms. The unused
    // whale pack TK16_TRK contains original dangling material IDs 111..113;
    // no source room selects that style. Preserve it instead of inventing art.
    for(const entry of m.maps){
      const room=JSON.parse(fs.readFileSync(root+'/'+entry.file)),name='TK'+String(room.style).padStart(2,'0')+'_TRK.MOD';
      const texture=m.textures.find(t=>t.name===name.replace('.MOD','.BIN'));
      assert.ok(texture,entry.name);
      for(const tile of room.tracks)for(const face of models.get(name).models[tile.index].faces)if(face.flags&1)assert.ok(face.material<texture.polygons,entry.name+': material index');
    }
  });
}
