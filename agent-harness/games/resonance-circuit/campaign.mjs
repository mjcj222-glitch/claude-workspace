import {C} from './config.mjs';
import {createGame,tap,useSkill,overcharge,group} from './engine.mjs';
export const STAGES=[
 {name:'새싹 회랑',lesson:'큰 연결 뒤 남은 잔향을 이어 보세요.',bossHP:620,attacks:[14,20],patterns:['덩굴 스침','잎새 파동']},
 {name:'수정 정원',lesson:'장막20% · 잔향 적중으로 이번 턴 방어를 해제하세요.',bossHP:1100,attacks:[20,30],patterns:['수정 파편','공명 파동']},
 {name:'온실의 여왕',lesson:'3턴마다 만개40 · 보호막과 회복을 준비하세요.',bossHP:1700,attacks:[18,26,40],patterns:['꽃잎','덩굴','만개 · 강공격']}
];
export const CHOICES=[
 [{id:'power',name:'빛의 렌즈',description:'공격 타일 1개당 피해 +1. 이후 모든 전투에 적용.'},{id:'vitality',name:'튼튼한 온실',description:'최대 체력 +50. 이후 전투도 늘어난 체력으로 시작.'}],
 [{id:'charge',name:'축전 수정',description:'차지의 추가 피해 +20. 일반 타일 피해는 그대로.'},{id:'healing',name:'재생의 잎',description:'회복 타일 1개당 회복 +3. 최대 체력 상한은 유지.'}]
];
export function rulesFor(stage,upgrades){return {...C,bossHP:STAGES[stage].bossHP,attacks:[...STAGES[stage].attacks],echoWard:stage===1,hp:C.hp+(upgrades.includes('vitality')?50:0),attack:C.attack+(upgrades.includes('power')?1:0),charge:C.charge+(upgrades.includes('charge')?20:0),heal:C.heal+(upgrades.includes('healing')?3:0)};}
export function createRun(seed=C.seed,learn=true){return {version:1,seed:seed>>>0,stage:0,phase:'battle',upgrades:[],history:[],retries:[0,0,0],entry:{hp:C.hp,gauge:0},tutorialIDs:[],tutorial:learn?'chain':'done',state:createGame(seed,rulesFor(0,[]))};}
export function nextAttack(run){const stage=STAGES[run.stage],i=(run.state.turn-1)%stage.attacks.length;return {name:stage.patterns[i],damage:stage.attacks[i],pattern:stage.attacks.join(' → ')};}
export function tutorialTargets(run){
 if(run.tutorial==='chain'){let best=[];for(let i=0;i<42;i++){const g=group(run.state,i);if(run.state.board[i].color!=='heal'&&g.length>best.length)best=g;}return best;}
 if(run.tutorial==='echo')return run.state.board.flatMap((t,i)=>run.tutorialIDs.includes(t.id)?[i]:[]);return [];
}
export function skipTutorial(run){run.tutorial='done';run.tutorialIDs=[];}
export function canRunTap(run,index){return run.phase==='battle'&&!!run.state.board[index];}
export function runTap(run,index){
 if(!canRunTap(run,index))return null;
 const result=tap(run.state,index);if(!result)return null;
 if(run.tutorial==='chain'&&run.state.echo.length){run.tutorial='echo';run.tutorialIDs=[...run.state.echo];}else if(run.tutorial==='echo'){run.tutorial='done';run.tutorialIDs=[];}
 if(run.state.status!=='playing'){
  skipTutorial(run);
  run.history.push({stage:run.stage,turns:run.state.turn,echoes:run.state.echoCount,maxChain:run.state.maxChain,result:run.state.status});
  run.phase=run.state.status==='lost'?'defeat':run.stage===2?'complete':'upgrade';
 }
 return result;
}
export function runSkill(run,index){return run.phase==='battle'&&useSkill(run.state,index);}
export function runBoost(run){return run.phase==='battle'&&overcharge(run.state);}
export function chooseUpgrade(run,id){
 if(run.phase!=='upgrade'||!CHOICES[run.stage]?.some(c=>c.id===id))return false;
 run.upgrades.push(id);run.stage++;run.phase='battle';run.tutorial='done';
 const rules=rulesFor(run.stage,run.upgrades);run.entry={hp:Math.min(rules.hp,run.state.hp+45),gauge:run.state.gauge};
 run.state=createGame((run.seed+run.stage*7919)>>>0,rules);Object.assign(run.state,run.entry);return true;
}

export function retryBattle(run){
 if(run.phase!=='defeat')return false;
 run.retries[run.stage]++;run.history=run.history.slice(0,run.stage);run.phase='battle';run.tutorial='done';run.tutorialIDs=[];
 run.state=createGame((run.seed+run.stage*7919)>>>0,rulesFor(run.stage,run.upgrades));Object.assign(run.state,run.entry);return true;
}
