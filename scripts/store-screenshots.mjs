#!/usr/bin/env node
// typefree-store-screenshots · VER 1 · 01.10.2026 · typerighting-claude-mac · задача 32a36c96 (2/6)
// Кадры для App Store и Google Play из настоящего интерфейса. Снимать с production-сборки (vite build + preview):
// в dev видна кнопка «Сообщить о баге», которой в магазинной сборке нет.
// Магазинная оболочка имитируется так же, как её видит код: window.__TAURI_INTERNALS__ + UA и касания устройства →
// src/store-build.ts прячет соцфункции, как в сборке 2.60.1. Движок как у устройства: WebKit для iPhone/iPad
// (WKWebView), Chromium для Android (WebView). Телефон без клавиатуры стартует компаньоном (main.ts
// isPhoneNoKeyboard) — так и снимаем; планшет — тренажёром. Перед кадрами — настоящая тренировка (нажатия по
// упражнению), чтобы прогресс и карта ошибок были не пустыми.
// Запуск: npx vite build && npx vite preview --port 8017 --strictPort   (сервер — отдельно), затем
//   node scripts/store-screenshots.mjs http://localhost:8017 <папка> [en ru …] [--only appstore,play-phone …]
// PLAYWRIGHT_CORE=<путь к playwright-core>, если его нет в node_modules.
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const require = createRequire(import.meta.url);
const pw = require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const args = process.argv.slice(2);
const only = args.includes('--only') ? args.splice(args.indexOf('--only'), 2)[1] : null;
const [BASE = 'http://localhost:8017', OUT = 'store-shots', ...LANGS] = args;

const UA = {
  iphone: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
  ipad: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)', // iPadOS — настольный UA
  android: 'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36',
  tablet: 'Mozilla/5.0 (Linux; Android 15; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
};
// App Store: 6.9" 1320×2868 (APP_IPHONE_67), 13" 2752×2064 альбомно (APP_IPAD_PRO_3GEN_129).
// iPad 13" — горизонтально: тренажёр широкий, в портрете нижние две трети кадра пустые (замер 01.10).
// Планшеты Play — вертикально: в альбомной 960×600 и 1280×800 клавиатура тренажёра обрезана снизу (замер 01.10).
// Play: сторона 320–3840 px, длинная не больше двух коротких.
const DEVICES = {
  'appstore-iphone-6.9': { engine: 'webkit', w: 440, h: 956, dsf: 3, ua: UA.iphone, phone: true },
  'appstore-ipad-13': { engine: 'webkit', w: 1376, h: 1032, dsf: 2, ua: UA.ipad, phone: false },
  // ширина Pixel 8 (412 dp), 1236×2448: в 360×640 и 360×712 клавиатура тренажёра уходит за нижний край (замер 01.10);
  // Play пускает длинную сторону не больше двух коротких
  'play-phone': { engine: 'chromium', w: 412, h: 816, dsf: 3, ua: UA.android, phone: true },
  'play-tablet-7': { engine: 'chromium', w: 600, h: 960, dsf: 2, ua: UA.tablet, phone: false },
  'play-tablet-10': { engine: 'chromium', w: 800, h: 1280, dsf: 2, ua: UA.tablet, phone: false },
};

function storeShell({ ua, lang, pet }) {
  const nav = (k, v) => Object.defineProperty(Navigator.prototype, k, { get: () => v, configurable: true });
  nav('userAgent', ua);
  nav('maxTouchPoints', 5);
  const real = window.matchMedia.bind(window);
  window.matchMedia = (q) => (/pointer:\s*coarse|hover:\s*none/.test(q)
    ? { matches: true, media: q, onchange: null, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {}, dispatchEvent: () => false }
    : real(q));
  window.__TAURI_INTERNALS__ = { invoke: () => Promise.reject(new Error('store-sim')), transformCallback: () => 0, convertFileSrc: (s) => s,
    metadata: { currentWindow: { label: 'main' }, currentWebview: { windowLabel: 'main', label: 'main' } } };
  if (!localStorage.getItem('tf_shots_seeded')) {
    localStorage.setItem('tf_shots_seeded', '1');
    localStorage.setItem('tr_lang', lang);
    localStorage.setItem('tr_profile', 'm');
    localStorage.setItem('tr_mode', 'trainer'); // сначала тренировка — для данных; телефон потом вернём в компаньон
    // питомец на узком экране закрывает подписи карточек (задача 5169679b) — там снимаем без него;
    // выключатель — настройка самого приложения (tr_pet)
    if (!pet) localStorage.setItem('tr_pet', '0');
  }
}

