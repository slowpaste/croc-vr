/* SPDX-License-Identifier: GPL-2.0-only */
// Read data tables only. Original executable instructions are never exported.
'use strict';
const {createHash}=require('node:crypto');
const supported='f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996';
function runtimeTables(bytes){
  const executableSha256=createHash('sha256').update(bytes).digest('hex');
  if(executableSha256!==supported)throw Error('Unsupported executable revision for runtime data tables');
  const address=0x8006b0dc,offset=address-bytes.readUInt32LE(24)+2048;
  if(offset<2048||offset+240>bytes.length)throw Error('Runtime table outside executable payload');
  const sineAddress=0x8006d37c,sineOffset=sineAddress-bytes.readUInt32LE(24)+2048;
  if(sineOffset<2048||sineOffset+2050>bytes.length)throw Error('Sine table outside executable payload');
  const rotationAddress=0x8006e020,rotationOffset=rotationAddress-bytes.readUInt32LE(24)+2048;
  if(rotationOffset<2048||rotationOffset+16384>bytes.length)throw Error('Rotation table outside executable payload');
  const rotation={sourceAddress:rotationAddress,sourceSha256:createHash('sha256').update(bytes.subarray(rotationOffset,rotationOffset+16384)).digest('hex'),pairs:Array.from({length:4096},(_,i)=>[bytes.readInt16LE(rotationOffset+i*4),bytes.readInt16LE(rotationOffset+i*4+2)])};
  const rootAddress=0x8006db90,rootOffset=rootAddress-bytes.readUInt32LE(24)+2048;
  const distanceRoot={sourceAddress:rootAddress,sourceSha256:createHash('sha256').update(bytes.subarray(rootOffset,rootOffset+384)).digest('hex'),values:Array.from({length:192},(_,i)=>bytes.readInt16LE(rootOffset+i*2))};
  const angleAddress=0x80072020,angleOffset=angleAddress-bytes.readUInt32LE(24)+2048;
  if(angleOffset<2048||angleOffset+2050>bytes.length)throw Error('Angle table outside executable payload');
  const wallAngles={sourceAddress:angleAddress,sourceSha256:createHash('sha256').update(bytes.subarray(angleOffset,angleOffset+2050)).digest('hex'),values:Array.from({length:1025},(_,i)=>bytes.readInt16LE(angleOffset+i*2))};
  const mapYAddress=0x8006b058,mapYOffset=mapYAddress-bytes.readUInt32LE(24)+2048;
  const mapYScale={sourceAddress:mapYAddress,sourceSha256:createHash('sha256').update(bytes.subarray(mapYOffset,mapYOffset+100)).digest('hex'),values:Array.from({length:25},(_,i)=>bytes.readInt32LE(mapYOffset+i*4))};
  const blinkAddress=0x8006af58,blinkOffset=blinkAddress-bytes.readUInt32LE(24)+2048;
  const blink={sourceAddress:blinkAddress,sourceSha256:createHash('sha256').update(bytes.subarray(blinkOffset,blinkOffset+128)).digest('hex'),yScaleUnits:Array.from({length:4},(_,i)=>bytes.readInt16LE(blinkOffset+i*32+8))};
  const menuAddress=0x8006d320,menuOffset=menuAddress-bytes.readUInt32LE(24)+2048;
  if(menuOffset<2048||menuOffset+92>bytes.length)throw Error('Menu level table outside executable payload');
  const menuLevels={sourceAddress:menuAddress,sourceSha256:createHash('sha256').update(bytes.subarray(menuOffset,menuOffset+92)).digest('hex'),values:Array.from({length:46},(_,i)=>bytes.readUInt16LE(menuOffset+i*2))};
  const at=a=>a-bytes.readUInt32LE(24)+2048;
  const optionsStartup={sourceAddress:0x8004f9ac,musicVolume:bytes.readUInt32LE(at(0x8004fa10))&65535,effectsVolume:bytes.readUInt32LE(at(0x8004fa18))&65535,stereoFlag:bytes.readUInt32LE(at(0x8004f9f4))&65535};
  const label=(sourceAddress,y)=>{const begin=at(sourceAddress),end=bytes.indexOf(0,begin);if(begin<2048||end<begin)throw Error('Menu label outside executable payload');return {sourceAddress,y,text:bytes.subarray(begin,end).toString('ascii'),sourceSha256:createHash('sha256').update(bytes.subarray(begin,end+1)).digest('hex')};};
  const labels=[label(0x800100a4,156),label(0x80074908,170),label(0x800100b0,184),label(0x800100c8,198),label(0x800100bc,212)],credits=label(0x80074910,198);
  const stageResults={heading:label(0x8001213c,24),continuePrompt:label(0x8001214c,200)};
  const gameOver={heading:label(0x8001204c,24),explanation:label(0x80012058,48),passwordPrefix:label(0x80012074,80),glyphs:{},headingGlyphs:{}};
  gameOver.passwordAlphabet=Array.from(bytes.subarray(at(0x80074cbc),at(0x80074cbc)+5));
  gameOver.passwordAlphabetAddress=0x80074cbc;
  gameOver.passwordConnector=label(0x80074cc8,116);
  gameOver.returnPrompt=label(0x80012088,196);
  gameOver.clearColorAddress=0x800749fc;
  gameOver.clearColor=Array.from(bytes.subarray(at(0x800749fc),at(0x800749fc)+3));
  gameOver.passwordEntry={heading:label(0x8001209c,24),instructions:label(0x800120ac,48),deletePrompt:label(0x800120c8,182),cancelPrompt:label(0x800120dc,200)};
  gameOver.continueMenu={heading:label(0x800100e4,24),yes:label(0x8007491c,165),no:label(0x80074920,180)};
  gameOver.sequenceLighting={lightAddress:0x8006aed8,colorAddress:0x8006af18,ambientAddress:0x80074a10,
    lightMatrix:Array.from({length:9},(_,i)=>bytes.readInt16LE(at(0x8006aed8)+i*2)),
    colorMatrix:Array.from({length:9},(_,i)=>bytes.readInt16LE(at(0x8006af18)+i*2)),
    ambientBytes:Array.from(bytes.subarray(at(0x80074a10),at(0x80074a10)+3)),textureBase:Array.from(bytes.subarray(at(0x80074934),at(0x80074934)+3))};
  gameOver.nativeModes={entryAddress:0x800101f0,drawAddress:0x80010290,entry:Array.from({length:15},(_,i)=>bytes.readUInt32LE(at(0x800101f0)+i*4)),draw:Array.from({length:15},(_,i)=>bytes.readUInt32LE(at(0x80010290)+i*4))};
  gameOver.sequenceScenes={sourceAddress:0x8006d074,records:Array.from({length:24},(_,i)=>{
    const pointer=bytes.readUInt32LE(at(0x8006d074)+i*4),p=at(pointer);
    return {sourceAddress:pointer,prefix:label(bytes.readUInt32LE(p),0).text,modelCount:bytes.readUInt32LE(p+4),level:bytes.readUInt32LE(p+8),firstRoom:bytes.readUInt32LE(p+12)};
  })};
  gameOver.stageNameGlyphs={};
  for(let code=0;code<256;code++){
    const width=bytes.readUInt16LE(at(0x8006c3fc)+code*2);
    gameOver.stageNameGlyphs[code]={advance:width,width,height:13,sprite:bytes.readInt32LE(at(0x8006bb3c)+code*4)};
  }
  for(const c of new Set(gameOver.explanation.text+gameOver.passwordPrefix.text+gameOver.passwordConnector.text+gameOver.returnPrompt.text+gameOver.passwordEntry.instructions.text+gameOver.passwordEntry.deletePrompt.text+gameOver.passwordEntry.cancelPrompt.text+gameOver.continueMenu.yes.text+gameOver.continueMenu.no.text+String.fromCharCode(...gameOver.passwordAlphabet))){
    const code=c.charCodeAt(0);
    gameOver.glyphs[code]={advance:bytes.readInt32LE(at(0x8006bf3c)+code*4),sprite:bytes.readInt32LE(at(0x8006b93c)+code*4),width:bytes.readUInt16LE(at(0x8006c13c)+code*2),height:bytes.readUInt16LE(at(0x8006c29c)+code*2)};
  }
  for(const c of new Set(gameOver.heading.text+gameOver.passwordEntry.heading.text+gameOver.continueMenu.heading.text)){
    const code=c.charCodeAt(0);
    gameOver.headingGlyphs[code]={advance:bytes.readInt32LE(at(0x8006c75c)+code*4)+1,sprite:161+bytes.readInt32LE(at(0x8006c55c)+code*4),width:bytes.readInt32LE(at(0x8006c95c)+code*4),height:18};
  }
  stageResults.sounds={confirm:{name:label(0x80074a58,0).text,volume:80,pitch:24},life:{name:label(0x80074a70,0).text,volume:75,pitch:24},crystal:{name:label(0x80074a60,0).text,volume:25,pitch:72}};
  const glyphs={};
  for(const c of new Set(labels.map(x=>x.text).join('')+credits.text)){
    const code=c.charCodeAt(0);
    glyphs[code]={advance:bytes.readInt32LE(at(0x8006bf3c)+code*4),sprite:bytes.readInt32LE(at(0x8006b93c)+code*4),width:bytes.readUInt16LE(at(0x8006c13c)+code*2),height:bytes.readUInt16LE(at(0x8006c29c)+code*2)};
  }
  const titlePrompt=label(0x800100d8,180);
  const mainMenu={labels,credits,titlePrompt,glyphs,centerX:256};
  stageResults.glyphs={};
  for(const c of new Set(stageResults.heading.text+stageResults.continuePrompt.text)){
    const code=c.charCodeAt(0);
    stageResults.glyphs[code]={advance:bytes.readInt32LE(at(0x8006bf3c)+code*4),sprite:bytes.readInt32LE(at(0x8006bd3c)+code*4),width:bytes.readUInt16LE(at(0x8006c13c)+code*2),height:bytes.readUInt16LE(at(0x8006c29c)+code*2)};
  }
  const demoAddress=0x8006aeb0,demoOffset=at(demoAddress);
  const attractDemos={sourceAddress:demoAddress,sourceSha256:createHash('sha256').update(bytes.subarray(demoOffset,demoOffset+40)).digest('hex'),destinations:Array.from({length:5},(_,i)=>[bytes.readInt32LE(demoOffset+i*8),bytes.readInt32LE(demoOffset+i*8+4)])};
  const cueAddress=0x8006d0d4,cueOffset=at(cueAddress);
  const musicCues={sourceAddress:cueAddress,sourceSha256:createHash('sha256').update(bytes.subarray(cueOffset,cueOffset+520)).digest('hex'),pairs:Array.from({length:65},(_,i)=>[bytes.readUInt32LE(cueOffset+i*8),bytes.readUInt32LE(cueOffset+i*8+4)])};
  const specialAddress=0x8006d2dc,specialOffset=at(specialAddress);
  musicCues.mode8={sourceAddress:specialAddress,sourceSha256:createHash('sha256').update(bytes.subarray(specialOffset,specialOffset+65)).digest('hex'),channels:Array.from(bytes.subarray(specialOffset,specialOffset+65))};
  return {schema:1,executableSha256,optionsStartup,rotation,distanceRoot,wallAngles,mapYScale,blink,menuLevels,mainMenu,stageResults,gameOver,attractDemos,musicCues,wobble:{sourceAddress:address,sourceSha256:createHash('sha256').update(bytes.subarray(offset,offset+240)).digest('hex'),verticalDeltas:Array.from({length:60},(_,i)=>bytes.readInt32LE(offset+i*4)),unitsPerCell:4096},trigonometry:{sourceAddress:sineAddress,sourceSha256:createHash('sha256').update(bytes.subarray(sineOffset,sineOffset+2050)).digest('hex'),quarterSine:Array.from({length:1025},(_,i)=>bytes.readInt16LE(sineOffset+i*2)),unitsPerTurn:4096}};
}
module.exports={runtimeTables};
