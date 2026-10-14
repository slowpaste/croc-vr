const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {Disc}=require('./disc.cjs'),{readCutsceneData}=require('./cutscene-sectors.cjs'),{record}=require('./an2-records.cjs'),{pose}=require('./an2-pose.cjs');
test('SAD rigid/deformed poses bind all23 original model parts',{skip:!process.env.CROC_BACKUP||!process.env.CROC_CONTENT},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const manifest=JSON.parse(fs.readFileSync(process.env.CROC_CONTENT+'/manifest.json'));
    const asset=manifest.models.find(m=>m.name==='SAD00.MOD');
    const models=JSON.parse(fs.readFileSync(process.env.CROC_CONTENT+'/'+asset.file)).models;
    const bytes=readCutsceneData(disc,'/CUTS/SAD.AN2');let offset=0;
    for(let tag=290;tag>=0;tag--){
      const raw=record(bytes,offset),decoded=pose(raw,models);offset=raw.nextOffset;
      assert.equal(decoded.parts.length,23);
      assert.equal(decoded.parts[0].scale,raw.matrices[0].readInt16LE(22));
      assert.deepEqual(decoded.parts.map(p=>p.id).sort((a,b)=>a-b),Array.from({length:23},(_,i)=>i));
      assert.deepEqual(decoded.parts.filter(p=>p.vertices).map(p=>[p.id,p.vertices.length]),[[9,42],[10,29],[11,29]]);
      if(tag===290){assert.deepEqual(decoded.camera.position,[3617,866,2315]);assert.deepEqual(decoded.camera.angles,[45,3050,2047]);assert.equal(decoded.camera.projectionDistance,320);}
    }
    const first=record(bytes);first.matrices[1]=Buffer.from(first.matrices[0]);
    const instances=pose(first,models);
    assert.equal(instances.parts[0].id,instances.parts[1].id);
    assert.equal(instances.parts.length,23);
    first.matrices[1].writeUInt32LE(models.length);
    assert.throws(()=>pose(first,models),/Invalid AN2 model index/);
  }finally{disc.close();}
});
