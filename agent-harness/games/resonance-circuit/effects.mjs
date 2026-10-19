// Screen-space accents, bounded independently from the board and its RNG.
export function createEffects(canvas,reduced){
 const ctx=canvas.getContext('2d');let particles=[],frame=0,last=0,peak=0;const marks=new Map(),labels=new Map();
 const point=el=>{const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};};
 function size(){const d=Math.min(devicePixelRatio||1,2);canvas.width=innerWidth*d;canvas.height=innerHeight*d;ctx?.setTransform(d,0,0,d,0,0);}
 function clearScreen(){cancelAnimationFrame(frame);frame=0;particles=[];ctx?.clearRect(0,0,innerWidth,innerHeight);canvas.dataset.active='0';for(const [el,t] of labels){clearTimeout(t);el.remove();}labels.clear();}
 window.addEventListener('scroll',clearScreen,{passive:true});
 size();window.addEventListener('resize',()=>{clearScreen();size();});
 function cue(kind,el,color='#c7f5e5'){if(document.hidden)return;clearTimeout(marks.get(el));el.dataset.fx=kind;el.style.setProperty('--fx-color',color);marks.set(el,setTimeout(()=>{delete el.dataset.fx;marks.delete(el);},160));}
 function draw(time){const dt=Math.min((time-last)/1000,.05);last=time;ctx.clearRect(0,0,innerWidth,innerHeight);particles=particles.filter(p=>{
  p.life-=dt;if(p.life<=0)return false;const a=p.life/p.total,u=1-a;ctx.globalAlpha=Math.min(1,a*2);ctx.strokeStyle=p.color;ctx.fillStyle=p.color;ctx.lineWidth=1.5;
  if(p.type==='ring'){ctx.beginPath();ctx.arc(p.x,p.y,8+u*(p.radius??42),0,Math.PI*2);ctx.stroke();}
  else if(p.type==='line'){ctx.lineWidth=1+2*a;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.quadraticCurveTo((p.x+p.tx)/2,(p.y+p.ty)/2-22,p.tx,p.ty);ctx.stroke();}
  else if(p.type==='absorb'){const v=u*u;ctx.beginPath();ctx.arc(p.x+(p.tx-p.x)*v,p.y+(p.ty-p.y)*v-16*Math.sin(u*Math.PI),2.5*a+.5,0,Math.PI*2);ctx.fill();}
  else{p.x+=p.vx*dt;p.y+=p.vy*dt;ctx.save();ctx.translate(p.x,p.y);ctx.rotate(u*2+p.angle);ctx.beginPath();if(p.type==='leaf')ctx.ellipse(0,0,5*a+1,2.5*a+1,0,0,Math.PI*2);else{ctx.moveTo(0,-3);ctx.lineTo(2.5,2);ctx.lineTo(-2.5,2);ctx.closePath();}ctx.fill();ctx.restore();}return true;
 });ctx.globalAlpha=1;canvas.dataset.active=String(particles.length);if(particles.length)frame=requestAnimationFrame(draw);else{frame=0;ctx.clearRect(0,0,innerWidth,innerHeight);}}
 function add(p){if(reduced.matches||document.hidden||!ctx)return;particles.push({...p,life:p.life??.28,total:p.life??.28});if(particles.length>80)particles.splice(0,particles.length-80);peak=Math.max(peak,particles.length);canvas.dataset.active=String(particles.length);if(!frame){last=performance.now();frame=requestAnimationFrame(draw);}}
 function burst(el,color='#b4f7dc',large=false){cue(large?'large':'chain',el,color);const p=point(el);for(let j=0;j<(large?5:3);j++){const a=j*Math.PI*.8;add({...p,vx:Math.cos(a)*(large?60:36),vy:Math.sin(a)*36,type:'shard',angle:a,color,life:large?.3:.22});}}
 function ring(el,color='#ffe5a5',kind='bomb'){cue(kind,el,color);add({...point(el),type:'ring',color,life:.28,radius:kind==='shield'?22:42});}
 function link(a,b,color='#a2ffdb'){cue('echo',b,color);add({...point(a),tx:point(b).x,ty:point(b).y,type:'line',color,life:.28});}
 function absorb(a,b,color='#ffe8a5'){add({...point(a),tx:point(b).x,ty:point(b).y,type:'absorb',color,life:.24});}
 function release(el){cue('vine',el,'#c2ec95');for(let j=0;j<3;j++)add({...point(el),type:'leaf',vx:(j-1)*42,vy:-25-j*9,angle:j,color:'#b9e589',life:.32});}
 function converge(el,color){cue('rainbow',el,color);const p=point(el);for(let j=0;j<4;j++){const a=j*Math.PI/2;add({x:p.x+Math.cos(a)*23,y:p.y+Math.sin(a)*23,tx:p.x,ty:p.y,type:'absorb',color,life:.23});}}
 function label(el,text,kind=''){if(document.hidden)return;if(reduced.matches){cue(kind||'hit',el);return;}if(labels.size>=3)return;const node=document.createElement('span'),p=point(el);node.className='fx-label '+kind;node.textContent=text;node.style.left=Math.max(65,Math.min(innerWidth-65,p.x))+'px';node.style.top=p.y+'px';node.setAttribute('aria-hidden','true');document.body.append(node);labels.set(node,setTimeout(()=>{node.remove();labels.delete(node);},380));}
 function clear(){cancelAnimationFrame(frame);frame=0;particles=[];ctx?.clearRect(0,0,innerWidth,innerHeight);canvas.dataset.active='0';for(const [el,t] of marks){clearTimeout(t);delete el.dataset.fx;}marks.clear();for(const [el,t] of labels){clearTimeout(t);el.remove();}labels.clear();document.querySelectorAll('.hit,.hurt,.guarded,.skill-used,.cleared').forEach(el=>el.classList.remove('hit','hurt','guarded','skill-used','cleared'));document.querySelectorAll('.tile,.concept-boss,.skill-cutin').forEach(el=>el.getAnimations().forEach(a=>a.cancel()));}
 return {burst,ring,link,absorb,release,converge,cue,label,clear,point,get stats(){return {particles:particles.length,peakParticles:peak,marks:marks.size,labels:labels.size};}};
}
