import test from 'node:test';import assert from 'node:assert/strict';
import {createEffects} from './effects.mjs';
test('a stale RAF timestamp cannot increase particle life or create a negative radius',()=>{
 const names=['window','document','innerWidth','innerHeight','devicePixelRatio','requestAnimationFrame','cancelAnimationFrame','performance'],before=Object.fromEntries(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
 const queue=[],radii=[],ctx={setTransform(){},clearRect(){},beginPath(){},stroke(){},arc(x,y,r){assert(r>=0&&Number.isFinite(r));radii.push(r);}};
 const values={window:{addEventListener(){}},document:{hidden:false,querySelectorAll:()=>[]},innerWidth:390,innerHeight:844,devicePixelRatio:1,requestAnimationFrame:f=>(queue.push(f),queue.length),cancelAnimationFrame(){},performance:{now:()=>1000}};
 for(const [key,value] of Object.entries(values))Object.defineProperty(globalThis,key,{value,writable:true,configurable:true});
 let fx;
 try{const canvas={getContext:()=>ctx,dataset:{}},el={dataset:{},style:{setProperty(){}},getBoundingClientRect:()=>({x:0,y:0,width:50,height:50})};fx=createEffects(canvas,{matches:false});fx.ring(el);queue.shift()(900);for(let t=1050;t<=1500&&queue.length;t+=50)queue.shift()(t);assert.equal(radii[0],8);assert(radii.every((r,i)=>!i||r>=radii[i-1]));assert.equal(fx.stats.particles,0);}
 finally{fx?.clear();for(const k of names){if(before[k])Object.defineProperty(globalThis,k,before[k]);else delete globalThis[k];}}
});
