/* SPDX-License-Identifier: GPL-2.0-only */
const zlib=require('node:zlib');
const crcTable=Array.from({length:256},(_,i)=>{let v=i;for(let n=0;n<8;n++)v=(v&1)?0xedb88320^(v>>>1):v>>>1;return v>>>0;});
function crc(bytes){let v=0xffffffff;for(const b of bytes)v=crcTable[(v^b)&255]^(v>>>8);return (v^0xffffffff)>>>0;}
function chunk(type,bytes){const t=Buffer.from(type),b=Buffer.alloc(12+bytes.length);b.writeUInt32BE(bytes.length);t.copy(b,4);bytes.copy(b,8);b.writeUInt32BE(crc(Buffer.concat([t,bytes])),8+bytes.length);return b;}
function png(width,height,rgba){
  if(rgba.length!==width*height*4)throw Error('Wrong PNG pixel buffer length');
  const header=Buffer.alloc(13);header.writeUInt32BE(width);header.writeUInt32BE(height,4);header[8]=8;header[9]=6;
  const scan=Buffer.alloc((width*4+1)*height);
  for(let y=0;y<height;y++)rgba.copy(scan,y*(width*4+1)+1,y*width*4,(y+1)*width*4);
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(scan)),chunk('IEND',Buffer.alloc(0))]);
}
function color555(word){return [Math.round((word&31)*255/31),Math.round(((word>>>5)&31)*255/31),Math.round(((word>>>10)&31)*255/31),word===0?0:255];}
function sampleWord(texture,poly,u,v){
  const mode=(poly.word0>>>8)&15,index=poly.word0&255,pageIndex=index>>>2,baseX=(index&3)*64;
  if(mode>2||pageIndex>=texture.pages.length)throw Error('Unsupported texture mode or page index');
  const shift=mode===0?2:mode===1?1:0,x=baseX+(u>>>shift);
  if(u<0||v<0||u>255||v>255||x>=256)throw Error('Texture coordinate crosses imported VRAM page');
  const packed=texture.pages[pageIndex].readUInt16LE((v*256+x)*2);
  if(mode===2)return packed;
  const palettePage=poly.word1>>>8,row=poly.word1&255;
  if(palettePage>=texture.pages.length)throw Error('Palette row outside imported VRAM');
  const paletteIndex=mode===0?(packed>>>((u&3)*4))&15:(packed>>>((u&1)*8))&255;
  return texture.pages[palettePage].readUInt16LE((row*256+paletteIndex)*2);
}
function sample(texture,poly,u,v){return color555(sampleWord(texture,poly,u,v));}
function atlas(texture,options={}){
  const width=1024,placements=[];let x=1,y=3,rowHeight=0;
  for(const [index,poly] of texture.polygons.entries()){
    const us=poly.uv.map(p=>p[0]),vs=poly.uv.map(p=>p[1]);
    const minU=Math.min(...us),minV=Math.min(...vs),w=Math.max(Math.max(...us)-minU+1,(options.dynamicU?.[index]??-1)+1),h=Math.max(...vs)-minV+1;
    if(x+w+1>width){x=1;y+=rowHeight+2;rowHeight=0;}
    placements.push({poly,x,y,w,h,minU,minV});x+=w+2;rowHeight=Math.max(rowHeight,h);
  }
  const used=y+rowHeight+1,height=2**Math.ceil(Math.log2(Math.max(2,used)));
  if(height>16384)throw Error('Texture atlas is too large');
  const pixels=Buffer.alloc(width*height*4),polygons=[];
  const mask=options.preserveMask?Buffer.alloc(width*height*4):null;
  pixels.fill(255,0,4); // White texel for untextured, vertex-colored polygons.
  for(const p of placements){
    for(let yy=-1;yy<=p.h;yy++)for(let xx=-1;xx<=p.w;xx++){
      const u=p.minU+Math.max(0,Math.min(p.w-1,xx)),v=p.minV+Math.max(0,Math.min(p.h-1,yy));
      const rgba=sample(texture,p.poly,u,v),offset=((p.y+yy)*width+p.x+xx)*4;
      for(let c=0;c<4;c++)pixels[offset+c]=rgba[c];
      if(mask){const word=sampleWord(texture,p.poly,u,v);mask[offset]=(word&0x8000)?255:0;mask[offset+1]=word===0?0:255;mask[offset+3]=255;}
    }
    // Source rectangles store bottom-left/right, then top-left/right in model
    // space (CrocUtils resources/crocpsxtex2.bt). PNG scanlines run downward,
    // while geometry() expects the low-V pair first. Keep the image upright
    // and swap the two coordinate pairs, including triangular face corners.
    const uv=p.poly.uv.map(([u,v])=>[(p.x+u-p.minU+0.5)/width,(p.y+v-p.minV+0.5)/height]);
    polygons.push({uv:[uv[2],uv[3],uv[0],uv[1]],mode:(p.poly.word0>>>8)&15,blend:(p.poly.word0>>>12)&3});
  }
  return {width,height,polygons,uvConvention:'model-low-v-first',image:png(width,height,pixels),rgba:pixels,...(mask?{maskImage:png(width,height,mask)}:{})};
}
function animationPatches(texture,options={}){
  if(!texture.animations?.length)return [];
  const base=atlas(texture,options),streams=[];
  for(const animation of texture.animations??[]){
    const frames=[],affected=Buffer.alloc(base.width*base.height);let left=base.width,top=base.height,right=-1,bottom=-1;
    for(let frame=0;frame<animation.frames;frame++){
      const pages=texture.pages.map(page=>Buffer.from(page));
      for(let y=0;y<animation.height;y++)animation.data.copy(pages[animation.page],((animation.y+y)*256+animation.x)*2,(frame*animation.height+y)*animation.width*2,(frame*animation.height+y+1)*animation.width*2);
      const pixels=atlas({...texture,pages},options).rgba;frames.push(pixels);
      for(let y=0;y<base.height;y++)for(let x=0;x<base.width;x++){
        const p=(y*base.width+x)*4;
        if(!pixels.subarray(p,p+4).equals(base.rgba.subarray(p,p+4))){affected[y*base.width+x]=1;left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
      }
    }
    if(right<left)continue;
    const width=right-left+1,height=bottom-top+1,pixels=Buffer.alloc(width*height*animation.frames*4);
    for(let frame=0;frame<animation.frames;frame++)for(let y=0;y<height;y++)frames[frame].copy(pixels,(frame*height+y)*width*4,((top+y)*base.width+left)*4,((top+y)*base.width+left+width)*4);
    const rectangles=[];
    for(let y=top;y<=bottom;y++)for(let x=left;x<=right;x++)if(affected[y*base.width+x]){
      const start=x;while(x<right&&affected[y*base.width+x+1])x++;
      const previous=rectangles.find(rect=>rect.x===start-left&&rect.width===x-start+1&&rect.y+rect.height===y-top);
      if(previous)previous.height++;else rectangles.push({x:start-left,y:y-top,width:x-start+1,height:1});
    }
    streams.push({frames:animation.frames,interval:animation.interval,x:left,y:top,width,height,rectangles,image:png(width,height*animation.frames,pixels)});
  }
  return streams;
}
module.exports={sample,sampleWord,color555,atlas,animationPatches,png,crc};
