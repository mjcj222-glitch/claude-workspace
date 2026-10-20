import {ENCOUNTERS,encounterFor,selectionEdges} from './encounters.mjs';
export function createEncounterUI(reduced){
 const $=id=>document.getElementById(id),title=document.createElement('span');title.id='encounterEntrance';title.setAttribute('aria-hidden','true');$('enemy').prepend(title);
 const graph=document.createElementNS('http://www.w3.org/2000/svg','svg');graph.id='selectionLinks';graph.setAttribute('aria-hidden','true');$('board').prepend(graph);
 let identity=null,timer=null,selection=[],boardState=null;
 function select(indices){selection=[...indices];graph.replaceChildren();const board=$('board').getBoundingClientRect(),tiles=[...document.querySelectorAll('.tile')];graph.setAttribute('viewBox',`0 0 ${board.width} ${board.height}`);for(const [i,j] of selectionEdges(indices,boardState)){const a=tiles[i]?.getBoundingClientRect(),b=tiles[j]?.getBoundingClientRect();if(!a||!b)continue;const line=document.createElementNS('http://www.w3.org/2000/svg','line');for(const [key,value] of Object.entries({x1:a.x+a.width/2-board.x,y1:a.y+a.height/2-board.y,x2:b.x+b.width/2-board.x,y2:b.y+b.height/2-board.y}))line.setAttribute(key,String(value));graph.append(line);}}
 function clear(){select([]);clearTimeout(timer);timer=null;title.classList.remove('visible');title.textContent='';}
 function render(run){boardState=run.state;const kind=encounterFor(run),info=ENCOUNTERS[kind]??ENCOUNTERS.normal;$('enemy').dataset.encounter=kind;document.documentElement.dataset.encounter=kind;
  if(run.phase==='battle'&&identity!==run.state){clear();identity=run.state;if(['midboss','boss'].includes(kind)&&!reduced.matches&&!document.hidden){title.textContent=info.name;title.classList.add('visible');timer=setTimeout(clear,650);}}
  if(run.phase!=='battle')clear();
  const scene=$('roomScene');scene.hidden=run.mode!=='expedition'||run.phase!=='room';scene.dataset.encounter=kind;scene.setAttribute('aria-label',info.name+' · '+info.label);$('roomSceneCaption').textContent=info.label;
 }
 document.addEventListener('visibilitychange',()=>{if(document.hidden)clear();});
 window.addEventListener('resize',()=>select(selection));return {render,clear,select};
}
