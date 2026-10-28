// Снимок экрана из запущенной Flutter web сборки без окон на маке (headless Chromium).
// Навигация — через дерево доступности Flutter (aria-label), данные — документ до старта приложения.
// node tool/acceptance/capture.mjs --url http://127.0.0.1:8093/ --w 390 --h 844 --dark 1 --seed seed.json \
//   --steps "Ещё;Настройки" --out actual.png [--dump 1]
// PLAYWRIGHT_CORE — путь к playwright-core (по умолчанию из ~/dev/psygames/frontend).
import { createRequire } from 'node:module';
import fs from 'node:fs';
const args = Object.fromEntries(process.argv.slice(2).reduce((a, v, i, arr) => (v.startsWith('--') ? [...a, [v.slice(2), arr[i + 1]]] : a), []));
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_CORE || '/Users/denisonosov/dev/psygames/frontend/node_modules/playwright-core');
const b = await chromium.launch({ headless: true });
const ctx = await b.newContext({ viewport: { width: +(args.w || 390), height: +(args.h || 844) }, deviceScaleFactor: +(args.dpr || 2), locale: args.locale || 'ru-RU', colorScheme: args.dark === '0' ? 'light' : 'dark' });
const extra = args.prefs ? JSON.parse(args.prefs) : null;
if (args.seed || extra) {
  const doc = args.seed ? fs.readFileSync(args.seed, 'utf8') : null;
  await ctx.addInitScript(({ doc, extra }) => {
    if (sessionStorage.getItem('seeded')) return;
    if (doc) localStorage.setItem('typefree.flutter.candidate.v1', doc);
    if (extra) for (const [k, v] of Object.entries(extra)) localStorage.setItem(k, v);
    sessionStorage.setItem('seeded', '1');
  }, { doc, extra });
}
const p = await ctx.newPage();
const errs = []; p.on('pageerror', e => errs.push(e.message));
await p.goto(args.url || 'http://127.0.0.1:8093/');
await p.waitForTimeout(+(args.wait || 6000));
await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await p.waitForTimeout(800);
for (const step of (args.steps || '').split(';').filter(Boolean)) {
  const [label, nth] = step.split('#');
  const box = await p.evaluate(({ label, nth }) => {
    const name = e => (e.getAttribute('aria-label') || e.innerText || '').trim();
    const nodes = [...document.querySelectorAll('flt-semantics, [aria-label], [role=button]')];
    const hits = nodes.filter(e => { const a = name(e); return a === label || a.startsWith(label + '\n') || a.startsWith(label + ' '); })
      .sort((x, y) => name(x).length - name(y).length);
    const e = hits[nth]; if (!e) return null; e.scrollIntoView({ block: 'center' }); const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, { label, nth: +(nth || 0) });
  if (!box) console.error('NOT FOUND step:', label); else await p.mouse.click(box.x, box.y);
  await p.waitForTimeout(+(args.stepWait || 1500));
}
if (args.dump) console.log(JSON.stringify(await p.evaluate(() => [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).filter(Boolean)), null, 0));
if (args.type) { // type an exercise for real (M3 result); \n = Enter
  // Focus the field first with a step (e.g. «Печатайте здесь»); Enter only
  // between lines, never at the end (it would press a focused Back button).
  const parts = args.type.split('\\n');
  for (let i = 0; i < parts.length; i++) {
    if (i) await p.keyboard.press('Enter');
    await p.keyboard.type(parts[i], { delay: +(args.typeDelay || 40) });
  }
  await p.waitForTimeout(+(args.stepWait || 1500));
}
await p.mouse.move(1, 1); // no hover tooltip in the shot
await p.waitForTimeout(400);
await p.screenshot({ path: args.out || 'actual.png' });
if (errs.length) console.error('page errors:', errs.slice(0, 3));
await b.close();
