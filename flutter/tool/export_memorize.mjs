// Original-source oracle; synthetic input, no personal storage or network.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
process.on('uncaughtException',e=>{console.error(e.name+': '+e.message);process.exit(1);});
const root=path.resolve(import.meta.dirname,'../..');const ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['memorize.ts','classic.ts','raven.ts','typing.ts','keyboard.ts','stats-store.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
globalThis.localStorage={getItem:()=>null,setItem(){}};globalThis.window={setTimeout:()=>1};Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:'Win32',userAgent:'fixture'}});
const pre=`let currentLanguage='en';const lang=()=>currentLanguage;const render=()=>{};`;
const strip=s=>s.replace(/^import .*;$/gm,'');
const mz=strip(sources['memorize.ts'].slice(0,sources['memorize.ts'].indexOf('// ── Рендер')));
const tail=`export function init(source,language,length){currentLanguage=language;src=source;lenIdx=length;lenUp=false;startPiece(source,0);}
export function pieceList(){return pieces();}
export function press(ch){memorizeHandleKey({key:ch,preventDefault(){}});}
export function next(){nextLevel();}
export function snapshot(){return {pattern:st.pattern,pos:st.pos,errors:st.errors,wordOf,firstLetter,isAlpha,level,lenIdx,passWpm:[...passWpm],screen,recall:accNow(),lenUp,display:[...st.pattern].map((c,i)=>i<st.pos||!isAlpha[i]||showLetter(LEVELS[level],wordOf[i],firstLetter[i])?c:'·').join('')};}`;
const joined=pre+'\n'+['typing.ts','keyboard.ts','classic.ts','raven.ts','stats-store.ts'].map(n=>strip(sources[n])).join('\n')+'\n'+mz+'\n'+tail;
const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const cases=[];let at=100000;const oldNow=Date.now;Date.now=()=>at;
for(const language of ['ru','en','es','de','fr','it','pt'])for(const source of ['raven','classic'])for(const length of [0,1,2,3])for(const errors of [false,true]){
 at=100000;m.init(source,language,length);const pieces=m.pieceList(),passes=[];
 for(let pass=0;pass<5;pass++){
  const before=m.snapshot(),pattern=before.pattern;const mid=[];
  for(let i=0;i<pattern.length;i++){
   m.press('Backspace');
   if(errors&&i%2===0){at+=90;m.press('§');}
   at+=150;m.press(pattern[i]);
   if(i===Math.floor(pattern.length/2))mid.push(m.snapshot());
  }
  passes.push({before,mid,after:m.snapshot()});if(pass<4)m.next();
 }
 cases.push({language,source,length,errors,pieces,passes});
}
Date.now=oldNow;
await fs.writeFile(path.join(root,'flutter/test/fixtures/memorize.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),cases}));
console.log(cases.length+' source scenarios / '+cases.length*5+' passes');
