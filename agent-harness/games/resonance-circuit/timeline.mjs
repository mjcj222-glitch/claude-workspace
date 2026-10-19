import {neighbors} from './engine.mjs';
const center=i=>({x:Math.floor(i/7)*.866,y:i%7+(Math.floor(i/7)%2)*.5});
function around(origin,a,b){const o=center(origin),p=center(a),q=center(b);return Math.atan2(p.y-o.y,p.x-o.x)-Math.atan2(q.y-o.y,q.x-o.x)||a-b;}
export function planTimeline(s,index,p){
 if(!p.removed.length)return {events:[],audio:[],lastStart:0,settleAt:0,total:0,echoOrigin:index};
 const initial=new Set(p.initial),removed=new Set(p.removed),times=new Map(),distance=new Map([[index,0]]),queue=[index];
 for(const i of queue)for(const n of neighbors(i).sort((a,b)=>around(i,a,b)))if(initial.has(n)&&!distance.has(n)){distance.set(n,distance.get(i)+1);queue.push(n);}
 queue.forEach((i,n)=>times.set(i,n*28));
 const marked=p.initial.filter(i=>s.echo.includes(s.board[i].id)).sort((a,b)=>times.get(a)-times.get(b)),echoOrigin=marked[0]??index;
 if(p.echoHit){const targets=p.removed.filter(i=>s.echo.includes(s.board[i].id)).sort((a,b)=>around(echoOrigin,a,b));targets.forEach((i,n)=>times.set(i,Math.min(times.get(i)??Infinity,times.get(echoOrigin)+52+n*18)));}
 // Relax blast edges over the already resolved removal set; never recalculate gameplay.
 for(let pass=0;pass<p.removed.length;pass++){let changed=false;for(const [i,t] of [...times].sort((a,b)=>a[1]-b[1]))if(s.board[i].kind==='bomb')for(const n of neighbors(i))if(removed.has(n)&&t+38<(times.get(n)??Infinity)){times.set(n,t+38);changed=true;}if(!changed)break;}
 const events=[...removed].map(i=>({index:i,id:s.board[i].id,type:'clear',at:times.get(i)??0,distance:distance.get(i)??Infinity,bomb:s.board[i].kind==='bomb',echo:p.echoHit&&s.echo.includes(s.board[i].id),rainbow:initial.has(i)&&s.board[i].kind==='rainbow'}));
 for(const i of p.unlocked){const adjacent=neighbors(i).filter(n=>removed.has(n));events.push({index:i,id:s.board[i].id,type:'vine',at:Math.min(...adjacent.map(n=>times.get(n)))+24});}
 const rawMax=Math.max(...events.map(e=>e.at)),scale=rawMax>420?420/rawMax:1;for(const e of events)e.at=Math.round(e.at*scale);
 events.sort((a,b)=>a.at-b.at||around(index,a.index,b.index));
 const audio=[];for(const e of events)if(e.type==='clear'&&audio.length<9&&(!audio.length||e.at-audio.at(-1).at>=48))audio.push({id:e.id,at:e.at,note:audio.length});
 const lastStart=Math.max(...events.map(e=>e.at)),settleAt=lastStart+150+28;
 return {events,audio,lastStart,settleAt,total:settleAt+140,echoOrigin};
}
export function runTimeline(plan,callback,reduced=false,shouldFinish=()=>false){
 const timers=new Set();let resolve,finished=false;const done=new Promise(r=>resolve=r);
 function finish(reason){if(finished)return;finished=true;for(const timer of timers)clearTimeout(timer);timers.clear();resolve(reason);}
 if(reduced){for(const event of plan.events)callback(event);queueMicrotask(()=>finish('done'));}
 else{let remaining=plan.events.length;const hold=plan.settleAt-Math.max(0,...plan.events.map(e=>e.at));if(!remaining)queueMicrotask(()=>finish('done'));for(const event of plan.events)timers.add(setTimeout(()=>{if(finished)return;if(shouldFinish()){finish('finish');return;}callback(event);remaining--;if(!remaining)timers.add(setTimeout(()=>finish(shouldFinish()?'finish':'done'),hold));},event.at));}
 return {done,cancel:finish};
}

export function fallOffset(previous,current,scroll){return previous?previous.y-scroll-current.y:-28;}
