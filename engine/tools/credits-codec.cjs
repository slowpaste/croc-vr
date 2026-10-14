'use strict';
const {checked}=require('./asset-codecs.cjs');
function credits(bytes){
 const payload=checked(bytes);
 if(payload.readUInt32LE(0)!==bytes.length-8)throw Error('Invalid credits size envelope');
 let offset=4,terminal=false;const commands=[];
 function text(){if(offset>=payload.length)throw Error('Truncated credits string');const count=payload[offset++];if(count>63||offset+count>payload.length)throw Error('Invalid credits string span');const value=payload.subarray(offset,offset+count).toString('latin1');offset+=count;return value;}
 while(offset<payload.length){
  const start=offset,op=payload[offset++];let command={offset:start-4,op};
  if([0,1,5].includes(op))command.text=text();
  else if(op===2){if(offset>=payload.length)throw Error('Truncated credits control');command.value=payload[offset++];}
  else if(op===4){command.name=text();command.detail=text();}
  else if(op===3){terminal=true;commands.push(command);break;}
  else throw Error('Unknown credits command '+op);
  commands.push(command);
 }
 if(!terminal||!payload.subarray(offset).every(value=>value===0))throw Error('Invalid credits terminal/padding');
 return {schema:1,commands};
}
function pages(data){
 const result=[];let current={lines:[],details:[]};
 for(const command of data.commands){
  if(command.op===0&&current.lines.length){result.push(current);current={lines:[],details:[]};}
  if([0,1,5].includes(command.op))current.lines.push({text:command.text,large:command.op!==1});
  else if(command.op===4)current.details.push({name:command.name,detail:command.detail});
  else if(command.op===3)break;
 }
 if(current.lines.length||current.details.length)result.push(current);
 return result;
}
module.exports={credits,pages};
