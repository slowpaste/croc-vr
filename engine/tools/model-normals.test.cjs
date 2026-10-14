const {test}=require('node:test'),assert=require('node:assert/strict');
const {Disc,directory}=require('./disc.cjs'),{modelPack}=require('./asset-codecs.cjs');
test('original SAD normals and face headers are preserved byte for byte',{skip:!process.env.CROC_BACKUP},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const archive=disc.file('/CROCFILE.1'),entry=directory(disc.file('/CROCFILE.DIR'),archive.length).find(e=>e.name==='SAD00.MOD');
    const bytes=archive.subarray(entry.offset,entry.offset+entry.size),pack=modelPack(bytes);
    assert.equal(pack.flags,0);let p=4,normals=0;
    for(const model of pack.models){
      p+=76;const n=bytes.readUInt32LE(p);p+=4+n*8;
      assert.equal(model.sourceNormals.length,n);
      for(let i=0;i<n;i++,p+=8){assert.deepEqual(model.sourceNormals[i],Array.from({length:4},(_,j)=>bytes.readInt16LE(p+j*2)));normals++;}
      const faces=bytes.readUInt32LE(p);p+=4;
      assert.equal(model.faces.length,faces);
      for(let i=0;i<faces;i++,p+=20)assert.deepEqual(model.faces[i].sourceHeader,Array.from({length:4},(_,j)=>bytes.readInt16LE(p+j*2)));
    }
    assert.equal(normals,327);assert.equal(p,bytes.length-4);
  }finally{disc.close();}
});
