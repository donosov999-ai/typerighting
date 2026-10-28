// Source numerical rules only; all storage/history/time here is synthetic.
import fs from 'node:fs/promises';import path from 'node:path';import{createRequire}from'node:module';import{createHash}from'node:crypto';
const root=path.resolve(import.meta.dirname,'../..'),ts=createRequire(path.join(root,'package.json'))('typescript');
const sources=Object.fromEntries(await Promise.all(['stats-store.ts','achievements.ts'].map(async n=>[n,await fs.readFile(path.join(root,'src',n),'utf8')])));
let values=new Map();globalThis.localStorage={getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v)};
globalThis.window={setTimeout:()=>1};
const strip=s=>s.replace(/^import .*;$/gm,'');
const badges=strip(sources['achievements.ts'].slice(0,sources['achievements.ts'].indexOf('function langsTried')));
const joined="const t=k=>k;\n"+strip(sources['stats-store.ts'])+'\n'+badges+'\nexport function badgeProbe(stats){return RULES.filter(r=>r.need(stats)).map(r=>r.id);}';
const code=ts.transpileModule(joined,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const m=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const sequences=[[],[5],[5,6,7,8],[5,5,5,5,5],[1,2,3,4,5],[10,9,8,7,6],[5,40,1,60,3,10],[39,39.04,39.08,39.12,39.16],Array.from({length:50},(_,i)=>20+i*.8)];
let seed=712;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
for(let i=0;i<100;i++)sequences.push(Array.from({length:5+i%39},(_,j)=>Math.round((5+j*random()*10+random()*15)*100)/100));
const forecasts=[];
for(const ys of sequences)for(const target of [20,40,70,120,9999]){
 values.set('tr_history',JSON.stringify(ys.map((wpm,i)=>({t:i*86400000,wpm,acc:100}))));
 forecasts.push({ys,target,result:m.forecast(target)});
}
const badgesOut=[];
for(const sessions of [0,1,9,10,49,50])for(const streak of [0,2,3,6,7,29,30])for(const maxWpm of [29,30,49,50,69,70])for(const maxAcc of [98,99])for(const langs of [2,3]){
 const input={sessions,streak,maxWpm,maxAcc,langs};badgesOut.push({input,result:m.badgeProbe(input)});
}
const streaks=[];
for(const now of [0,86400000-1,86400000,30*86400000+3600000])for(const days of [[],[0],[0,0,1],[0,1,2],[27,28,29],[28,30],[27,28,29,30]]){
 const times=days.map(d=>d*86400000+100);values.set('tr_history',JSON.stringify(times.map(t=>({t,wpm:40,acc:100}))));
 streaks.push({now,times,result:m.streakDays(now)});
}
await fs.writeFile(path.join(root,'flutter/test/fixtures/progress.json'),JSON.stringify({sources:Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')])),forecasts,badges:badgesOut,streaks}));
console.log(`${forecasts.length} forecasts / ${badgesOut.length} badge threshold sets / ${streaks.length} UTC streaks`);
