import {SKILLS,skillInfo} from './skills.mjs';
export function createSkillUI(getState){
 const byID=id=>document.getElementById(id);let timer;
 function render(){
  const s=getState();document.querySelectorAll('[data-skill]').forEach((b,k)=>{const info=skillInfo(s,k);b.title=info.text;b.setAttribute('aria-label',`${info.name}. ${info.text}`);});
  const badges=[];if(s.buffs.prism)badges.push(['prism','프리즘 +12/24','다음 공격색 탭에서 소비. 잔향 적중이면 +24, 아니면 +12.']);
  if(s.buffs.ignition)badges.push(['ignition','점화 ≤30','다음 실제 폭탄 해소 탭에 폭탄당10, 최대30.']);
  if(s.buffs.shield)badges.push(['shield','보호 18','다음 실제 반격 한 번을 최대18 흡수.']);
  if(s.rules?.echoWard&&s.status==='playing')badges.push(['ward',s.wardBroken?'장막 해제':'장막 20%',s.wardBroken?'이번 턴 방어 해제. 다음 턴에는 다시 형성.':'이번 턴 최종 피해20% 감소. 잔향이 적중하면 해제.']);
  byID('buffs').replaceChildren();for(const [kind,text,title] of badges){const span=document.createElement('span');span.className=`buff ${kind}`;span.textContent=text;span.title=title;byID('buffs').append(span);}
  if(badges.length)byID('echo').textContent=`◌ ${s.echo.length}개`;
 }
 function describe(){
  const s=getState();byID('skillDescriptions').replaceChildren();
  SKILLS.forEach((skill,k)=>{const info=skillInfo(s,k),article=document.createElement('article'),h=document.createElement('h3'),p=document.createElement('p');h.textContent=skill.name;p.textContent=info.text;article.append(h,p);byID('skillDescriptions').append(article);});
  byID('skillGuide').showModal();
 }
 function clear(){clearTimeout(timer);byID('skillCutin').hidden=true;}
 function show(k){clear();const node=byID('skillCutin');node.className=`skill-cutin cutin-${k}`;node.replaceChildren();const portrait=document.createElement('span'),text=document.createElement('strong');portrait.className=`portrait portrait-${k}`;portrait.setAttribute('aria-hidden','true');text.textContent=SKILLS[k].name+' · 준비';node.append(portrait,text);node.hidden=false;timer=setTimeout(clear,500);}
 return {render,describe,show,clear};
}
