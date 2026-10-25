// Read-only export from the frozen TypeScript baseline. No user storage is read.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const root = path.resolve(import.meta.dirname, '../..');
const require = createRequire('/Users/denisonosov/dev/typerighting-wt-release-20261024/package.json');
const ts = require('typescript');
globalThis.localStorage = {getItem: () => null, setItem: () => {}};
const sha = s => createHash('sha256').update(s).digest('hex');
const sources = {};
async function moduleOf(file, extra = '', tag = '') {
  const source = await fs.readFile(path.join(root, 'src', file), 'utf8');
  sources[file] = sha(source);
  const js = ts.transpileModule(source + '\n' + extra, {compilerOptions:{
    target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022
  }}).outputText;
  return import('data:text/javascript;base64,' + Buffer.from(js + '\n//' + tag).toString('base64'));
}
const classic = await moduleOf('classic.ts');
const raven = await moduleOf('raven.ts');
const ru = await moduleOf('ru.ts');
const options = await moduleOf('practice-options.ts');
const i18n = await moduleOf('i18n.ts');
const corpus = await moduleOf('corpus.ts');
const catalog = {};
for (const lang of i18n.LANGS) {
  catalog[lang] = [...classic.classicExercises(lang), ...raven.ravenExercises(lang),
    ...(lang === 'ru' ? [...ru.ruWordsExercises(), ...ru.ruPhrasesExercises()] : []),
    ...options.numericExercises()].map(e => ({...e, plainLines: options.practiceLines(e.lines, true)}));
}
const keyboard = {};
for (const os of ['windows', 'mac']) {
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{
    platform: os === 'mac' ? 'MacIntel' : 'Win32', userAgent: os
  }});
  const k = await moduleOf('keyboard.ts', `
export function snapshot(layout) {
 setLayout(layout);
 return {layoutName: layout, keys: Object.values(GEO).map(g=>({...g,...engraving(g),baseEn:g.en})),
   en: EN_MAP, ru: RU_MAP, layout: LAYOUT_MAP,
   homeOf: HOME_OF, leftHand: [...LEFT_HAND], arrows: ARROWS};
}
`, os);
  keyboard[os] = Object.fromEntries(['qwerty','azerty','qwertz'].map(l => [l,k.snapshot(l)]));
}
const engine = await moduleOf('typing.ts');
const cases = [];
const events = (text, at = 1000) => text.split('').map((ch,i)=>({op:'char',ch,block:true,at:at+i*120}));
cases.push({name:'newline',lines:['ab','CD'],events:events('ab\rCD')});
cases.push({name:'error-and-backspace',lines:['ab cd'],events:[
  {op:'char',ch:'x',block:true,at:1000},
  {op:'char',ch:'a',block:true,at:1100},
  {op:'backspace',at:1200}, ...events('ab cd',1300),
  {op:'char',ch:'z',block:false,at:3000}, {op:'backspace',at:3100}]});
cases.push({name:'free-errors',lines:['abc'],events:events('xzc').map(e=>({...e,block:false}))});
cases.push({name:'empty-free',lines:[],events:[{op:'char',ch:'a',block:false,at:1000}]});
cases.push({name:'empty-block',lines:[''],events:[{op:'char',ch:'a',block:true,at:1000}]});
cases.push({name:'epoch-zero',lines:['abc'],events:events('abc',0)});
cases.push({name:'unicode',lines:['éё😀'],events:events('éё😀')});
let seed = 1943;
const rand = n => { seed = (Math.imul(seed,1664525)+1013904223)>>>0; return seed%n; };
for (let n=0;n<40;n++) {
 const sample = ['The fox.', 'дом кот ёж', 'café déjà', 'ä ö ß', 'a\nb'][n%5];
 const ev = [];
 for (let i=0;i<70;i++) ev.push(rand(8)===0 ? {op:'backspace',at:1000+i*137} :
   {op:'char',ch:sample[rand(sample.length)],block:n%2===0,at:1000+i*137});
 cases.push({name:'generated-'+n,lines:sample.split('\n'),events:ev});
}
const originalNow = Date.now;
for (const item of cases) {
 const st = engine.createState(item.lines);
 item.expected = [];
 for (const e of item.events) {
  Date.now = () => e.at;
  let result = null;
  if (e.op==='backspace') engine.backspace(st);
  else result = engine.pressChar(st,e.ch,e.block);
  item.expected.push({pos:st.pos,errors:st.errors,startedAt:st.startedAt,
    finishedAt:st.finishedAt,marks:[...st.marks],stats:engine.stats(st),result});
 }
}
Date.now = originalNow;
await fs.mkdir(path.join(root,'flutter/assets/baseline'),{recursive:true});
await fs.mkdir(path.join(root,'flutter/test/fixtures'),{recursive:true});
await fs.writeFile(path.join(root,'flutter/assets/baseline/catalog.json'), JSON.stringify({catalog,dict:i18n.DICT,corpus:corpus.CORPUS}));
await fs.writeFile(path.join(root,'flutter/assets/baseline/keyboard.json'), JSON.stringify(keyboard));
await fs.writeFile(path.join(root,'flutter/test/fixtures/typing-traces.json'), JSON.stringify(cases));
await fs.writeFile(path.join(root,'flutter/docs/baseline-export.json'),JSON.stringify({
 source:'2fa2b77f032e77b759b29b44d223c7f91578597b',sourceHashes:sources,
 exerciseCounts:Object.fromEntries(Object.entries(catalog).map(([l,c])=>[l,c.length])),
 traces:cases.length,events:cases.reduce((n,c)=>n+c.events.length,0),
 hiddenBanks:['abandon','engRus','letterByLetter'],scope:'source data, no user storage'
},null,2));
console.log('Exported',Object.values(catalog).flat().length,'exercise variants,',cases.length,'engine traces');
