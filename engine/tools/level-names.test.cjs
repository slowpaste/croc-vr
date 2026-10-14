const {test}=require('node:test'),assert=require('node:assert/strict');
const {Disc,directory}=require('./disc.cjs'),{levelNames}=require('./level-names.cjs');
test('original startup names preserve100 relocated string entries',{skip:!process.env.CROC_BACKUP},()=>{
  const d=new Disc(process.env.CROC_BACKUP);
  try{
    const archive=d.file('/CROCFILE.1'),entry=directory(d.file('/CROCFILE.DIR'),archive.length).find(e=>e.name==='EXCLUDE.WAD');
    const bytes=archive.subarray(entry.offset,entry.offset+entry.size),data=levelNames(bytes);
    assert.equal(data.names.length,100);assert.equal(data.names[10],'and so the adventure begins');assert.equal(data.names[54],'secret sentinel');
    for(let i=0;i<100;i++){
      const p=data.sourceOffset+bytes.readUInt32LE(data.sourceOffset+i*8);
      assert.equal(data.names[i],bytes.subarray(p,bytes.indexOf(0,p)).toString('latin1'));
    }
    const invalid=Buffer.from(bytes);invalid.writeUInt32LE(0,data.sourceOffset);
    assert.throws(()=>levelNames(invalid),/pointer outside/);
    assert.throws(()=>levelNames(bytes.subarray(0,100)),/Invalid startup/);
  }finally{d.close();}
});
