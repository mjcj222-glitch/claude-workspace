// Render-only monotone Hermite curves. Never writes physics frames or saved state.
const distance=(a,b)=>Math.max(...a.map((p,i)=>Math.hypot(p.x-b[i].x,p.y-b[i].y)));
export function monotoneCurve(times,values){
 const n=values.length,secants=values.slice(1).map((v,i)=>(v-values[i])/(times[i+1]-times[i]));
 const slopes=values.map((_,i)=>i===0?secants[0]:i===n-1?0:secants[i-1]*secants[i]<=0?0:2/(1/secants[i-1]+1/secants[i]));
 return t=>{
  if(t<=times[0])return values[0];if(t>=times[n-1])return values[n-1];
  let i=0;while(times[i+1]<t)i++;
  const h=times[i+1]-times[i],u=(t-times[i])/h,u2=u*u,u3=u2*u;
  return (2*u3-3*u2+1)*values[i]+(u3-2*u2+u)*h*slopes[i]+(-2*u3+3*u2)*values[i+1]+(u3-u2)*h*slopes[i+1];
 };
}
export function playbackFrames(flow){
 let frames=flow.frames;while(frames.length>3&&distance(frames.at(-2),frames.at(-1))<.03)frames=[...frames.slice(0,-2),frames.at(-1)];
 if(frames.length<2)return {duration:0,tracks:[]};
 const weights=frames.slice(1).map((f,i)=>Math.max(.5,Math.sqrt(distance(f,frames[i]))));
 // The authoritative solver's final projection gets its own visible settling interval.
 if(distance(frames.at(-2),frames.at(-1))>1)weights[weights.length-1]=Math.max(weights.at(-1),weights.slice(0,-1).reduce((a,b)=>a+b,0)*.18);
 const total=weights.reduce((a,b)=>a+b,0),times=[0];for(const w of weights)times.push(times.at(-1)+w/total);times[times.length-1]=1;
 const travel=Math.max(...frames[0].map((p,i)=>Math.abs(p.y-frames.at(-1)[i].y)));
 const duration=Math.min(720,Math.max(460,430+travel*.36)),samples=Math.ceil(duration/1000*60);
 const tracks=frames[0].map((p,i)=>{
  const curves=Object.fromEntries(['x','y','angle'].map(k=>[k,monotoneCurve(times,frames.map(f=>f[i][k]))]));
  return {id:p.id,frames:Array.from({length:samples+1},(_,j)=>{const offset=j/samples;return {offset,...Object.fromEntries(Object.entries(curves).map(([k,curve])=>[k,curve(offset)]))};})};
 });
 return {duration,tracks,projectionDistance:distance(frames.at(-2),frames.at(-1)),settlingMs:weights.at(-1)/total*duration};
}
