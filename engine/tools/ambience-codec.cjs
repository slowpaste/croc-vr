'use strict';
const {Cursor,checked}=require('./asset-codecs.cjs');
const crypto=require('node:crypto');
function parse(bytes){
 const cursor=new Cursor(checked(bytes)),chunks=[];
 for(const kind of ['sequence','bankHeader','bankBody']){
  const length=cursor.u32();
  if(!length)throw Error('Empty ambience '+kind);
  const data=cursor.take(length);
  chunks.push({kind,data,sha256:crypto.createHash('sha256').update(data).digest('hex')});
 }
 if(cursor.p!==cursor.bytes.length)throw Error('Trailing ambience data');
 if(chunks[0].data.length<15||chunks[0].data.toString('ascii',0,4)!=='pQES')throw Error('Invalid original ambience sequence');
 if(chunks[1].data.length<32||chunks[1].data.toString('ascii',0,4)!=='pBAV')throw Error('Invalid original ambience bank');
 if(chunks[2].data.length%16)throw Error('Partial ambience sound block');
 return chunks;
}
module.exports={parse};
