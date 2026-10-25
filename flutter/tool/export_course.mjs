// Read-only extraction of the shipped course programme and deterministic test cases.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const require=createRequire('/Users/denisonosov/dev/typerighting-wt-release-20261024/package.json');
const ts=require('typescript');
const raw=await fs.readFile(path.join(root,'src/course.ts'),'utf8');
const prefix='const createState=()=>({}); const stats=()=>({wpm:0}); const localStorage={setItem(){}};';
const tail=`export {buildLessons,lessonLines,REAL_WORDS,SENTENCES};
export function starProbe(e,c){errs=e;chars=c;lesson={id:1};prog={stars:{}};finishLesson();return lastStars;}`;
const js=ts.transpileModule(prefix+raw.replace(/^import .*;$/gm,'')+tail,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const m=await import('data:text/javascript;base64,'+Buffer.from(js).toString('base64'));
const langs=['ru','en','es','de','fr','it','pt'];
const data={source:'2fa2b77f032e77b759b29b44d223c7f91578597b',sourceSha256:createHash('sha256').update(raw).digest('hex'),lessons:Object.fromEntries(langs.map(l=>[l,m.buildLessons(l)])),words:m.REAL_WORDS,sentences:m.SENTENCES};
const original=Math.random, cases=[];
for(const l of langs) for(const lesson of data.lessons[l]){
 let seed=1943;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 cases.push({language:l,lesson,lines:m.lessonLines(l,lesson)});
}
Math.random=original;
const stars=[0,1,7,8,9,100,101].map(e=>({errors:e,chars:100,stars:m.starProbe(e,100)}));
await fs.writeFile(path.join(root,'flutter/assets/baseline/course.json'),JSON.stringify(data));
await fs.writeFile(path.join(root,'flutter/test/fixtures/course-generation.json'),JSON.stringify({cases,stars}));
console.log('Exported',cases.length,'canonical course lesson fixtures');
