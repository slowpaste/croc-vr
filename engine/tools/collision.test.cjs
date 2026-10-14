/* SPDX-License-Identifier: GPL-2.0-only */
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {Cursor,collisionRecords,modelPack}=require('./asset-codecs.cjs'),{wad}=require('./wad-codecs.cjs');
test('collision records retain signed halfwords and exact offsets',()=>{
  const bytes=Buffer.alloc(92);for(let i=0;i<44;i++)bytes.writeInt16LE(i%2?-32768+i:32767-i,4+i*2);
  const c=new Cursor(bytes);c.p=4;const records=collisionRecords(c,2);
  assert.deepEqual(records.map(r=>r.offset),[4,48]);assert.equal(c.p,92);
  for(const r of records){const roundtrip=Buffer.alloc(44);r.halfwords.forEach((v,i)=>roundtrip.writeInt16LE(v,i*2));assert.deepEqual(roundtrip,bytes.subarray(r.offset,r.offset+44));}
  assert.throws(()=>collisionRecords(new Cursor(Buffer.alloc(43)),1),/Truncated/);
  assert.throws(()=>collisionRecords(new Cursor(Buffer.alloc(0)),20001),/Invalid collision/);
});
test('all imported collision records reproduce original model/WAD bytes',{skip:!process.env.CROC_CONTENT},()=>{
  const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));let recordCount=0,modelsChecked=0;
  function verify(source,data,imported){
    assert.deepEqual(imported,data);
    for(const model of data.models){modelsChecked++;for(const group of model.collision.groups)for(const r of group){
      assert.equal(r.halfwords.length,22);const bytes=Buffer.alloc(44);r.halfwords.forEach((v,i)=>bytes.writeInt16LE(v,i*2));
      assert.deepEqual(bytes,source.subarray(r.offset,r.offset+44));recordCount++;
    }}
  }
  for(const e of m.models){const raw=fs.readFileSync(path.join(root,m.entries.find(a=>a.id===e.id).file));verify(raw,modelPack(raw),JSON.parse(fs.readFileSync(path.join(root,e.file))));}
  for(const e of m.wads){const raw=fs.readFileSync(path.join(root,m.entries.find(a=>a.id===e.id).file));for(const chunk of wad(raw).chunks.filter(c=>c.type==='model')){
    const r=m.resources.find(r=>r.owner===e.name&&r.offset===chunk.offset&&r.type==='model');
    verify(raw.subarray(chunk.offset,chunk.offset+chunk.length),chunk.data,JSON.parse(fs.readFileSync(path.join(root,r.file))));
  }}
  assert.ok(recordCount>0);assert.ok(modelsChecked>3648);console.log(`Verified ${recordCount} collision records across ${modelsChecked} model headers`);
});
