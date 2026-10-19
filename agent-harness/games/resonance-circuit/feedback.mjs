// Event routing describes the resolved action; it never changes game state.
export function preFeedback(p){
 const events=[];if(p.bombs)events.push('bomb');if(p.echoHit)events.push('echo');if(p.unlocked.length)events.push('vine');if(p.rainbows)events.push('rainbow');
 if(!events.length)events.push(p.initial.length>=10?'large':'chain');return events;
}
export function postFeedback(result,{bossHit=false,healed=0,status='playing'}={}){
 const events=[];if(healed>0)events.push('heal');if(bossHit)events.push('hit');if(result.blocked)events.push('shield');if(result.retaliation)events.push('enemy');if(status!=='playing')events.push(status==='won'?'win':'lose');return events;
}
