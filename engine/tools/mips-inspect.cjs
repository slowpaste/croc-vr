/* SPDX-License-Identifier: GPL-2.0-only */
// Read-only disassembly aid for a user's PS-X executable. No original bytes saved.
const {Disc}=require('./disc.cjs');
const regs=['zero','at','v0','v1','a0','a1','a2','a3','t0','t1','t2','t3','t4','t5','t6','t7','s0','s1','s2','s3','s4','s5','s6','s7','t8','t9','k0','k1','gp','sp','fp','ra'];
function instruction(word,pc){
  const op=word>>>26,rs=(word>>>21)&31,rt=(word>>>16)&31,rd=(word>>>11)&31,sa=(word>>>6)&31,fn=word&63,imm=word&65535,simm=(imm<<16)>>16;
  if(word===0)return 'nop';
  if(op===18 && (rs&16) && fn===40)return 'gte.sqr sf='+((word>>>19)&1)+' lm='+((word>>>10)&1);
  if(op===50||op===58){const gte={9:'IR1',10:'IR2',11:'IR3',25:'MAC1',26:'MAC2',27:'MAC3'}[rt]||('r'+rt);return (op===50?'lwc2 ':'swc2 ')+gte+', '+simm+'('+regs[rs]+')';}
  if(op===0){
    if([0,2,3].includes(fn))return ({0:'sll',2:'srl',3:'sra'})[fn]+' '+regs[rd]+', '+regs[rt]+', '+sa;
    if([4,6,7].includes(fn))return ({4:'sllv',6:'srlv',7:'srav'})[fn]+' '+regs[rd]+', '+regs[rt]+', '+regs[rs];
    if(fn===8)return 'jr '+regs[rs];
    if(fn===9)return 'jalr '+regs[rd]+', '+regs[rs];
    const n={16:'mfhi',18:'mflo',24:'mult',25:'multu',26:'div',27:'divu',32:'add',33:'addu',34:'sub',35:'subu',36:'and',37:'or',38:'xor',39:'nor',42:'slt',43:'sltu'}[fn];
    if(n)return n+' '+([16,18].includes(fn)?regs[rd]:[24,25,26,27].includes(fn)?regs[rs]+', '+regs[rt]:regs[rd]+', '+regs[rs]+', '+regs[rt]);
  }
  if(op===2||op===3)return (op===2?'j ':'jal ')+'0x'+((((pc+4)&0xf0000000)|((word&0x03ffffff)<<2))>>>0).toString(16);
  if(op===15)return 'lui '+regs[rt]+', 0x'+imm.toString(16);
  const branch={4:'beq',5:'bne',6:'blez',7:'bgtz'}[op];
  if(branch)return branch+' '+regs[rs]+([4,5].includes(op)?', '+regs[rt]:'')+', 0x'+((pc+4+simm*4)>>>0).toString(16);
  if(op===1)return (rt===0?'bltz':rt===1?'bgez':'regimm')+' '+regs[rs]+', 0x'+((pc+4+simm*4)>>>0).toString(16);
  const calc={8:'addi',9:'addiu',10:'slti',11:'sltiu',12:'andi',13:'ori',14:'xori'}[op];
  if(calc)return calc+' '+regs[rt]+', '+regs[rs]+', '+(op>=12?'0x'+imm.toString(16):simm);
  const mem={32:'lb',33:'lh',34:'lwl',35:'lw',36:'lbu',37:'lhu',38:'lwr',40:'sb',41:'sh',42:'swl',43:'sw',46:'swr'}[op];
  if(mem)return mem+' '+regs[rt]+', '+simm+'('+regs[rs]+')';
  return 'word 0x'+word.toString(16).padStart(8,'0');
}
function inspect(source,start,count){
  const disc=new Disc(source);
  try{
    const b=disc.file('/CROC.EXE'),base=b.readUInt32LE(0x18);
    for(let pc=start;pc<start+count*4;pc+=4){const offset=pc-base+2048;if(offset<2048||offset+4>b.length)throw Error('Address outside executable');console.log(pc.toString(16)+' '+instruction(b.readUInt32LE(offset),pc));}
  }finally{disc.close();}
}
if(require.main===module)inspect(process.argv[2],Number(process.argv[3]),Number(process.argv[4]||80));
module.exports={instruction};
