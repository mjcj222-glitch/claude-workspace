import {createAudio,SOUND_EVENTS} from './audio.mjs';
const options={enabled:false,volume:.3},audio=createAudio(options),by=id=>document.getElementById(id);let id=0;
by('toggle').onclick=()=>{audio.enable(!options.enabled);by('toggle').textContent=options.enabled?'소리 끄기':'소리 켜기';};
by('volume').oninput=e=>audio.volume(Number(e.target.value)/100);
for(const [kind,label] of Object.entries(SOUND_EVENTS)){const b=document.createElement('button');b.textContent=label;b.onclick=()=>{if(!options.enabled){by('status').textContent='먼저 소리 켜기를 눌러 주세요.';return;}audio.unlock();audio.play(kind,{id:++id,chain:kind==='large'?12:3});by('status').textContent=audio.available?label:'이 브라우저에서 오디오를 시작할 수 없습니다.';};by('samples').append(b);}
document.addEventListener('visibilitychange',()=>{if(document.hidden)audio.hide();});
