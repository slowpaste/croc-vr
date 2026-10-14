/* SPDX-License-Identifier: GPL-2.0-only */
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {Disc}=require('./disc.cjs'),{runtimeTables}=require('./runtime-tables.cjs');
test('unrecognized and truncated executable revisions are rejected',()=>{
  assert.throws(()=>runtimeTables(Buffer.alloc(64)),/Unsupported executable revision/);
});
test('imported table matches the supported backup data byte for byte',{skip:!process.env.CROC_BACKUP},()=>{
  const disc=new Disc(process.env.CROC_BACKUP);
  try{
    const exe=disc.file('/CROC.EXE'),tables=runtimeTables(exe),offset=tables.wobble.sourceAddress-exe.readUInt32LE(24)+2048;
    for(const [address,word] of [[0x80019ab8,0x00051883],[0x80019abc,0x00051103],[0x80019ac4,0x00051183],[0x80019acc,0x00051203]])assert.equal(exe.readUInt32LE(address-exe.readUInt32LE(24)+2048),word);
    for(const [address,word] of [[0x80012d30,0x24040200],[0x80012d40,0x240500f0],[0x80012d44,0x24040200],[0x80012d4c,0x24050180],[0x800160bc,0x00102042],[0x800160c4,0x00112842]])assert.equal(exe.readUInt32LE(address-exe.readUInt32LE(24)+2048),word);
    assert.deepEqual(tables.optionsStartup,{sourceAddress:0x8004f9ac,musicVolume:80,effectsVolume:127,stereoFlag:1});
    for(const [address,word] of [[0x8004f9f4,0x24020001],[0x8004f9fc,0xac224fd8],[0x8004fa10,0x24020050],[0x8004fa14,0xa7820260],[0x8004fa18,0x2402007f],[0x8004fa1c,0xa7820262]])assert.equal(exe.readUInt32LE(address-exe.readUInt32LE(24)+2048),word);
    const streamMode=0x80023000-exe.readUInt32LE(24)+2048;
    assert.equal(exe.readUInt32LE(streamMode),0x240200c0); // 192: double speed + XA decode.
    assert.equal(exe.readUInt32LE(streamMode+8),0x2404000e); // Setmode command14.
    // Native scene fade dispatch: unsigned(scene-10)<9 selects white kind3;
    // every other scene, including SAD20, selects black kind1.
    const fadeDispatch=0x80050368-exe.readUInt32LE(24)+2048;
    assert.deepEqual(Array.from({length:9},(_,i)=>exe.readUInt32LE(fadeDispatch+i*4)),[
      0x8faa0290,0x00000000,0x2542fff6,0x2c420009,0x10400002,
      0x24040001,0x24040003,0x0c00f6d8,0x00000000
    ]);
    assert.equal(tables.wobble.verticalDeltas.length,60);
    for(let i=0;i<60;i++)assert.equal(tables.wobble.verticalDeltas[i],exe.readInt32LE(offset+i*4));
    const sineOffset=tables.trigonometry.sourceAddress-exe.readUInt32LE(24)+2048;
    assert.equal(tables.trigonometry.quarterSine.length,1025);
    for(let i=0;i<1025;i++)assert.equal(tables.trigonometry.quarterSine[i],exe.readInt16LE(sineOffset+i*2));
    const rotationOffset=tables.rotation.sourceAddress-exe.readUInt32LE(24)+2048;
    assert.equal(tables.rotation.pairs.length,4096);
    for(let i=0;i<4096;i++)assert.deepEqual(tables.rotation.pairs[i],[exe.readInt16LE(rotationOffset+i*4),exe.readInt16LE(rotationOffset+i*4+2)]);
    const rootOffset=tables.distanceRoot.sourceAddress-exe.readUInt32LE(24)+2048;
    const menuOffset=tables.menuLevels.sourceAddress-exe.readUInt32LE(24)+2048;
    assert.equal(tables.menuLevels.values.length,46);
    for(let i=0;i<46;i++)assert.equal(tables.menuLevels.values[i],exe.readUInt16LE(menuOffset+i*2));
    assert.deepEqual(tables.menuLevels.values.slice(0,10),[10,11,12,13,18,14,15,16,17,19]);
    assert.deepEqual(tables.menuLevels.values.slice(40),[50,51,52,53,54,0]);
    assert.deepEqual(tables.mainMenu.labels.map(x=>x.text),['START GAME','OPTIONS','LOAD GAME','ENTER PASSWORD','SHOW INTRO']);
    assert.equal(tables.mainMenu.credits.text,'CREDITS');
    assert.equal(tables.mainMenu.titlePrompt.text,'PRESS START');
    assert.equal(tables.mainMenu.titlePrompt.sourceAddress,0x800100d8);
    assert.equal(tables.stageResults.heading.text,'LEVEL COMPLETE!');
    assert.equal(tables.stageResults.heading.y,24);
    assert.equal(tables.stageResults.continuePrompt.text,'= TO CONTINUE');
    assert.equal(tables.stageResults.continuePrompt.y,200);
    assert.ok(tables.stageResults.glyphs[33]);
    assert.ok(tables.stageResults.glyphs[61]);
    assert.equal(tables.gameOver.heading.text,'Password');
    assert.equal(tables.gameOver.explanation.text,'allows level access only');
    assert.equal(tables.gameOver.passwordPrefix.text,'The password for');
    assert.equal(tables.gameOver.passwordConnector.text,'is');
    assert.equal(tables.gameOver.passwordConnector.y,116);
    assert.equal(tables.gameOver.passwordEntry.heading.text,'Enter Password');
    assert.deepEqual(Object.values(tables.gameOver.continueMenu).map(x=>[x.text,x.y]),[['CONTINUE GAME',24],['YES',165],['NO',180]]);
    for(let i=0;i<9;i++){
      assert.equal(tables.gameOver.sequenceLighting.lightMatrix[i],exe.readInt16LE(2048+0x5aed8+i*2));
      assert.equal(tables.gameOver.sequenceLighting.colorMatrix[i],exe.readInt16LE(2048+0x5af18+i*2));
    }
    assert.deepEqual(tables.gameOver.sequenceLighting.ambientBytes,Array.from(exe.subarray(2048+0x64a10,2048+0x64a10+3)));
    assert.deepEqual(tables.gameOver.sequenceLighting.textureBase,Array.from(exe.subarray(2048+0x64934,2048+0x64934+3)));
    for(let mode=0;mode<15;mode++){
      assert.equal(tables.gameOver.nativeModes.entry[mode],exe.readUInt32LE(2048+0x1f0+mode*4));
      assert.equal(tables.gameOver.nativeModes.draw[mode],exe.readUInt32LE(2048+0x290+mode*4));
    }
    assert.equal(tables.gameOver.nativeModes.entry[14],0x8001334c);
    assert.equal(tables.gameOver.nativeModes.draw[14],0x80014138);
    assert.equal(tables.gameOver.nativeModes.draw[12],0x800141a8);
    assert.equal(tables.gameOver.nativeModes.draw[13],0x80014198);
    for(let i=0;i<24;i++){
      const record=tables.gameOver.sequenceScenes.records[i],p=2048+record.sourceAddress-exe.readUInt32LE(24);
      assert.equal(record.sourceAddress,exe.readUInt32LE(2048+0x5d074+i*4));
      assert.equal(record.modelCount,exe.readUInt32LE(p+4));
      assert.equal(record.level,exe.readUInt32LE(p+8));
      assert.equal(record.firstRoom,exe.readUInt32LE(p+12));
    }
    assert.deepEqual(Object.values(tables.gameOver.sequenceScenes.records[20]).slice(1),['SAD',1,84,0]);
    assert.equal(tables.gameOver.passwordEntry.instructions.text,'Using directional buttons');
    assert.equal(tables.gameOver.passwordEntry.deletePrompt.y,182);
    assert.equal(tables.gameOver.passwordEntry.cancelPrompt.y,200);
    assert.deepEqual(tables.gameOver.clearColor,Array.from(exe.subarray(2048+0x649fc,2048+0x649fc+3)));
    for(let code=0;code<256;code++){
      const glyph=tables.gameOver.stageNameGlyphs[code];
      assert.equal(glyph.width,exe.readUInt16LE(2048+0x6c3fc-0x10000+code*2));
      assert.equal(glyph.sprite,exe.readInt32LE(2048+0x6bb3c-0x10000+code*4));
    }
    assert.deepEqual(tables.gameOver.passwordAlphabet,Array.from(exe.subarray(2048+0x64cbc,2048+0x64cbc+5)));
    for(const [code,glyph]of Object.entries(tables.gameOver.headingGlyphs)){
      assert.equal(glyph.sprite,161+exe.readInt32LE(2048+0x8006c55c-exe.readUInt32LE(24)+Number(code)*4));
      assert.equal(glyph.advance,1+exe.readInt32LE(2048+0x8006c75c-exe.readUInt32LE(24)+Number(code)*4));
      assert.equal(glyph.width,exe.readInt32LE(2048+0x8006c95c-exe.readUInt32LE(24)+Number(code)*4));
    }
    for(const [code,glyph]of Object.entries(tables.stageResults.glyphs))assert.equal(glyph.sprite,exe.readInt32LE(2048+0x8006bd3c-exe.readUInt32LE(24)+Number(code)*4));
    assert.deepEqual(tables.stageResults.sounds,{confirm:{name:'START',volume:80,pitch:24},life:{name:'SEEDRED',volume:75,pitch:24},crystal:{name:'CRYS',volume:25,pitch:72}});
    assert.equal(tables.musicCues.pairs.length,65);
    assert.equal(tables.musicCues.mode8.channels.length,65);
    for(let cue=0;cue<65;cue++)assert.equal(tables.musicCues.mode8.channels[cue],exe[2048+tables.musicCues.mode8.sourceAddress-exe.readUInt32LE(24)+cue]);
    for(let cue=0;cue<65;cue++)for(let variant=0;variant<2;variant++)assert.equal(tables.musicCues.pairs[cue][variant],exe.readUInt32LE(2048+tables.musicCues.sourceAddress-exe.readUInt32LE(24)+cue*8+variant*4));
    assert.deepEqual(tables.attractDemos.destinations,[[15,0],[16,0],[20,0],[30,1],[41,0]]);
    for(let i=0;i<5;i++)for(let axis=0;axis<2;axis++)assert.equal(tables.attractDemos.destinations[i][axis],exe.readInt32LE(2048+tables.attractDemos.sourceAddress-exe.readUInt32LE(24)+i*8+axis*4));
    for(const [code,glyph]of Object.entries(tables.mainMenu.glyphs)){
      const at=a=>a-exe.readUInt32LE(24)+2048;
      assert.equal(glyph.advance,exe.readInt32LE(at(0x8006bf3c)+Number(code)*4));
      assert.equal(glyph.sprite,exe.readInt32LE(at(0x8006b93c)+Number(code)*4));
      assert.equal(glyph.width,exe.readUInt16LE(at(0x8006c13c)+Number(code)*2));
      assert.equal(glyph.height,exe.readUInt16LE(at(0x8006c29c)+Number(code)*2));
    }
    const blinkOffset=tables.blink.sourceAddress-exe.readUInt32LE(24)+2048;
    for(let i=0;i<4;i++)assert.equal(tables.blink.yScaleUnits[i],exe.readInt16LE(blinkOffset+i*32+8));
    const mapYOffset=tables.mapYScale.sourceAddress-exe.readUInt32LE(24)+2048;
    for(let i=0;i<25;i++)assert.equal(tables.mapYScale.values[i],exe.readInt32LE(mapYOffset+i*4));
    const angleOffset=tables.wallAngles.sourceAddress-exe.readUInt32LE(24)+2048;
    assert.equal(tables.wallAngles.values.length,1025);
    for(let i=0;i<1025;i++)assert.equal(tables.wallAngles.values[i],exe.readInt16LE(angleOffset+i*2));
    for(let i=0;i<192;i++)assert.equal(tables.distanceRoot.values[i],exe.readInt16LE(rootOffset+i*2));
    if(process.env.CROC_CONTENT)assert.deepEqual(JSON.parse(fs.readFileSync(process.env.CROC_CONTENT+'/resources/runtime-tables.json')),tables);
  }finally{disc.close();}
});
