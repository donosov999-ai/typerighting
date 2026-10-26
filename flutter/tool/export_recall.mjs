// Run the unchanged source engine with a synthetic clock, RNG and timer handles.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
process.on('uncaughtException',e=>{console.error(e.name+': '+e.message);process.exit(1);});
const root=path.resolve(import.meta.dirname,'../..'),ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['recall.ts','typing.ts','keyboard.ts','stats-store.ts','corpus.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
globalThis.localStorage={getItem:()=>null,setItem(){}};let nextHandle=0;globalThis.window={setTimeout:()=>++nextHandle};globalThis.clearTimeout=()=>{};Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:'Win32',userAgent:'fixture'}});
const strip=s=>s.replace(/^import .*;$/gm,'');
let recall=strip(sources['recall.ts'].slice(0,sources['recall.ts'].indexOf('// ── Рендер')));
// Observe the existing local WPM calculation without changing its expression.
recall=recall.replace('pushHistory(wpm, lastRecall, Date.now());','lastComputedWpm=wpm; pushHistory(wpm, lastRecall, Date.now());');
const prefix=`let currentLanguage='en',lastComputedWpm=0;const lang=()=>currentLanguage;const render=()=>{};const sfx={start(){},fanfare(){},star(){}};`;
const tail=`export function init(language,initialSpan,initialBest){currentLanguage=language;span=initialSpan;bestSpan=initialBest;startRound();}
export function pool(){return wordPool(currentLanguage);}
export function hide(){toType();}
export function next(){startRound();}
export function press(ch){recallHandleKey({key:ch,preventDefault(){}});}
export function snapshot(){return {pattern:st.pattern,pos:st.pos,errors:st.errors,revealing:revealMode,span,bestSpan,display:[...st.pattern].map((c,i)=>revealMode||i<st.pos||c===' '?c:'·').join(''),result:screen==='result'?{wpm:lastComputedWpm,recall:lastRecall,span,bestSpan,lastUp,stars:lastRecall===100?3:lastRecall>=90?2:lastRecall>=70?1:0}:null};}`;
const joined=prefix+'\n'+['typing.ts','keyboard.ts','stats-store.ts','corpus.ts'].map(n=>strip(sources[n])).join('\n')+'\n'+recall+'\n'+tail;
const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
let seed=1943,at=100000;const oldRandom=Math.random,oldNow=Date.now;
Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};Date.now=()=>at;
const cases=[];
for(const language of ['ru','en','es','de','fr','it','pt'])for(let span=3;span<=9;span++)for(const errors of [false,true]){
 seed=1943;at=100000;m.init(language,span,span);const rounds=[];
 for(let round=0;round<3;round++){
  const before=m.snapshot();m.press('§');m.hide();const hidden=m.snapshot(),pattern=hidden.pattern;
  let mid;
  for(let i=0;i<pattern.length;i++){
   m.press('Backspace');m.press('Enter');
   if(errors&&i%2===0){at+=90;m.press('§');}
   at+=150;m.press(pattern[i]);
   if(i===Math.floor(pattern.length/2))mid=m.snapshot();
  }
  rounds.push({before,hidden,mid,after:m.snapshot()});if(round<2)m.next();
 }
 cases.push({language,span,errors,pool:m.pool(),rounds});
}
Math.random=oldRandom;Date.now=oldNow;
await fs.writeFile(path.join(root,'flutter/test/fixtures/recall.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),cases}));
console.log(cases.length+' source scenarios / '+cases.length*3+' rounds');
