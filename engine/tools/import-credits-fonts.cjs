'use strict';
const fs=require('node:fs'),path=require('node:path'),{Disc}=require('./disc.cjs'),{fonts}=require('./credits-fonts.cjs');
function exportFonts(disc,content,manifest){
 const tables=JSON.parse(fs.readFileSync(path.join(content,manifest.runtimeTables))),codes=[];
 for(const entry of manifest.credits)for(const command of JSON.parse(fs.readFileSync(path.join(content,entry.file))).commands)if(command.text)for(const character of command.text)codes.push(character.charCodeAt(0));
 const data=fonts(disc.file('/CROC.EXE'),tables.executableSha256,codes),file='resources/credits-fonts.json';fs.writeFileSync(path.join(content,file),JSON.stringify(data),{flag:'wx'});return {file,texture:'FONT.BIN'};
}
function importFonts(backup,content){const disc=new Disc(backup);try{const p=path.join(content,'manifest.json'),m=JSON.parse(fs.readFileSync(p));if(m.creditsFonts)throw Error('Credits fonts already imported');m.creditsFonts=exportFonts(disc,content,m);fs.writeFileSync(p,JSON.stringify(m));return m.creditsFonts;}finally{disc.close();}}
if(require.main===module)console.log(JSON.stringify(importFonts(process.argv[2],process.argv[3])));
module.exports={exportFonts,importFonts};
