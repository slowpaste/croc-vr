'use strict';
function sequence(bytes){
 if(bytes.length<15||bytes.toString('ascii',0,4)!=='pQES'||bytes.readUInt32BE(4)!==1)throw Error('Unsupported ambience sequence header');
 const division=bytes.readUInt16BE(8),tempo=bytes.readUIntBE(10,3);
 if(!division||!tempo)throw Error('Invalid ambience timing');
 let position=15,tick=0,running=0,ended=false;const events=[];
 function take(){if(position>=bytes.length)throw Error('Truncated sequence event');return bytes[position++];}
 function variable(){let value=0;for(let i=0;i<4;i++){const b=take();value=(value<<7)|(b&127);if(!(b&128))return value;}throw Error('Oversized sequence delta');}
 while(position<bytes.length){
  const offset=position,delta=variable();tick+=delta;
  let status=bytes[position];if(status>=128){status=take();if(status<240)running=status;}else{if(!running)throw Error('Missing sequence running status');status=running;}
  if(status===255){const type=take(),length=variable();if(type!==47||length!==0)throw Error('Unsupported original sequence meta event');events.push({offset,delta,tick,status,type,data:[]});ended=true;break;}
  if(status<128||status>=240)throw Error('Unsupported sequence status');
  const count=(status&240)===192||(status&240)===208?1:2,data=[];
  for(let i=0;i<count;i++){const value=take();if(value>=128)throw Error('Invalid sequence event data');data.push(value);}
  events.push({offset,delta,tick,status,data});
 }
 if(!ended||position!==bytes.length)throw Error('Missing terminal event or trailing sequence data');
 return {division,tempo,timeSignature:[bytes[13],bytes[14]],durationTicks:tick,events};
}
module.exports={sequence};
