const {test}=require('node:test'),assert=require('node:assert/strict');
const {Disc}=require('./disc.cjs'),{readCutsceneData}=require('./cutscene-sectors.cjs'),{record}=require('./an2-records.cjs');
test('complete original SAD record stream and native limits',{skip:!process.env.CROC_BACKUP},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const bytes=readCutsceneData(disc,'/CUTS/SAD.AN2');
    let offset=0;
    for(let tag=290;tag>=0;tag--){
      const data=record(bytes,offset);
      assert.equal(data.tag,tag);assert.equal(data.end,tag===0);
      assert.equal(data.matrices.length,20);assert.equal(data.groups.length,3);
      assert.equal(data.payloadLength,7280);assert.equal(data.nextOffset-offset,8960);
      assert.ok(data.header.equals(bytes.subarray(offset+4,offset+28)));
      offset=data.nextOffset;
    }
    assert.equal(offset,2607360);assert.equal(bytes.length-offset,1792);
    assert.ok(bytes.subarray(offset).every(x=>x===0));
    assert.throws(()=>record(bytes.subarray(0,100)),/Truncated/);
    for(const [at,value,message]of[[0,4097,/tag/],[28,1025,/matrix count/],[752,1025,/group count/],[1676,10753,/payload length/]]){
      const invalid=Buffer.from(bytes.subarray(0,8960));invalid.writeUInt32LE(value,at);
      assert.throws(()=>record(invalid),message);
    }
  }finally{disc.close();}
});
