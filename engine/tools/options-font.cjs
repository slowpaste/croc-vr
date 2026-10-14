'use strict';
const fs=require('node:fs'),crypto=require('node:crypto');
const {Disc}=require('./disc.cjs');
function extract(source){
 const disc=new Disc(source);
 try{
  const bytes=disc.file('/CROC.EXE');
  const executableSha256=crypto.createHash('sha256').update(bytes).digest('hex');
  if(executableSha256!=='f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996')throw Error('Unsupported font-table executable');
  const at=address=>address-bytes.readUInt32LE(24)+2048,glyphs={};
  for(const character of new Set('-U<>VFYB@*:$#^&{}|~ControlMethodABC;Forward]TurnLeft[TurnRight\\BackwardJumpFlipAttackCameraLeftstickmovesCrocRightstickmovescameraCenterLeftControllerandPressMoveleftstickinacompletecircle3timesthenpressCalibrationSuccessfulFailedUsingDefaultsRequires 1 blockSAVE GAMEOVERWRITE BLOCKOVERWRITE GAMECANCELRETURN TO MAP%0123456789GAME SAVEDMEMORY CARD PROBLEMOTHER OPTIONSQUIT GAMERETURNREALLY QUIT ?NOYES!CrocEmpty BlockDo you really wantto delete this block ?PLAY TRACKPAUSE TRACKSTOP TRACKNEXT TRACKPREVIOUS TRACKRETURN TO AUDIO OPTIONSUse directional buttonsto centerPress { when finished')){
   const code=character.charCodeAt(0);
   glyphs[code]={advance:bytes.readInt32LE(at(0x8006bf3c)+code*4),sprite:bytes.readInt32LE(at(0x8006b93c)+code*4),width:bytes.readUInt16LE(at(0x8006c13c)+code*2),height:bytes.readUInt16LE(at(0x8006c29c)+code*2),verticalOffset:bytes.readInt32LE(at(0x8006cb5c)+code*4)};
   if(glyphs[code].sprite<0||glyphs[code].width===0||glyphs[code].height===0)throw Error('Invalid original Options glyph '+character);
  }
  const headingGlyphs={};
  for(const character of new Set('OPTIONSCONTROLLERSET-UP AUDIO MISC CALIBRATE ANALOG LOAD GAME SAVE GAME DELETE BLOCK MUSIC PLAYER CENTER SCREEN')){
   const code=character.charCodeAt(0);
   headingGlyphs[code]={advance:bytes.readInt32LE(at(0x8006c75c)+code*4)+1,sprite:161+bytes.readInt32LE(at(0x8006c55c)+code*4),width:bytes.readInt32LE(at(0x8006c95c)+code*4),height:18};
  }
  const muteGlyphs={};
  for(const character of new Set('MUTENo analog controller foundNot available for analog controller')){
   const code=character.charCodeAt(0),width=bytes.readUInt16LE(at(0x8006c3fc)+code*2);
   muteGlyphs[code]={advance:width,sprite:bytes.readInt32LE(at(0x8006bb3c)+code*4),width,height:13};
  }
  return {schema:1,executableSha256,glyphs,headingGlyphs,muteGlyphs};
 }finally{disc.close();}
}
if(require.main===module)fs.writeFileSync(process.argv[3],JSON.stringify(extract(process.argv[2])));
module.exports={extract};









