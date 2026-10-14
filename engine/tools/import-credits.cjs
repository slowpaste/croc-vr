'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{credits}=require('./credits-codec.cjs');
function exportCredits(root,manifest){
 return ['CREDITS.BIN','CREDITS2.BIN'].map((name,variant)=>{
  const source=manifest.entries.find(entry=>entry.name===name),bytes=fs.readFileSync(path.join(root,source.file));
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==source.sha256)throw Error('Credits source changed');
  const data=credits(bytes),file='resources/'+name+'.json';fs.writeFileSync(path.join(root,file),JSON.stringify(data),{flag:'wx'});
  return {variant,name,file,sourceSha256:source.sha256};
 });
}
function importCredits(root){const file=path.join(root,'manifest.json'),manifest=JSON.parse(fs.readFileSync(file));if(manifest.credits)throw Error('Credits already imported');manifest.credits=exportCredits(root,manifest);fs.writeFileSync(file,JSON.stringify(manifest));return manifest.credits;}
if(require.main===module)console.log(JSON.stringify(importCredits(process.argv[2])));
module.exports={exportCredits,importCredits};
