const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {credits,pages}=require('./credits-codec.cjs');
test('both original credits streams preserve page/type commands and distinct ending text',{skip:!process.env.CROC_CONTENT},()=>{
 const root=process.env.CROC_CONTENT,m=JSON.parse(fs.readFileSync(root+'/manifest.json'));
 for(const entry of m.credits){
  const source=m.entries.find(e=>e.name===entry.name),bytes=fs.readFileSync(root+'/'+source.file),data=credits(bytes);
  assert.deepEqual(data,JSON.parse(fs.readFileSync(root+'/'+entry.file)));
  const result=pages(data);assert.equal(result.length,entry.variant===0?31:34);
  assert.equal(data.commands.filter(c=>c.op===4).length,4);
  assert.equal(data.commands.at(-1).op,3);
  const texts=result.flatMap(p=>p.lines.map(l=>l.text));
  assert.equal(texts.includes('100% COMPLETE!'),entry.variant===1);
  assert.ok(entry.variant===0?texts.includes('Jigsaw Pieces'):texts.includes('TAKE CARE'));
  assert.throws(()=>credits(bytes.subarray(0,-1)),/checksum/i);
 }
});
