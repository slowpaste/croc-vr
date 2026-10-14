const {test}=require('node:test'),assert=require('node:assert/strict');
const {Disc}=require('./disc.cjs'),{inspectCutscene}=require('./cutscene-sectors.cjs');
test('original SAD stream separates animation, XA and padding sectors',{skip:!process.env.CROC_BACKUP},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const data=inspectCutscene(disc,'/CUTS/SAD.AN2');
    assert.equal(data.sectors,1656);
    assert.deepEqual(data.channels.map(x=>[x.kind,x.channel,x.sectors]),[['data',1,1274],['audio',2,207],['padding',0,175]]);
    assert.deepEqual(data.headerWords,[290,3617,866,2315]);
    assert.equal(data.channels.reduce((n,x)=>n+x.sectors,0),data.sectors);
    assert.throws(()=>inspectCutscene(disc,'/CUTS/MISSING.AN2'),/Invalid raw/);
  }finally{disc.close();}
});
