// Visual-only effects. No game RNG, timers or objects enter the rules engine.
export function createEffects(canvas, reduced) {
 const ctx=canvas.getContext('2d');let particles=[],frame=0,last=0;const labels=new Set();
 const point=el=>{const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};};
 function size(){const d=Math.min(devicePixelRatio||1,2);canvas.width=innerWidth*d;canvas.height=innerHeight*d;ctx.setTransform(d,0,0,d,0,0);}
 size();window.addEventListener('resize',size);
 function draw(time){const dt=Math.min((time-last)/1000,.04);last=time;ctx.clearRect(0,0,innerWidth,innerHeight);particles=particles.filter(p=>{p.life-=dt;if(p.life<=0)return false;const a=p.life/p.total;ctx.globalAlpha=a;ctx.strokeStyle=p.color;ctx.fillStyle=p.color;
 if(p.type==='ring'){ctx.lineWidth=2;ctx.beginPath();ctx.arc(p.x,p.y,8+(1-a)*65,0,Math.PI*2);ctx.stroke();}
 else if(p.type==='line'){ctx.lineWidth=1+2*a;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(p.tx,p.ty);ctx.stroke();}
 else{p.x+=p.vx*dt;p.y+=p.vy*dt;p.vy+=30*dt;ctx.fillRect(p.x,p.y,2+2*a,2+2*a);}return true;});ctx.globalAlpha=1;
 if(particles.length)frame=requestAnimationFrame(draw);else{frame=0;ctx.clearRect(0,0,innerWidth,innerHeight);}canvas.dataset.active=particles.length;
 }
 function add(p){if(reduced.matches)return;particles.push({...p,life:p.life??.55,total:p.life??.55});if(particles.length>100)particles.splice(0,particles.length-100);if(!frame){last=performance.now();frame=requestAnimationFrame(draw);}}
 function burst(el,color='#b4f7dc'){const p=point(el);for(let j=0;j<6;j++){const a=j*Math.PI/3;add({...p,vx:Math.cos(a)*65,vy:Math.sin(a)*65,type:'spark',color});}}
 function ring(el){add({...point(el),type:'ring',color:'#ffe5a5',life:.65});}
 function link(a,b,color='#a2ffdb'){add({...point(a),tx:point(b).x,ty:point(b).y,type:'line',color,life:.4});}
 function label(el,text,kind=''){const node=document.createElement('span'),p=point(el);node.className='fx-label '+kind;node.textContent=text;node.style.left=Math.max(90,Math.min(innerWidth-90,p.x))+'px';node.style.top=p.y+'px';node.setAttribute('aria-hidden','true');document.body.append(node);labels.add(node);setTimeout(()=>{node.remove();labels.delete(node);},reduced.matches?350:750);}
 function clear(){cancelAnimationFrame(frame);frame=0;particles=[];ctx.clearRect(0,0,innerWidth,innerHeight);canvas.dataset.active='0';for(const n of labels)n.remove();labels.clear();}
 return {burst,ring,link,label,clear,point};
}
