// Exact shipped scoring/input functions, synthetic clock/storage, no user data.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
process.on('uncaughtException',e=>{console.error(e.name+': '+e.message);process.exit(1);});
const root=path.resolve(import.meta.dirname,'../..'),ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['main.ts','classic.ts','typing.ts','keyboard.ts','stats-store.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
const main=sources['main.ts'],strip=s=>s.replace(/^import .*;$/gm,'');
const exam=main.slice(main.indexOf('interface Exam {'),main.indexOf('\nfunction exitExam()'));
const input=main.slice(main.indexOf("  if (exam && exam.phase !== 'run') return;"),main.indexOf('  if (st.startedAt === null && !statsTimer)'));
const tracking=main.slice(main.indexOf('function statTrack('),main.indexOf('\nfunction updateStatsOnly()'));
const prefix=`let currentLanguage='en';const lang=()=>currentLanguage;let st=createState(['']);const render=()=>{};const notifyBadges=()=>{};const updateExamHud=()=>{};const blockOnError=true;const layoutDet={feed(){}};const ruCtx=()=>currentLanguage==='ru';const beep=()=>{};`;
const tail=`export function init(language,duration){currentLanguage=language;startExam(duration,35,'Fixture');}
export function key(k){handle({key:k,code:'',preventDefault(){}});}
export function finish(){finishExam();}
export function snapshot(){return {metrics:examStats(),pattern:st.pattern,pos:st.pos,errors:st.errors,marks:[...st.marks],completed:exam.count,index:exam.pi,pool:exam.pool.map(e=>e.id)};}`;
const code=ts.transpileModule(prefix+'\n'+['typing.ts','keyboard.ts','classic.ts','stats-store.ts'].map(n=>strip(sources[n])).join('\n')+'\n'+exam+'\nfunction handle(e){'+input+'}\n'+tracking+'\n'+tail,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
globalThis.localStorage={getItem:()=>null,setItem(){}};globalThis.window={setInterval:()=>1,setTimeout:()=>1};globalThis.clearInterval=()=>{};Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:'Win32',userAgent:'fixture'}});
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
let at=100000,seed=1943;const oldNow=Date.now,oldRandom=Math.random;Date.now=()=>at;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const cases=[];
for(const language of ['ru','en','es','de','fr','it','pt'])for(const duration of [1,5,10])for(const mode of ['correct','errors','corrections','timeout']){
 at=100000;seed=1943;m.init(language,duration);const initial=m.snapshot(),events=[],checkpoints=[];
 function press(key){at+=100;m.key(key);events.push({key,at});if(events.length%20===0)checkpoints.push({after:events.length,snapshot:m.snapshot()});}
 for(let i=0;i<120;i++){
  const s=m.snapshot(),expected=s.pattern[s.pos];
  if(mode==='errors'&&i%4===0)press('§');
  else if(mode==='corrections'&&i%5===0){press('§');press('Backspace');press(expected);}
  else press(expected);
 }
 if(mode==='timeout')at=100000+duration*60000;
 const before=m.snapshot();m.finish();const final=m.snapshot();
 cases.push({language,duration,mode,initial,events,checkpoints,before,finishedAt:at,final});
}
for(const language of ['ru','en','es','de','fr','it','pt']){
 at=100000;seed=1943;m.init(language,10);const initial=m.snapshot(),events=[],checkpoints=[];const wanted=initial.pool.length+1;
 while(m.snapshot().completed<wanted){const s=m.snapshot();at+=5;m.key(s.pattern[s.pos]);events.push({key:s.pattern[s.pos],at});if(m.snapshot().completed!==s.completed)checkpoints.push({after:events.length,snapshot:m.snapshot()});}
 const before=m.snapshot();m.finish();cases.push({language,duration:10,mode:'rollover',initial,events,checkpoints,before,finishedAt:at,final:m.snapshot()});
}
Date.now=oldNow;Math.random=oldRandom;
await fs.writeFile(path.join(root,'flutter/test/fixtures/exam.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),cases}));
console.log(cases.length+' source exams / '+cases.reduce((n,c)=>n+c.events.length,0)+' input events');
