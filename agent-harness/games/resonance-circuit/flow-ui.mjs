import {FLOW,flowHit} from './flow.mjs';
import {playbackFrames} from './flow-motion.mjs';
// Playback only. Authoritative settled coordinates already exist before any animation begins.
export function createFlowUI(getState,reduced){
 const board=document.getElementById('board');let active=[],lastState=null;
 const elements=()=>[...board.querySelectorAll('.tile')];
 function geometry(){const rect=board.getBoundingClientRect(),scale=Math.min(rect.width/FLOW.width,rect.height/FLOW.height);return {rect,scale,ox:(rect.width-FLOW.width*scale)/2,oy:rect.height-FLOW.height*scale};}
 function position(t,i,g){if(lastState?.boardVersion===1)return {x:g.ox+t.x*g.scale,y:g.oy+t.y*g.scale,r:t.r*g.scale,angle:t.angle};const c=Math.floor(i/7),row=i%7,dx=g.rect.width/6.5,dy=g.rect.height/7.6;return {x:(c+.75)*dx,y:(row+.55+(c%2)*.5)*dy,r:Math.min(dx,dy)*.46,angle:0};}
 function render(){lastState=getState();const g=geometry();document.documentElement.dataset.board=lastState.boardVersion===1?'flow':'legacy';board.setAttribute('aria-label',lastState.boardVersion===1?'자유낙하 빛 기물. 공간 방향키 이동, Enter 또는 Space 확정':'기존 저장의 6열 7행 회로. 방향키 이동, Enter 또는 Space 확정');elements().forEach((el,i)=>{const p=position(lastState.board[i],i,g);Object.assign(el.style,{left:p.x-p.r+'px',top:p.y-p.r+'px',width:p.r*2+'px',height:p.r*2+'px',rotate:'0deg'});el.style.setProperty('--piece-size',p.r*2+'px');el.style.setProperty('--piece-angle',p.angle+'deg');el.dataset.tileId=lastState.board[i].id;});}
 function finish(){for(const a of active)a.cancel();active=[];board.dataset.falling='false';render();}
 async function play(flow){
  if(!flow||reduced.matches||document.hidden){render();return;}
  const g=geometry(),playback=playbackFrames(flow),tracks=new Map(playback.tracks.map(t=>[t.id,t.frames]));
  board.dataset.falling='true';board.dataset.flowDuration=String(playback.duration);
  active=elements().flatMap((el,i)=>{
   const final=lastState.board[i],frames=tracks.get(final.id);
   return [el.animate(frames.map(p=>({offset:p.offset,transform:`translate3d(${(p.x-final.x)*g.scale}px,${(p.y-final.y)*g.scale}px,0)`})),{duration:playback.duration,easing:'linear'}),
    el.querySelector('.gem').animate(frames.map(p=>({offset:p.offset,transform:`translate(-50%,-50%) rotate(${p.angle}deg)`})),{duration:playback.duration,easing:'linear'})];
  });
  await Promise.all(active.map(a=>a.finished.catch(()=>{})));finish();
 }
 function hit(x,y){const s=getState();if(s.boardVersion!==1)return null;const g=geometry();return flowHit(s.board,(x-g.rect.x-g.ox)/g.scale,(y-g.rect.y-g.oy)/g.scale);}
 window.addEventListener('resize',()=>finish());return {render,play,finish,hit};
}
