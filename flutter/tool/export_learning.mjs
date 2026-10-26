process.on('uncaughtException',e=>{console.error(e.name+': '+e.message);process.exit(1);});
// Execute shipped learning + typing/statistics/ngram with seeded synthetic input.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
const root=path.resolve(import.meta.dirname,'../..'),base=path.join(root,'flutter');
const ts=createRequire('/Users/denisonosov/dev/typerighting-wt-release-20261024/package.json')('typescript');
const sources=Object.fromEntries(await Promise.all(['learn.ts','typing.ts','stats-store.ts','ngram.ts','keyboard.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
const allKeys=JSON.parse(await fs.readFile(path.join(base,'assets/baseline/keyboard.json'),'utf8'));
const corpus=JSON.parse(await fs.readFile(path.join(base,'assets/baseline/catalog.json'),'utf8')).corpus;
const chars=new Set([...Object.values(corpus).join(''),...'éüçßœæ ЙйЁёъЪàáâãäåèêëìíîïñòóôõöùúûýÿ']);
const normalization=Object.fromEntries([...chars].map(c=>[c,c.normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/ß/g,'ss').replace(/œ/g,'oe').replace(/æ/g,'ae')]).filter(([a,b])=>a!==b));
await fs.writeFile(path.join(base,'assets/baseline/learning.json'),JSON.stringify({normalization,sourceSha256:createHash('sha256').update(sources['learn.ts']).digest('hex')}));
const cases=[];let number=0;
for(const os of ['windows','mac'])for(const language of ['ru','en','es','de','fr','it','pt'])for(const profile of ['m','f','kids'])for(const hand of profile==='kids'?['both']:['both','left','right']){
 const layout=language==='fr'?'azerty':language==='de'?'qwertz':'qwerty',keyboard=allKeys[os][layout];
 const letters=Object.fromEntries(['en','ru'].map(l=>[l,keyboard.keys.filter(g=>/^[A-Za-zА-Яа-яЁё]$/.test(l==='en'?g.baseEn:g.ru)).map(g=>({id:g.id,ch:(l==='en'?g.baseEn:g.ru).toLowerCase()}))]));
 const initial={a:{ok:8,err:2},s:{ok:9,err:1},d:{ok:10,err:0},f:{ok:3,err:3}};
 const values=new Map([['tr_keystats',JSON.stringify(initial)],['tr_kids_ai_lvl','1']]);
 globalThis.localStorage={getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v)};globalThis.window={setTimeout:()=>1};
 Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:os==='mac'?'MacIntel':'Win32',userAgent:os}});
 const prefix=`const CORPUS=${JSON.stringify(corpus)};let currentLang='${language}';const lang=()=>currentLang;const sfx={upgrade(){}};const learnRender=()=>{};`;
 const learn=sources['learn.ts'].slice(0,sources['learn.ts'].indexOf('\nfunction learnRender()')).replace(/^import .*;$/gm,'').replace(/\besc\b/g,'learnEsc');
 const tail=`export function init(){setLayout('${layout}');root={};prof='${profile}';hand='${hand}';kidsLvl=1;adultDiff=0;acc=blank();kidsScore=0;nextLine();}
 export function snapshot(){return {pattern:st.pattern,pos:st.pos,errors:st.errors,marks:[...st.marks],acc:{...acc,intervals:[...acc.intervals]},kidsLvl,adultDiff,kidsScore,kidsLinesOnLvl,errWin:[...errWin],lineKeysCnt,lineErrCnt,metrics:metrics(),mood:kidsMood()};}
 export function tick(ch){learnHandleKey({key:ch,preventDefault(){}});}
 export function cleanProbe(s){return cleanLine(s);}
 export function generationProbe(k,d,e){kidsLvl=k;adultDiff=d;return genLine(e);}`;
 const joined=prefix+'\n'+sources['typing.ts']+'\n'+sources['keyboard.ts']+'\n'+sources['ngram.ts']+'\n'+sources['stats-store.ts'].replace(/^import .*;$/gm,'')+'\n'+learn+'\n'+tail;
 const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
 const m=await import('data:text/javascript;base64,'+Buffer.from(code+'\n//'+number++).toString('base64'));
 let seed=1943,at=100000;const oldRandom=Math.random,oldNow=Date.now;
 Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};Date.now=()=>at;
 m.init();const steps=[],start=m.snapshot();
 for(let line=0;line<4;line++){
  const pattern=m.snapshot().pattern;
  for(let i=0;i<pattern.length;i++){
   if(line>=2&&i%2===0&&pattern[i]!==' '){at+=110;m.tick('§');steps.push({ch:'§',at,expected:m.snapshot()});}
   at+=150;m.tick(pattern[i]);steps.push({ch:pattern[i],at,expected:i===pattern.length-1?m.snapshot():null});
  }
 }
 const cleanInput='éüçßœæ ЙйЁёъЪ',clean=m.cleanProbe(cleanInput);
 const generation=[];
 for(const level of profile==='kids'?[0,language==='ru'?15:12,99]:[1])for(const difficulty of profile==='kids'?[0]:[0,6])for(const easy of [false,true])for(const hard of [false,true]){
  seed=1943;values.set('tr_hardkeys',hard?'1':'0');
  generation.push({level,difficulty,easy,hard,line:m.generationProbe(level,difficulty,easy)});
 }
 Math.random=oldRandom;Date.now=oldNow;
 cases.push({os,language,profile,hand,layout,initial,start,steps,cleanInput,clean,generation});
}
await fs.writeFile(path.join(base,'test/fixtures/learning.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),cases}));
console.log(cases.length,'source learning scenarios /',cases.reduce((n,c)=>n+c.steps.length,0),'keypresses');
