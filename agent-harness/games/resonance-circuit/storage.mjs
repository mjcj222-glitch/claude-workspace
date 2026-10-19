import {panelSeed} from './panels.mjs';
import {C,COLORS} from './config.mjs';
import {freshBuffs} from './skills.mjs';
import {createRun,rulesFor,CHOICES} from './campaign.mjs';
export const SAVE_KEY='resonance-circuit-v1';
const integer=(n,a,b)=>Number.isInteger(n)&&n>=a&&n<=b;
export function decodeSave(raw){
 try{
 const data=JSON.parse(raw);if(data?.version!==1||typeof data.learned!=='boolean'||typeof data.audio?.enabled!=='boolean'||!Number.isFinite(data.audio.volume)||data.audio.volume<0||data.audio.volume>1)return null;
 let run=null;
 if(data.run!==null){
 const r=data.run,s=r?.state;
 if(!r||r.version!==1||!integer(r.seed,0,4294967295)||!integer(r.stage,0,2)||!['battle','upgrade','complete','defeat'].includes(r.phase)||!['chain','echo','done'].includes(r.tutorial))return null;
 if(!Array.isArray(r.upgrades)||r.upgrades.length!==r.stage||r.upgrades.some((id,i)=>!CHOICES[i]?.some(c=>c.id===id)))return null;
 const panelVersion=r.panelVersion??0,panelLesson=r.panelLesson??null,panelSeen=r.panelSeen??[false,false];
 if(![0,1].includes(panelVersion)||!Array.isArray(panelSeen)||panelSeen.length!==2||panelSeen.some(x=>typeof x!=='boolean')||![null,'vine','rainbow'].includes(panelLesson))return null;
 if(panelLesson&&(r.phase!=='battle'||!panelVersion||r.stage!==(panelLesson==='vine'?1:2)||panelSeen[r.stage-1]))return null;
 const rules={...rulesFor(r.stage,r.upgrades),panelStage:panelVersion?r.stage:0};
 if(!Array.isArray(r.retries)||r.retries.length!==3||r.retries.some(n=>!integer(n,0,10000))||!integer(r.entry?.hp,1,rules.hp)||!integer(r.entry?.gauge,0,C.gauge)||!Array.isArray(r.tutorialIDs)||r.tutorialIDs.length>8)return null;
 if(!s||!integer(s.seed,0,4294967295)||!integer(s.rng,0,4294967295)||!integer(s.nextID,43,1000000)||!integer(s.turn,1,10000)||!integer(s.taps,0,3)||!integer(s.hp,0,rules.hp)||!integer(s.bossHP,0,rules.bossHP)||!integer(s.gauge,0,C.gauge)||typeof s.boost!=='boolean'||!['playing','won','lost'].includes(s.status))return null;
 for(const key of ['damage','healing','maxChain','echoCount'])if(!integer(s[key],0,1000000))return null;
 if(!Array.isArray(s.board)||s.board.length!==42||s.board.some(t=>!integer(t.id,1,s.nextID-1)||!COLORS.includes(t.color)||!['normal','charge','bomb','rainbow'].includes(t.kind)||t.vine!==undefined&&typeof t.vine!=='boolean'||t.vine&&(t.kind!=='normal'||t.color==='heal')))return null;
 if(s.board.filter(t=>t.vine).length>4||s.board.filter(t=>t.kind==='rainbow').length>2||s.board.some(t=>(t.vine&&!rules.panelStage)||(t.kind==='rainbow'&&rules.panelStage!==2)))return null;
 if((panelVersion===1||s.panelRng!==undefined)&&!integer(s.panelRng,0,4294967295))return null;
 if(s.seed!==((r.seed+r.stage*7919)>>>0))return null;
 const ids=new Set(s.board.map(t=>t.id));if(r.tutorialIDs.some(id=>!ids.has(id)))return null;if(ids.size!==42||!Array.isArray(s.echo)||s.echo.length>8||new Set(s.echo).size!==s.echo.length||s.echo.some(id=>!ids.has(id)))return null;
 if(s.echo.some(id=>s.board.find(t=>t.id===id).color==='heal'||s.board.find(t=>t.id===id).vine||s.board.find(t=>t.id===id).kind==='rainbow'))return null;
 if(r.phase!=='battle'&&(s.taps!==0||s.status==='won'&&s.hp===0||s.status==='lost'&&s.bossHP===0))return null;
 if(!Array.isArray(s.ready)||s.ready.length!==3||s.ready.some(n=>!integer(n,1,s.turn+C.cooldown)))return null;
 if(r.phase==='battle'&&(s.status!=='playing'||s.taps<1||s.hp<1||s.bossHP<1))return null;
 if(r.phase==='upgrade'&&(s.status!=='won'||r.stage>=2||s.bossHP!==0)||r.phase==='complete'&&(s.status!=='won'||r.stage!==2||s.bossHP!==0)||r.phase==='defeat'&&(s.status!=='lost'||s.hp!==0))return null;
 if(r.tutorial!=='done'&&(r.stage!==0||r.phase!=='battle')||r.tutorial==='echo'&&!s.echo.length)return null;
 if(!Array.isArray(r.history)||r.history.length!==r.stage+(r.phase==='battle'?0:1)||r.history.some((h,i)=>h.stage!==i||!integer(h.turns,1,10000)||!integer(h.echoes,0,1000000)||!integer(h.maxChain,0,42)||!['won','lost'].includes(h.result)))return null;
 run=createRun(r.seed,false);Object.assign(run,{panelVersion,panelLesson,panelSeen:[...panelSeen],stage:r.stage,phase:r.phase,tutorial:r.tutorial,upgrades:[...r.upgrades],history:r.history.map(h=>({...h})),retries:[...r.retries],entry:{...r.entry},tutorialIDs:[...r.tutorialIDs]});
 const buffs=s.buffs===undefined?freshBuffs():s.buffs;
 if(!buffs||typeof buffs.prism!=='boolean'||typeof buffs.ignition!=='boolean'||![0,18].includes(buffs.shield)||s.wardBroken!==undefined&&typeof s.wardBroken!=='boolean')return null;
 if(r.phase!=='battle'&&(buffs.prism||buffs.ignition||buffs.shield))return null;
 run.state.buffs={prism:buffs.prism,ignition:buffs.ignition,shield:buffs.shield};run.state.wardBroken=s.wardBroken??(r.stage===1);
 const keys=['seed','rng','nextID','hp','bossHP','turn','taps','damage','healing','gauge','boost','status','maxChain','echoCount'];for(const k of keys)run.state[k]=s[k];
 run.state.panelRng=s.panelRng??panelSeed(s.seed);run.state.rules=rules;run.state.board=s.board.map(({id,color,kind,vine})=>({...{id,color,kind},...(vine===undefined?{}:{vine})}));run.state.echo=[...s.echo];run.state.ready=[...s.ready];
 }
 return {version:1,run,learned:data.learned,audio:{enabled:data.audio.enabled,volume:data.audio.volume}};
 }catch{return null;}
}
export function loadProgress(storage){try{const raw=storage.getItem(SAVE_KEY);if(!raw)return {data:null,reason:'empty'};const data=decodeSave(raw);const legacy=data&&data.run&&(JSON.parse(raw).run.state.buffs===undefined||JSON.parse(raw).run.panelVersion===undefined);return {data,reason:data?(legacy?'migrated':'ok'):'invalid'};}catch{return {data:null,reason:'unavailable'};}}
export function saveProgress(storage,run,learned,audio){try{const data={version:1,run,learned,audio};if(!decodeSave(JSON.stringify(data)))return false;storage.setItem(SAVE_KEY,JSON.stringify(data));return true;}catch{return false;}}
