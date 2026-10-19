import {C} from './config.mjs';
export const SKILLS=[
 {name:'프리즘 링크',color:'coral',description:'파랑 전부를 불꽃으로. 다음 공격색 탭 1회 +12 피해, 잔향 적중이면 +24. 회복색 탭에는 유지.'},
 {name:'연쇄 점화',color:'blue',description:'일반 공격 타일 최대2개를 폭탄으로. 다음 실제 폭탄 해소 탭에 폭탄당 +10 피해, 최대+30. 폭탄 없는 탭에는 유지.'},
 {name:'생명의 온실',color:'heal',description:'일반 공격 타일 최대6개를 회복으로. 다음 실제 적 반격 1회를 최대18 흡수. 승리 시 흡수 없이 종료.'}
];
export function freshBuffs(){return {prism:false,ignition:false,shield:0};}
export function skillCandidates(s,k){
 if(!Number.isInteger(k)||k<0||k>2)return [];
 const found=s.board.filter(t=>k===0?t.color==='blue':t.kind==='normal'&&t.color!=='heal');
 return k===0?found:found.slice(0,k===1?2:6);
}
export function skillInfo(s,k){
 const skill=SKILLS[k],count=skillCandidates(s,k).length,remaining=Math.max(0,s.ready[k]-s.turn);
 return {...skill,count,remaining,usable:s.status==='playing'&&remaining===0&&count>0,
 text:`${skill.description} 현재 대상 ${count}개. 쿨다운 ${C.cooldown}턴${remaining?` (남음 ${remaining}턴)`:''}. 대상0이면 사용 실패·쿨다운/버프 변화 없음. 재사용은 갱신, 중첩 없음. 고정 보너스는 과충전 배율 제외.`};
}
