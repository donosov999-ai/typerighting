// Execute unchanged shipped competition engine with synthetic clock/RNG/storage.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
process.on('uncaughtException', e => {console.error(e.name+': '+e.message);process.exit(1);});
const root=path.resolve(import.meta.dirname,'../..');
const ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['compete.ts','typing.ts','keyboard.ts','stats-store.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
const compete=sources['compete.ts'].slice(0,sources['compete.ts'].indexOf('\nasync function openBoard()')).replace(/^import .*;$/gm,'');
const pre=`let currentLanguage='en';const lang=()=>currentLanguage;const STORE_APP=true;const render=()=>{};const leagueSubmit=()=>{};const getReplay=async()=>null;globalThis.cancelAnimationFrame=()=>{};`;
const tail=`export function init(d,l,b){currentLanguage=l;best={};best[d+'_'+curLang()]=b;startDisc(d);}
export function press(ch){competeHandleKey({key:ch,preventDefault(){}});}
export function snapshot(){return {pattern:st.pattern,pos:st.pos,errors:st.errors,marks:[...st.marks],result:lastResult,timeline:[...timeline]};}
export function pattern(d,l){return content(d,l==='ru'?'ru':'en');}
export function resetResult(){lastResult=null;}`;
const joined=pre+'\n'+sources['typing.ts']+'\n'+sources['keyboard.ts']+'\n'+sources['stats-store.ts'].replace(/^import .*;$/gm,'')+'\n'+compete+'\n'+tail;
const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
globalThis.localStorage={getItem:()=>null,setItem(){}};
globalThis.window={setTimeout:()=>1};
Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:'Win32',userAgent:'fixture'}});
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const cases=[],generation=[];let seed=0,at=100000;
const oldNow=Date.now,oldRandom=Math.random;
Date.now=()=>at;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
for(const language of ['ru','en','es','de','fr','it','pt'])for(const discipline of ['alpha_fwd','alpha_rev','words','digits','sprint']){
 seed=1943;generation.push({language,discipline,pattern:m.pattern(discipline,language)});
 for(const [speed,errorEvery,previousBest,start] of [[150,0,0,100000],[350,3,1000,100000],[50,0,10,0]]){
  seed=1943;at=start;m.resetResult();m.init(discipline,language,previousBest);const initial=m.snapshot(),steps=[];
  for(let i=0;i<initial.pattern.length;i++){
   at+=10;m.press('Backspace');
   if(errorEvery&&i%errorEvery===0){at+=speed;m.press('§');steps.push({ch:'§',at});}
   at+=speed;m.press(initial.pattern[i]);steps.push({ch:initial.pattern[i],at});
  }
  cases.push({language,discipline,previousBest,initial,steps,expected:m.snapshot()});
 }
}
Date.now=oldNow;Math.random=oldRandom;
await fs.writeFile(path.join(root,'flutter/test/fixtures/competition.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),generation,cases}));
console.log(cases.length+' source races / '+cases.reduce((n,c)=>n+c.steps.length,0)+' strokes / '+generation.length+' seeded content probes');
