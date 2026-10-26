// Synthetic execution of unchanged shipped statistics, never user storage.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const ts=createRequire('/Users/denisonosov/dev/typerighting-wt-release-20261024/package.json')('typescript');
const source=await fs.readFile(path.join(root,'src/stats-store.ts'),'utf8');
const cases=[
 {name:'threshold',events:[...Array.from({length:9},(_,i)=>({id:'a',ok:i!==2,at:100000+i*100})),{push:true,wpm:42,acc:90,at:101000},{id:'s',ok:true,at:101100},{push:true,wpm:0,acc:1,at:101200}]},
 {name:'timing-boundaries',events:[{id:'a',ok:true,at:100000},{id:'a',ok:true,at:100039},{id:'a',ok:true,at:100079},{id:'s',ok:false,at:100179},{id:'a',ok:true,at:112179},{id:'s',ok:true,at:124180},{id:'s',ok:true,at:124280,timed:false},{id:'a',ok:true,at:424281},{push:true,wpm:30,acc:100,at:424400}]},
 {name:'decay',initial:{a:{ok:6,err:2,t:400,nt:8,bt:300,ts:100000}},events:[{id:'a',ok:true,at:100000+21*86400000},{push:true,wpm:30,acc:99,at:100001+21*86400000}]},
 {name:'duration-boundary',events:[...Array.from({length:10},(_,i)=>({id:'s',ok:true,at:100000+i*100})),{push:true,wpm:40,acc:.98,at:3700000}]},
 {name:'ranking',initial:{a:{ok:8,err:2,t:100,nt:9,bt:80},s:{ok:9,err:1,t:200,nt:9,bt:150},d:{ok:10,err:0,t:500,nt:8,bt:220}},events:[]},
];
let seed=1943;const random=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n;};
for(let c=0;c<12;c++){
 let at=100000;const events=[];
 for(let i=0;i<120;i++){at += [0,39,40,100,12000,12001,300001,86400000][random(8)];
  events.push(i%23===22?{push:true,wpm:random(80),acc:random(101),at}:{id:['a','s','d','f','d1','comma'][random(6)],ok:random(4)>0,at,timed:random(7)>0});}
 cases.push({name:'random-'+c,events});
}
const keys=JSON.parse(await fs.readFile(path.join(root,'flutter/assets/baseline/keyboard.json'),'utf8')).windows.qwerty.keys;
const letters=keys.filter(k=>/^[a-z]$/i.test(k.baseEn)).map(k=>({id:k.id,ch:k.baseEn.toLowerCase()}));
for(const [i,c] of cases.entries()){
 const storage=new Map([['tr_keystats',JSON.stringify(c.initial??{})]]);
 globalThis.localStorage={getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v)};
 globalThis.window={setTimeout:()=>1};
 const js=ts.transpileModule(`const letterKeys=()=>${JSON.stringify(letters)};\n`+source.replace(/^import .*;$/gm,'')+'\nexport const snapshot=()=>JSON.parse(JSON.stringify(keystats));',{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
 const m=await import('data:text/javascript;base64,'+Buffer.from(js+'\n//'+i).toString('base64'));
 c.expected=[];
 for(const e of c.events){if(e.push)m.pushHistory(e.wpm,e.acc,e.at);else m.recordKey(e.id,e.ok,e.at,e.timed??true);
 c.expected.push({stats:m.snapshot(),history:m.history()});}
 c.result={stats:m.snapshot(),heat:m.heatMap()};
}
await fs.writeFile(path.join(root,'flutter/test/fixtures/key-statistics.json'),JSON.stringify({sha256:createHash('sha256').update(source).digest('hex'),cases}));
console.log(cases.length,'traces /',cases.reduce((n,c)=>n+c.events.length,0),'events');