// Печать по упражнению: ↵ — Enter, остальное — символ как есть. ms — пауза между нажатиями (~60 WPM при 200).
async function type(page, count, ms = 200) {
  const keys = await page.evaluate(() => {
    const cur = document.querySelector('.pattern span.cur');
    if (!cur) return [];
    const spans = [...cur.parentElement.querySelectorAll('span')];
    return spans.slice(spans.indexOf(cur)).map((s) => (s.classList.contains('nl') ? 'Enter' : s.textContent));
  });
  for (const key of keys.slice(0, count)) {
    await page.evaluate((k) => document.body.dispatchEvent(new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true })), key);
    await page.waitForTimeout(ms);
  }
  return Math.min(count, keys.length);
}

async function shoot(page, dir, name) {
  await page.waitForTimeout(5200); // тост достижения гаснет через 4,5 с
  await page.screenshot({ path: join(dir, `${name}.png`) });
  console.log('  ', name);
}

async function goto(page, mode) {
  const b = page.locator(`[data-goto="${mode}"]`).first();
  if (await b.count()) { await b.click(); await page.waitForTimeout(1500); return true; }
  return false;
}

for (const lang of LANGS.length ? LANGS : ['en']) {
  for (const [name, d] of Object.entries(DEVICES)) {
    if (only && !only.split(',').some((o) => name.startsWith(o))) continue;
    const dir = join(OUT, lang, name);
    mkdirSync(dir, { recursive: true });
    console.log(`▶ ${lang} · ${name} (${d.w * d.dsf}×${d.h * d.dsf})`);
    const browser = await pw[d.engine].launch();
    const ctx = await browser.newContext({ viewport: { width: d.w, height: d.h }, deviceScaleFactor: d.dsf, hasTouch: true,
      isMobile: d.engine === 'chromium' && d.phone, userAgent: d.ua, locale: lang === 'ru' ? 'ru-RU' : 'en-US' });
    await ctx.addInitScript(storeShell, { ua: d.ua, lang, pet: d.w >= 700 });
    const page = await ctx.newPage();
    await page.goto(BASE);
    await page.waitForTimeout(2500);
    // старт — главная «С чего начать?»; на планшете это и первый кадр
    if (!d.phone) await shoot(page, dir, '01-home');
    // данные для прогресса и карты ошибок: тренировка по упражнению
    await page.locator('[data-go="train"]').first().click();
    await page.waitForTimeout(1500);
    // стартовый банк «Слова в предложениях» — английский; русской карточке — русские фразы
    if (lang === 'ru') { await page.selectOption('#bank', 'ruPhrases'); await page.waitForTimeout(1500); }
    await type(page, 260, 110);
    await page.waitForTimeout(1500);
    if (d.phone) {
      await page.evaluate(() => localStorage.setItem('tr_mode', 'companion'));
      await page.reload();
      await page.waitForTimeout(2500);
      await shoot(page, dir, '05-companion'); // честный экран телефона «нужна клавиатура» — последним кадром
      await page.locator('#comp-train').click(); // «всё равно открыть тренажёр» ведёт на главную
      await page.waitForTimeout(1500);
      await page.locator('[data-go="train"]').first().click();
      await page.waitForTimeout(1500);
      if (lang === 'ru') { await page.selectOption('#bank', 'ruPhrases'); await page.waitForTimeout(1500); } // банк сбросился после перезагрузки
      await type(page, 18);
      await shoot(page, dir, '01-trainer');
      if (await goto(page, 'learn')) { await type(page, 12); await shoot(page, dir, '02-learn'); }
      if (await goto(page, 'course')) await shoot(page, dir, '03-course');
      if (await goto(page, 'compete')) await shoot(page, dir, '04-compete');
    } else {
      if (await goto(page, 'train')) { await type(page, 22); await shoot(page, dir, '02-trainer'); }
      if (await goto(page, 'learn')) { await type(page, 12); await shoot(page, dir, '03-learn'); }
      if (await goto(page, 'course')) await shoot(page, dir, '04-course');
      if (await goto(page, 'compete')) await shoot(page, dir, '05-compete');
      if (await goto(page, 'memorize')) await shoot(page, dir, '06-memorize');
    }
    await browser.close();
  }
}
