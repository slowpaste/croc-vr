/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {linkArchive}=require('./resource-linker.cjs');
test('Original menu cache resolves scene resources without changing gameplay bindings',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
  const bytes=name=>fs.readFileSync(path.join(root,m.entries.find(e=>e.name===name).file));
  const maps=m.maps.map(e=>({name:e.name,data:JSON.parse(fs.readFileSync(path.join(root,e.file)))}));
  const linked=linkArchive(bytes,maps);
  assert.deepEqual(linked.unresolvedRooms,{});
  const scenes=Object.entries(linked.rooms).filter(([name,r])=>r.menu);
  assert.equal(scenes.length,10);
  for(const [name,r]of scenes){
    assert.equal(r.player,null);assert.equal(r.playerFile,null);assert.equal(r.cameraOffset,null);assert.equal(r.redirectOffset,null);
    const terrain=m.resources.find(e=>e.owner===name.replace('.MAP','.WAD')&&e.offset===r.terrainOffset);
    const data=JSON.parse(fs.readFileSync(path.join(root,terrain.file)));
    const map=maps.find(e=>e.name===name).data;
    const bank=m.models.find(e=>e.name===`TK${String(map.style).padStart(2,'0')}_TRK.MOD`);
    assert.equal(data.models.length,bank.count);
    assert.ok(map.tracks.every(t=>Number(t.index)<data.models.length));
  }
  const identity=list=>list.map(b=>[b.kind,b.name,b.owner,b.offset]);
  for(const [name,r]of Object.entries(m.linkage.rooms))if(!linked.rooms[name].menu)assert.deepEqual(identity(linked.rooms[name].assets),identity(r.assets),name);
});
