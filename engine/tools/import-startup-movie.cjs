'use strict';
// Read the user's backup, retaining mixed MODE2 video/audio sectors for FFmpeg.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),{Disc}=require('./disc.cjs');
const [source,ffmpeg,movieOutput,temporaryInput]=process.argv.slice(2);
if(!source||!ffmpeg)throw Error('Usage: node tools/import-startup-movie.cjs <backup.bin> <ffmpeg.exe>');
const root=path.resolve(__dirname,'..'),disc=new Disc(source);
try {
  if(disc.sectorSize!==2352)throw Error('Original mixed-sector backup required');
  const entry=disc.files.find(e=>e.path==='/ARGOLOGO.STR');
  if(!entry)throw Error('Original Argonaut movie missing');
  const bytes=Buffer.alloc(Math.ceil(entry.size/2048)*2352);
  if(fs.readSync(disc.fd,bytes,0,bytes.length,entry.lba*2352)!==bytes.length)throw Error('Truncated movie');
  const input=temporaryInput||path.join(root,'build/argonaut-original.str');fs.mkdirSync(path.dirname(input),{recursive:true});fs.writeFileSync(input,bytes);
  const result=spawnSync(ffmpeg,['-hide_banner','-i',input,'-c:v','libtheora','-q:v','7','-c:a','libvorbis','-q:a','4','-y',movieOutput||path.join(root,'game/argonaut-logo.ogv')],{stdio:'inherit',windowsHide:true});
  if(result.status!==0)throw Error('Movie conversion failed');
} finally {disc.close();}
