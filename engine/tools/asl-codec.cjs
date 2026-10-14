/* SPDX-License-Identifier: GPL-2.0-only
 * New bounds-checked decoder informed by Stratigise's Croc1 interface spec.
 * Original game instructions are decoded only from the user's backup.
 */
'use strict';
const fs=require('node:fs');
const table=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'asl-interface.json'),'utf8').replace(/^\uFEFF/,'')).opcodes;
class Reader {
  constructor(bytes,end=bytes.length){this.b=bytes;this.p=0;this.end=end;}
  take(n){if(n<0||this.p+n>this.end)throw Error(`ASL read outside code at ${this.p}`);const b=this.b.subarray(this.p,this.p+n);this.p+=n;return b;}
  byte(){return this.take(1)[0];}
  short(){return this.take(2).readInt16LE();}
  word(){return this.take(4).readInt32LE();}
  text(){const size=this.byte();return this.take(size).toString('latin1').replace(/\0+$/,'');}
  expr(depth=0){
    if(depth>32)throw Error('ASL expression nesting limit');
    const terms=[];
    for(let count=0;count<10000;count++){
      const op=this.byte(),term={op};
      if([1,2,3,27,28,29,45].includes(op))term.index=this.short();
      else if(op===4)term.value=this.word();
      else if(op===19){
        term.kind=this.byte();
        if([1,2,3,4,5,80].includes(term.kind)){term.placeholder=this.word();term.name=this.text();}
        else if([81,142].includes(term.kind))term.placeholder=this.word();
        else if(term.kind===9){
          term.mode=this.byte();term.args=[this.expr(depth+1)];
          if(term.mode>1)term.args.push(this.expr(depth+1));
          if(term.mode>3)term.args.push(this.expr(depth+1),this.expr(depth+1));
        }else throw Error(`Unknown ASL asset kind ${term.kind} at ${this.p}`);
      }else if(![6,7,8,9,10,11,12,13,14,15,16,17,18,20,21,23,24,25,26,30,31,32,33,34,35,36,37,38].includes(op))throw Error(`Unknown ASL expression ${op} at ${this.p-1}`);
      terms.push(term);if(op===18||op===38)return terms;
    }
    throw Error('ASL expression does not terminate');
  }
  placeholder(allowEmpty){
    if(allowEmpty){if(this.p+4<=this.end&&this.b.readUInt32LE(this.p)===0)this.p+=4;return;}
    this.word();const value=this.word();if(value!==0)this.p-=4;
  }
}
function decode(bytes){
  if(bytes.length<8||bytes.readUInt32LE()!==bytes.length)throw Error('ASL size mismatch');
  const entry=bytes.readUInt16LE(4)+4,end=bytes.readUInt16LE(6)+4;
  if(end<8||end>bytes.length)throw Error('Invalid ASL code extent');
  const r=new Reader(bytes,end);r.p=8;
  const instructions=[],boundaries=new Set();
  while(r.p<end){
    const pc=r.p,op=r.byte(),signature=table[String(op)];
    if(!signature)throw Error(`Unknown ASL opcode ${op} at ${pc}`);
    const args=[],targets=[];
    for(const type of signature.slice(1)){
      if(type==='int8')args.push(r.byte());
      else if(type==='int16')args.push(r.short());
      else if(type==='int32')args.push(r.word());
      else if(type==='eval')args.push(r.expr());
      else if(type==='string')args.push(r.text());
      else if(type==='offset16'){const offset=r.short();const target=r.p+offset;args.push(target);targets.push(target);}
      else if(type==='address16'){const offset=r.short();const target=offset+4;args.push(target);targets.push(target);}
      else if(type==='placeholder32_64')r.placeholder(false);
      else if(type==='placeholder0_32')r.placeholder(true);
      else if(type==='varargs'){
        if(op===9){if(args[0]===2)args.push(r.expr());else if(args[0]===4)args.push(r.expr(),r.expr(),r.expr());}
        else if(op===26){for(let i=0;i<args[1];i++){const target=r.short()+4;targets.push(target);args.push({target,condition:r.expr()});}}
        else if([48,119,177].includes(op)){args.push(r.text());for(let i=0;i<args[0]-1;i++)args.push(r.expr());}
        else if(op===49){if(![1,8,9,11].includes(args[0]))args.push(r.expr());}
        else if([60,112].includes(op)){for(let i=0;i<args[0];i++)args.push(r.short());}
        else throw Error(`Unknown ASL variable arguments at ${pc}`);
      }else throw Error(`Unknown ASL argument kind ${type}`);
    }
    if(r.p<=pc)throw Error('ASL decoder did not advance');
    boundaries.add(pc);instructions.push({pc,op,name:signature[0],args,next:r.p,targets});
  }
  const invalidTargets=instructions.flatMap(i=>i.targets.filter(t=>t!==end&&!boundaries.has(t)).map(target=>({pc:i.pc,target})));
  const refs=new Reader(bytes);refs.p=end;
  const references=[];
  if(refs.p+2<=bytes.length){
    const count=refs.take(2).readUInt16LE();
    for(let i=0;i<count;i++){
      const kind=refs.byte();
      if(kind===0){references.push({kind,name:refs.text()});continue;}
      const offset=refs.take(2).readUInt16LE(),record={offset,kind};
      if(offset+4>end)throw Error(`ASL reference ${i}/${count} kind ${kind} offset ${offset} lies outside code ${end}`);
      if([1,2,3,4,5,7,8].includes(kind)){
        const nameReader=new Reader(bytes,end);nameReader.p=offset+4;record.name=nameReader.text();
        if(!record.name||!/^[\x20-\x7e]+$/.test(record.name))throw Error('Invalid ASL reference name');
        if([7,8].includes(kind))record.condition=nameReader.expr();
      }
      references.push(record);
    }
    if(((refs.p+3)&~3)!==bytes.length)throw Error('ASL reference table size mismatch');
  }
  return {entryField:bytes.readUInt16LE(4),entry,codeEnd:end,totalBytes:bytes.length,referenceBytes:bytes.length-end,references,instructions,invalidTargets};
}
module.exports={decode,Reader};
