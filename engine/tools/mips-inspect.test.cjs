const {test}=require('node:test'),assert=require('node:assert/strict'),{instruction}=require('./mips-inspect.cjs');
test('radius helper decodes IR inputs, shifted square and unsaturated MAC outputs',()=>{
  assert.equal(instruction(0xc8890000,0),'lwc2 IR1, 0(a0)');
  assert.equal(instruction(0x4aa80428,0),'gte.sqr sf=1 lm=1');
  assert.equal(instruction(0xe8b90000,0),'swc2 MAC1, 0(a1)');
  assert.equal(instruction(0x4aa00428,0),'gte.sqr sf=0 lm=1');
});
