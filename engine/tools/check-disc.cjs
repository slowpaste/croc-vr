'use strict';
const {Disc}=require('./disc.cjs');
const crypto=require('node:crypto');
const disc=new Disc(process.argv[2]);
try {
  if(disc.volume.trim()!=='CROC')throw Error('Select a supported Croc: Legend of the Gobbos PlayStation disc.');
  for(const name of ['/CROCFILE.1','/CROCFILE.DIR','/CROC.EXE'])if(!disc.files.some(e=>e.path===name))throw Error('Croc disc file missing: '+name);
  if(disc.sectorSize!==2352)throw Error('This cooked 2048-byte ISO lacks original mixed-sector movie/audio data. Use a 2352-byte PlayStation backup (.bin or raw .iso).');
  const executableHash=crypto.createHash('sha256').update(disc.file('/CROC.EXE')).digest('hex');
  if(executableHash!=='f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996')throw Error('This Croc disc revision is not yet supported. See the supported CROC.EXE revision in README.md.');
  console.log('Croc PlayStation disc validated; original mixed-sector audio and movies are available.');
} finally {disc.close();}
