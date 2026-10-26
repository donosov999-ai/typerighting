// Frozen source execution with seeded randomness and synthetic statistics only.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const ts=createRequire('/Users/denisonosov/dev/typerighting-wt-release-20261024/package.json')('typescript');
const ng=await fs.readFile(path.join(root,'src/ngram.ts'),'utf8'),stats=await fs.readFile(path.join(root,'src/stats-store.ts'),'utf8');
const keyboards=JSON.parse(await fs.readFile(path.join(root,'flutter/assets/baseline/keyboard.json'),'utf8'));
const corpus=JSON.parse(await fs.readFile(path.join(root,'flutter/assets/baseline/catalog.json'),'utf8')).corpus;
const cases=[];let number=0;
for(const os of ['windows','mac'])for(const language of ['ru','en','es','de','fr','it','pt'])for(const state of ['empty','weak','recovery']){
 const letters=Object.fromEntries(['en','ru'].map(l=>[l,keyboards[os].qwerty.keys.filter(g=>/^[A-Za-zА-Яа-яЁё]$/.test(l==='en'?g.baseEn:g.ru)).map(g=>({id:g.id,ch:(l==='en'?g.baseEn:g.ru).toLowerCase()}))]));
 const initial=state==='empty'?{}:{a:{ok:8,err:2,t:100,nt:9,bt:80},s:{ok:9,err:1,t:200,nt:9,bt:150},d:{ok:10,err:0,t:state==='weak'?500:300,nt:8,bt:100},f:{ok:3,err:3,t:100,nt:9,bt:100},tilde:{ok:3,err:7},backslash:{ok:4,err:6}};
 globalThis.localStorage={getItem:k=>k==='tr_keystats'?JSON.stringify(initial):null,setItem(){}};
 const prefix=`const CORPUS=${JSON.stringify(corpus)};const letters=${JSON.stringify(letters)};const letterKeys=l=>letters[l];\n`;
 const code=ts.transpileModule(prefix+ng+'\n'+stats.replace(/^import .*;$/gm,''),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
 const m=await import('data:text/javascript;base64,'+Buffer.from(code+'\n//'+number++).toString('base64'));
 let seed=1943;const old=Math.random;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const kb=language==='ru'?'ru':'en';
 const result={weak:m.weakKeys(kb),recovery:m.recoveryKeys(kb),weights:m.letterWeights(kb),lines:m.weakDrill(language)};
 Math.random=old;cases.push({os,language,state,initial,letters:letters[kb],result});
}
await fs.writeFile(path.join(root,'flutter/test/fixtures/adaptive.json'),JSON.stringify({sources:{ngram:createHash('sha256').update(ng).digest('hex'),stats:createHash('sha256').update(stats).digest('hex')},cases}));
console.log(cases.length,'adaptive source cases');
