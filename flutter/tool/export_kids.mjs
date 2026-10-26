// Execute the shipped kids controller, replacing only browser/render/audio ports.
// No user storage is read. The exported content retains source IDs and order.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['kids.ts','typing.ts','keyboard.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
const strip=s=>s.replace(/^import .*;$/gm,'');
globalThis.localStorage={getItem:()=>null,setItem(){}};
Object.defineProperty(globalThis,'navigator',{configurable:true,value:{platform:'Win32',userAgent:'fixture'}});
const beforeRender=strip(sources['kids.ts'].slice(0,sources['kids.ts'].indexOf('// ── Рендер')));
const prefix=`let uiLanguage='ru';const lang=()=>uiLanguage,t=k=>k;const speak=()=>{};const sfx={catSad(){},catHappy(){},fanfare(){},star(){}};const kidsRender=()=>{},clearDoneTimer=()=>{};`;
const tail=`export function init(id,stars){uiLanguage='ru';prog={stars:{...stars}};playedThisSession=0;lastStars=0;startLevel(KIDS_LEVELS.find(l=>l.id===id)!);}
export function key(key){kidsHandleKey({key,preventDefault(){}});}
export function snap(){return {screen,id:level!.id,wordIdx,pattern:st.pattern,pos:st.pos,errors:levelErrors,characters:levelChars,stars:lastStars,played:playedThisSession,progress:{...prog.stars},marks:[...st.marks]};}
export function isOpen(id){return unlocked(id);}
export function opposite(ch,ru){const k=Object.values(GEO).find(g=>(ru?g.ru:g.en)===ch);return k?(ru?k.en:k.ru):ch;}`;
const joined=prefix+'\n'+strip(sources['typing.ts'])+'\n'+strip(sources['keyboard.ts'])+'\n'+beforeRender+'\n'+tail;
const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const cases=[];
for(const level of m.KIDS_LEVELS)for(const errors of [0,1,2,4])for(const opposite of [false,true]){
 const initial={};for(let id=1;id<level.id;id++)initial[id]=2;
 m.init(level.id,initial);const events=[];
 function press(key){m.key(key);events.push({key,after:m.snap()});}
 // Backspace is ignored, Enter is a blocked wrong attempt in this mode.
 press('Backspace');
 if(errors>0){press('Enter');for(let i=1;i<errors;i++)press('§');}
 for(const word of level.words)for(const ch of word)press(opposite?m.opposite(ch,level.lang==='ru'):ch);
 press('Backspace');press('§'); // complete results must be immutable
 cases.push({id:level.id,errors,opposite,initial,events,result:m.snap(),unlocked:m.KIDS_LEVELS.filter(l=>m.isOpen(l.id)).map(l=>l.id)});
}
const hashes=Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')]));
await fs.writeFile(path.join(root,'flutter/assets/baseline/kids.json'),JSON.stringify({sources:hashes,levels:m.KIDS_LEVELS}));
await fs.writeFile(path.join(root,'flutter/test/fixtures/kids.json'),JSON.stringify({sources:hashes,cases}));
console.log(`${m.KIDS_LEVELS.length} levels / ${cases.length} source runs / ${cases.reduce((n,c)=>n+c.events.length,0)} input events`);
