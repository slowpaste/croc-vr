'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {texturePack}=require('./asset-codecs.cjs'),{atlas}=require('./texture-atlas.cjs');
test('Original FONT.BIN glyph atlas and metrics retain source pixels and sprite rectangles',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  const entry=m.entries.find(e=>e.name==='FONT.BIN'),texture=m.textures.find(e=>e.name==='FONT.BIN');
  const parsed=texturePack(fs.readFileSync(path.join(root,entry.file))),decoded=atlas(parsed);
  assert.equal(parsed.polygons.length,188);assert.equal(parsed.pages.length,1);
  assert.ok(decoded.image.equals(fs.readFileSync(path.join(root,texture.image))));
  const exported=JSON.parse(fs.readFileSync(path.join(root,texture.file)));
  assert.deepEqual(exported.polygons,decoded.polygons);
  const runtime=JSON.parse(fs.readFileSync(path.join(root,m.runtimeTables)));
  for(const [code,glyph]of Object.entries(runtime.mainMenu.glyphs)){
    if(Number(code)<=32)continue;
    const uv=parsed.polygons[glyph.sprite].uv;
    assert.equal(Math.max(...uv.map(p=>p[0]))-Math.min(...uv.map(p=>p[0]))+1,glyph.width);
    assert.equal(Math.max(...uv.map(p=>p[1]))-Math.min(...uv.map(p=>p[1]))+1,glyph.height);
  }
});
