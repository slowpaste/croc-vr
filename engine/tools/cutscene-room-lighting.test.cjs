const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {mapData}=require('./asset-codecs.cjs');
test('SAD room lighting tail is retained byte for byte without changing map geometry',{skip:!process.env.CROC_CONTENT},()=>{
 const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),entry=m.entries.find(e=>e.name==='MP084_00.MAP'),bytes=fs.readFileSync(path.join(root,entry.file));
 const parsed=mapData(bytes,false,true),{sourceLighting,...geometry}=parsed;
 assert.deepEqual(geometry,mapData(bytes));
 assert.deepEqual(sourceLighting.pointRecords,[]);
 assert.deepEqual(sourceLighting.tail,Array.from(bytes.subarray(bytes.length-44,bytes.length-8)));
 assert.equal(sourceLighting.finalWord,bytes.readUInt32LE(bytes.length-8));
 const decoded=require('./cutscene-room-lighting.cjs').roomLighting(bytes);
 assert.deepEqual(decoded.lightMatrix,[0,4096,0,0,2048,3547,0,2048,-1]);
 assert.deepEqual(decoded.colorMatrix,[1024,4080,688,1024,4080,688,1024,2048,688]);
 assert.deepEqual(decoded.ambientBytes,[64,64,64]);
});
