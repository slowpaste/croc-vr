'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {Disc,directory}=require('./disc.cjs'),{bootstrapMusicBounds,musicBounds}=require('./music-bounds.cjs');
test('bootstrap music block rejects malformed envelope and span',()=>{
  assert.throws(()=>bootstrapMusicBounds(Buffer.alloc(12)));
  const data=Buffer.alloc(300);data.writeUInt32LE(292,0);data.writeUInt32LE(292,4);data.writeUInt32LE(284,8);
  assert.equal(bootstrapMusicBounds(data).endSectorOffsets.length,70);
  data.writeUInt32LE(280,8);assert.throws(()=>bootstrapMusicBounds(data));
});
test('supported backup boots MUSIC catalog from EXCLUDE first block',{skip:!process.env.CROC_BACKUP},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const archive=disc.file('/CROCFILE.1'),entries=directory(disc.file('/CROCFILE.DIR'),archive.length);
    const raw=name=>{const entry=entries.find(x=>x.name===name);assert.ok(entry);return archive.subarray(entry.offset,entry.offset+entry.size);};
    const bootstrap=bootstrapMusicBounds(raw('EXCLUDE.WAD'));
    assert.deepEqual(bootstrap.endSectorOffsets,musicBounds(raw('MUSIC.BIN')).endSectorOffsets);
    assert.notDeepEqual(bootstrap.endSectorOffsets,musicBounds(raw('MAGMUS.BIN')).endSectorOffsets);
    assert.equal(bootstrap.endSectorOffsets[63],600);
  }finally{disc.close();}
});
