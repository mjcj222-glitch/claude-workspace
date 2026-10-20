// Pure fixed-step positional dynamics. Coordinates, contacts and saved state share one world.
export const FLOW=Object.freeze({width:420,height:440,dt:1/120,gravity:2000,gap:5,steps:720});
const quant=n=>Math.round(n*10000)/10000;
function hash(seed,id){let n=(seed^Math.imul(id,2654435761))>>>0;n^=n>>>16;n=Math.imul(n,2246822507);n^=n>>>13;return (n>>>0)/4294967296;}
const bodyRadius=(seed,id)=>28+hash(seed,id)*3;
const clampBody=b=>{b.x=Math.max(b.r,Math.min(FLOW.width-b.r,b.x));b.y=Math.min(FLOW.height-b.r,b.y);if(!b.incoming)b.y=Math.max(b.r,b.y);};
export function flowNeighbors(board,i){const a=board[i];if(!a)return [];return board.flatMap((b,j)=>i!==j&&Math.hypot(a.x-b.x,a.y-b.y)<=a.r+b.r+FLOW.gap?[j]:[]);}
export function flowHit(board,x,y){let best=-1,distance=Infinity;board.forEach((t,i)=>{const d=Math.hypot(t.x-x,t.y-y);if(d<=t.r&&d<distance){distance=d;best=i;}});return best;}
export function validFlowBoard(board){if(!Array.isArray(board)||board.length!==42)return false;for(let i=0;i<board.length;i++){const a=board[i];if(!['x','y','r','angle'].every(k=>Number.isFinite(a[k]))||a.r<28||a.r>31||Math.abs(a.angle)>180||a.x<a.r-.1||a.x>FLOW.width-a.r+.1||a.y<a.r-.1||a.y>FLOW.height-a.r+.1)return false;for(let j=0;j<i;j++){const b=board[j];if(Math.hypot(a.x-b.x,a.y-b.y)<a.r+b.r-.12)return false;}}return true;}
function resolve(bodies,iterations,tolerance=0){for(let k=0;k<iterations;k++){let worst=0;for(const b of bodies)clampBody(b);for(let i=0;i<bodies.length;i++)for(let j=i+1;j<bodies.length;j++){const a=bodies[i],b=bodies[j],dx=b.x-a.x,dy=b.y-a.y,limit=a.r+b.r+.4,d2=dx*dx+dy*dy;if(d2>=limit*limit)continue;const d=Math.sqrt(d2);worst=Math.max(worst,limit-d);const nx=d>.0001?dx/d:((a.id+b.id)%2?1:-1),ny=d>.0001?dy/d:0,move=(limit-d)*.5;a.x-=nx*move;a.y-=ny*move;b.x+=nx*move;b.y+=ny*move;}if(tolerance&&worst<tolerance)break;}for(const b of bodies)clampBody(b);}
export function settleBodies(tiles,seed,{trace=false}={}){
 let spawn=0;const bodies=tiles.map(t=>{const existing=Number.isFinite(t.x)&&Number.isFinite(t.y),r=t.r??bodyRadius(seed,t.id),n=spawn; if(!existing)spawn++;return {...t,r,x:existing?t.x:65+hash(seed,t.id+3)*290,y:existing?t.y:-r-12-n*17,angle:t.angle??(hash(seed,t.id+9)-.5)*36,vx:0,vy:0,incoming:!existing};}).sort((a,b)=>a.id-b.id);
 const snapshot=()=>bodies.map(({id,x,y,angle})=>({id,x:quant(x),y:quant(y),angle:quant(angle)}));const frames=trace?[snapshot()]:[];let stable=0,steps=0;
 for(let step=0;step<FLOW.steps;step++){
  const old=bodies.map(b=>({x:b.x,y:b.y}));
  for(const b of bodies){b.vy+=FLOW.gravity*FLOW.dt;if(b.incoming)b.vy=Math.max(b.vy,210);b.x+=b.vx*FLOW.dt;b.y+=b.vy*FLOW.dt;}
  resolve(bodies,8);for(const b of bodies)if(b.y>=b.r)b.incoming=false;let maxMove=0;
  bodies.forEach((b,i)=>{const dx=b.x-old[i].x,dy=b.y-old[i].y;b.vx=dx/FLOW.dt*.96;b.vy=dy/FLOW.dt*.96;b.angle=Math.max(-44,Math.min(44,b.angle+dx/b.r*16));maxMove=Math.max(maxMove,Math.hypot(dx,dy));});
  if(trace&&step%6===5)frames.push(snapshot());steps=step+1;stable=maxMove<.035&&!bodies.some(b=>b.incoming)?stable+1:0;if(step>120&&stable>=18)break;
 }
 // Close the bounded inlet after the fixed simulation budget; projection resolves packing pressure.
 for(const b of bodies)b.incoming=false;
 resolve(bodies,4000,.02);const byID=new Map(bodies.map(({vx,vy,incoming,...b})=>[b.id,{...b,x:quant(b.x),y:quant(b.y),r:quant(b.r),angle:quant(b.angle)}]));const board=tiles.map(t=>byID.get(t.id));if(trace)frames.push(snapshot());return {board,frames,steps};
}
export function seedBodies(tiles,seed){return settleBodies(tiles,seed).board;}
export function spatialFocus(board,index,key){const d={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]}[key];if(!d)return index;const a=board[index];let best=index,score=Infinity;board.forEach((b,i)=>{const dx=b.x-a.x,dy=b.y-a.y,forward=dx*d[0]+dy*d[1];if(forward<=1)return;const cross=Math.abs(dx*d[1]-dy*d[0]),cost=Math.hypot(dx,dy)+cross*1.8;if(cost<score){score=cost;best=i;}});return best;}
