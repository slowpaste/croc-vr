'use strict';
const fs=require('node:fs'),path=require('node:path');
function refresh(content){
 const manifest=JSON.parse(fs.readFileSync(path.join(content,'manifest.json')));let count=0;
 for(const [name,room] of Object.entries(manifest.linkage.rooms)){
  if(room.redirectOffset===null||!room.camera)continue;
  const owner=name.replace('.MAP','.WAD'),entry=manifest.entries.find(x=>x.name===owner);
  if(!entry)throw Error('Missing camera redirect source '+owner);
  const raw=fs.readFileSync(path.join(content,entry.file)),offset=room.redirectOffset;
  if(offset<0||offset+256>raw.length)throw Error('Camera redirect outside '+owner);
  const file=room.camera.replace(/-\d+\.json$/,'-'+offset+'.json');
  if(file===room.camera)throw Error('Unexpected camera resource path');
  fs.writeFileSync(path.join(content,file),JSON.stringify({values:Array.from(raw.subarray(offset,offset+256))}));count++;
 }
 console.log('CAMERA_REDIRECT_RESOURCES: '+count);
}
if(require.main===module)refresh(process.argv[2]);
module.exports={refresh};
