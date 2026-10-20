import {neighbors} from './engine.mjs';
import {currentRoom} from './expedition.mjs';
export const ENCOUNTERS={normal:{name:'등불나방 요정',label:'회랑의 작은 수호자'},elite:{name:'정예 · 가면여우 수호자',label:'단단한 장막'},midboss:{name:'중간보스 · 황동 사슴',label:'네 번째 문을 지키는 자'},boss:{name:'최종보스 · 일식 화룡',label:'마지막 빛의 수호자'},rest:{name:'달빛 쉼터',label:'체력36 회복'},event:{name:'여우의 작은 교역소',label:'유물을 얻거나 따뜻한 차를 마셔요'}};
export function encounterKind(node){if(!node)return 'normal';return node.depth===3&&['normal','elite'].includes(node.type)?'midboss':node.type;}
export function encounterFor(run){return run.mode==='expedition'?encounterKind(currentRoom(run)):['normal','midboss','boss'][run.stage]??'normal';}

export function selectionEdges(indices){if(!indices.length)return [];const selected=new Set(indices),seen=new Set([indices[0]]),queue=[indices[0]],edges=[];for(const i of queue)for(const j of neighbors(i))if(selected.has(j)&&!seen.has(j)){seen.add(j);queue.push(j);edges.push([i,j]);}return edges;}
