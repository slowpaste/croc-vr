/* SPDX-License-Identifier: GPL-2.0-only */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {decode,Reader}=require('./asl-codec.cjs');
function script(code,refs=Buffer.from([0,0])){
  const end=8+code.length,length=(end+refs.length+3)&~3,b=Buffer.alloc(length);
  b.writeUInt32LE(length);b.writeUInt16LE(4,4);b.writeUInt16LE(end-4,6);code.copy(b,8);refs.copy(b,end);return b;
}
test('Decoder validates calls and rejects non-instruction branch destinations',()=>{
  const good=script(Buffer.from([28,7,0,59]));assert.equal(decode(good).invalidTargets.length,0);
  const bad=script(Buffer.from([28,6,0,59]));assert.equal(decode(bad).invalidTargets.length,1);
});
test('Short trigger tail does not read beyond code when optional zero field is absent',()=>{
  const d=decode(script(Buffer.from([49,1,4,0,59])));assert.equal(d.instructions.length,2);
});
test('External actor references use variable-length names rather than offsets',()=>{
  const d=decode(script(Buffer.from([59]),Buffer.from([1,0,0,4,67,114,111,99])));
  assert.deepEqual(d.references,[{kind:0,name:'Croc'}]);
});
test('Expressions reject missing returns and excessive reads',()=>{
  const r=new Reader(Buffer.from([4,1,0,0,0]));assert.throws(()=>r.expr(),/outside/);
});
if(process.env.CROC_CONTENT){
  test('All linked gameplay actor entry points and resource paths are valid',()=>{
    const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),defs=m.linkage.definitions;
    const gameplay=Object.entries(m.linkage.rooms).filter(([,room])=>!room.menu);
    assert.equal(defs.length,703);assert.equal(m.maps.length,310);assert.equal(gameplay.length,252);
    assert.equal(m.resources.filter(r=>r.type==='strategy').length,2253);
    for(const [name,room]of gameplay){
      const data=JSON.parse(fs.readFileSync(path.join(root,m.maps.find(e=>e.name===name).file)));
      const assets=[...m.linkage.bootstrap,...m.linkage.controllers[room.profile].assets,...room.assets];
      for(const entity of data.entities){
        const definition=defs.find(d=>d.name.startsWith(entity.name));assert.ok(definition,entity.name);
        const binding=assets.find(b=>b.kind===1&&b.name===definition.file);assert.ok(binding,name+': '+entity.name);
        const program=JSON.parse(fs.readFileSync(path.join(root,binding.file)));
        assert.equal(program.invalidTargets.length,0);
        assert.ok(program.instructions.some(i=>i.pc===definition.pc),name+': '+entity.name+' entry');
      }
      for(const file of [room.camera,room.terrain,room.background])assert.ok(fs.existsSync(path.join(root,file)),file);
    }
  });
}
