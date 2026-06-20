// AI-режим обучения (запрос Дениса 13.06.2026) — VerseQ-подобный «умный» режим:
// бесконечный поток фонетически связных строк (n-граммы), адаптивно
// подмешивающих слабые буквы пользователя, с метриками Мастерство / Ритмичность
// / Темп. Адаптируется под профиль (м/ж/дети). Прогресс/статистика — общие.
import { createState, pressChar, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor, handLetters, getLayout } from './keyboard';
import { recordKey, pushHistory, letterWeights, heatMap } from './stats-store';
import { buildModel, generate, type NgramModel } from './ngram';
import { CORPUS } from './corpus';
import { sfx } from './sound';
import { t, lang, type Lang } from './i18n';
import type { Profile } from './profiles';

let model: NgramModel | null = null;
let modelLang: Lang | null = null;
// клавиатурный алфавит: ru — кириллица, остальные 6 языков — латиница (QWERTY-схема)
function kbLang(): 'en' | 'ru' { return lang() === 'ru' ? 'ru' : 'en'; }
function ensureModel(L: Lang) {
  if (model && modelLang === L) return;
  model = buildModel(CORPUS[L] ?? CORPUS.en, L === 'ru' ? 'ru' : 'en', 3);
  modelLang = L;
}

// Накопленные метрики сессии
interface Acc { correct: number; keys: number; errors: number; ms: number; intervals: number[]; lines: number; }
let acc: Acc = blank();
function blank(): Acc { return { correct: 0, keys: 0, errors: 0, ms: 0, intervals: [], lines: 0 }; }

let st: TypingState = createState(['']);
let lineStart = 0;     // время начала текущей строки (мс)
let lastStroke = 0;    // время прошлого нажатия (для интервалов)
let prof: Profile = 'm';
let hand: 'both' | 'left' | 'right' = 'both'; // однорукие режимы (реабилитация / слабая рука)
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

// Детская «лесенка» букв (по классике постановки): старт — указательные пальцы (А О),
// потом средние (Л В), безымянные, мизинцы, затем ряды; мелкий шаг по паре букв.
// Сложные (Э Щ Ц Х) — В КОНЦЕ, после освоения. Совсем убраны навсегда только Ё и Ъ.
const KIDS_LADDER_RU = ['ао', 'лв', 'ыд', 'фж', 'пр', 'ен', 'кт', 'им', 'су', 'гб', 'шй', 'зч', 'ья', 'ю', 'цщ', 'хэ'];
const KIDS_LADDER_EN = ['fj', 'dk', 'sl', 'ag', 'eh', 'ir', 'nt', 'ou', 'mc', 'vb', 'wp', 'yx', 'zq'];
const VOWELS = new Set('аоыуиеэюяaeiou'.split(''));
let kidsLvl = Math.max(0, +(localStorage.getItem('tr_kids_ai_lvl') ?? '0') || 0);
function kidsLadder(KL: 'en' | 'ru') { return KL === 'ru' ? KIDS_LADDER_RU : KIDS_LADDER_EN; }
function kidsCap(KL: 'en' | 'ru') { return kidsLadder(KL).length - 1; }
function kidsPool(KL: 'en' | 'ru') { const L = kidsLadder(KL); return L.slice(0, Math.min(kidsLvl, L.length - 1) + 1).join(''); }
// Адаптивное состояние (общее для всех профилей)
let lineKeysCnt = 0, lineErrCnt = 0;     // нажатий/ошибок в текущей строке
let errWin: number[] = [];               // errRate последних строк (скользящее окно)
let kidsLinesOnLvl = 0;                  // строк отыграно на текущем уровне (дети)
let kidsEasyNext = false;                // детям: следующую строку проще (передышка)
let adultDiff = 0;                       // взрослый AI: уровень сложности 0..6 (растёт по успеху)
let adultEasyNext = false;               // взрослым: следующую строку проще
let kidsScore = 0;                       // детям: очки (+ за верную букву, − за ошибку)
function saveKidsLvl() { try { localStorage.setItem('tr_kids_ai_lvl', String(kidsLvl)); } catch { /* */ } }
// ё/ъ по умолчанию выключены (редкие, навыка почти не дают); галочка в настройках включает.
export function hardKeysOn(): boolean { try { return localStorage.getItem('tr_hardkeys') === '1'; } catch { return false; } }
function sanitizeHard(line: string): string {
  if (hardKeysOn() || kbLang() !== 'ru') return line;
  return line.replace(/[ёЁ]/g, (c) => (c === 'Ё' ? 'Е' : 'е')).replace(/[ъЪ]/g, '');
}
// Спецбуквы (é ü ç ß …) оставляем только при активной нац. раскладке (AZERTY/QWERTZ),
// где они вводятся нативно; на QWERTY приводим к ASCII — иначе их не набрать (выбор A, 20.06).
function sanitizeDiacritics(line: string): string {
  if (getLayout() !== 'qwerty') return line;
  return line.normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/ß/g, 'ss').replace(/œ/g, 'oe').replace(/æ/g, 'ae');
}
function cleanLine(line: string): string { return sanitizeDiacritics(sanitizeHard(line)); }

// Генерация детской строки: упор на новые буквы уровня и на те, где ошибаешься.
// easy=true — строка-передышка (без новых букв, только освоенное).
function kidsGenLine(easy = false): string {
  const KL = kbLang();
  // ФАЗА 2 — алфавит освоен (лесенка дошла до конца): переходим на реальные
  // сочетания/фонемы языка (ngram корпуса, как у взрослых), а не случайные слоги.
  if (kidsLvl >= kidsCap(KL)) {
    ensureModel(lang());
    const line = generate(model!, { chars: 22, weight: letterWeights(KL, easy ? 2 : 5), maxWord: easy ? 4 : 6 });
    return cleanLine(line); // ё/ъ + спецбуквы по раскладке
  }
  // ФАЗА 1 — лесенка клавиш: случайные слоги из освоенных букв (постановка пальцев)
  const pool = kidsPool(KL).split('');
  const newest = easy ? '' : kidsLadder(KL)[Math.min(kidsLvl, kidsCap(KL))]; // буквы последнего уровня
  const heat = heatMap(3);               // errRate по клавишам (per-key)
  const ruKb = KL === 'ru';
  const bag: string[] = [];
  for (const ch of pool) {
    let wt = 1;
    if (newest.includes(ch)) wt *= 4;    // новые буквы — прорабатываем чаще
    const id = keyIdFor(ch, ruKb);
    const rate = id ? heat[id] : undefined;
    if (rate && rate > 0) wt *= 1 + rate * 6;   // слабые (где ошибки) — тоже чаще
    for (let i = 0; i < Math.max(1, Math.round(wt)); i++) bag.push(ch);
  }
  const vow = bag.filter((c) => VOWELS.has(c));
  const con = bag.filter((c) => !VOWELS.has(c));
  const pick = (a: string[]) => a[Math.floor(Math.random() * a.length)];
  const out: string[] = [];
  let guard = 0;
  while (out.join(' ').length < 20 && guard++ < 40) {
    const len = 2 + Math.floor(Math.random() * 3); // короткие слова 2–4 буквы
    let w = '';
    for (let i = 0; i < len; i++) {
      w += (vow.length && con.length) ? (i % 2 === 1 ? pick(vow) : pick(con)) : pick(bag);
    }
    out.push(w);
  }
  return out.join(' ');
}

// errRate скользящего окна последних 3 строк (общая для kids/adult)
function winAvg(): number | null {
  const er = lineKeysCnt > 0 ? lineErrCnt / lineKeysCnt : 0;
  errWin.push(er); if (errWin.length > 3) errWin.shift();
  if (errWin.length < 2) return null;
  return errWin.reduce((a, b) => a + b, 0) / errWin.length;
}
// Дети: окно ошибок → +пара букв / передышка / откат уровня.
function kidsAdapt() {
  const avg = winAvg();
  kidsLinesOnLvl++;
  if (avg === null || kidsLinesOnLvl < 2) return; // дать обжиться ≥2 строки на уровне
  if (avg < 0.10 && kidsLvl < kidsCap(kbLang())) {       // освоено → +пара букв
    kidsLvl++; saveKidsLvl(); kidsLinesOnLvl = 0; errWin = []; kidsEasyNext = false; sfx.upgrade();
  } else if (avg > 0.25) {                                // перегруз → передышка
    kidsEasyNext = true;
    if (avg > 0.35 && kidsLvl > 0) { kidsLvl--; saveKidsLvl(); } // совсем тяжело → шаг назад
    kidsLinesOnLvl = 0; errWin = [];
  }
}
// Взрослые: окно ошибок → сложнее (длиннее слова, больше упор на слабые) / передышка.
function adultAdapt() {
  const avg = winAvg();
  if (avg === null) return;
  if (avg < 0.06 && adultDiff < 6) { adultDiff++; errWin = []; adultEasyNext = false; sfx.upgrade(); }  // освоено → сложнее
  else if (avg > 0.18) {                                                                  // перегруз → передышка
    adultEasyNext = true;
    if (avg > 0.30 && adultDiff > 0) adultDiff--;                                          // тяжело → шаг назад
    errWin = [];
  }
}

function genLine(easy = false): string {
  if (prof === 'kids') return kidsGenLine(easy);   // детям — лёгкие буквы по адаптивной лесенке
  const L = lang();              // корпус — по языку интерфейса (7 языков)
  const KL = kbLang();           // алфавит клавиш — ru или латиница
  const chars = prof === 'f' ? 40 : 50;     // kids уже обработан выше (kidsGenLine)
  if (hand === 'both') {
    ensureModel(L);
    // адаптивно: освоил — длиннее слова и сильнее упор на слабые; передышка (easy) — проще
    const mw = easy ? 5 : Math.min(12, 6 + adultDiff);
    const boost = easy ? 3 : 4 + adultDiff;
    return cleanLine(generate(model!, { chars, weight: letterWeights(KL, boost), maxWord: mw }));
  }
  const maxWord = 8;
  // одна рука: слоги из букв этой руки, слабые буквы — чаще (осмысленных слов
  // одной рукой почти нет, цель — досягаемость и сила пальцев конкретной руки)
  const w = letterWeights(KL);
  const bag: string[] = [];
  for (const ch of handLetters(KL, hand)) {
    const rep = Math.max(1, Math.round(w[ch] ?? 1));
    for (let i = 0; i < rep; i++) bag.push(ch);
  }
  if (bag.length === 0) return '';
  const out: string[] = [];
  let guard = 0;
  while (out.join(' ').length < chars && guard++ < 60) {
    const len = 3 + Math.floor(Math.random() * (maxWord - 2));
    let word = '';
    for (let i = 0; i < len; i++) word += bag[Math.floor(Math.random() * bag.length)];
    out.push(word);
  }
  return out.join(' ');
}

function nextLine() {
  const easy = prof === 'kids' ? kidsEasyNext : adultEasyNext;
  st = createState([genLine(easy)]);
  kidsEasyNext = false; adultEasyNext = false;
  lineKeysCnt = 0; lineErrCnt = 0;
  lineStart = 0; lastStroke = 0;
}

export function learnEnter(container: HTMLElement, profile: Profile, exit: () => void) {
  root = container; onExit = exit; prof = profile;
  acc = blank();
  kidsScore = 0;
  nextLine();
  learnRender();
}

export function learnExit() {
  // зафиксировать историю по накопленному
  const m = metrics();
  if (m.mastery > 0) pushHistory(Math.round(m.mastery / 5), m.accuracy, Date.now());
  onExit?.();
}

export function learnHandleKey(e: KeyboardEvent) {
  if (!root) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();

  const now = Date.now();
  if (st.startedAt === null) { lineStart = now; lastStroke = now; }
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  const rc = /[а-яё]/i.test(st.pattern);
  const r = pressChar(st, ch, true); // блок при ошибке (как VerseQ)

  // тайминг: интервал между верными нажатиями (для ритмичности)
  if (r.accepted) {
    const dt = now - lastStroke;
    if (dt > 0 && dt < 3000) acc.intervals.push(dt); // отсекаем паузы >3с
    lastStroke = now;
    acc.keys++;
    if (expected !== ' ' && expected !== '\n') acc.correct++;
  }
  if (expected && expected !== ' ' && expected !== '\n') { const id = keyIdFor(expected, rc); if (id) recordKey(id, !r.wrong); }
  if (r.wrong) acc.errors++;
  // адаптив: считаем нажатия/ошибки текущей строки (окно — для kids и взрослых)
  if (expected && expected !== ' ' && expected !== '\n') {
    lineKeysCnt++;
    if (r.wrong) { lineErrCnt++; if (prof === 'kids') kidsScore = Math.max(0, kidsScore - 5); }   // ошибка − очки
    else if (prof === 'kids') kidsScore += 10;                                                     // верно + очки
  }

  if (r.finished) {
    acc.ms += now - lineStart;
    acc.lines++;
    if (prof === 'kids') kidsAdapt();          // дети: окно ошибок → +буквы/передышка/откат
    else if (hand === 'both') adultAdapt();    // взрослые: окно ошибок → сложнее/проще
    nextLine();
  }
  learnRender();
}

interface Metrics { mastery: number; tempo: number; rhythm: number; accuracy: number; }
function metrics(): Metrics {
  const min = acc.ms / 60000;
  const mastery = min > 0 ? Math.round(acc.correct / min) : 0;          // символов/мин (как VerseQ)
  const tempo = min > 0 ? Math.round((acc.correct + acc.errors) / min) : 0;
  const total = acc.correct + acc.errors;
  const accuracy = total > 0 ? Math.round((acc.correct / total) * 100) : 100;
  let rhythm = 0;
  if (acc.intervals.length >= 4) {
    const mean = acc.intervals.reduce((a, b) => a + b, 0) / acc.intervals.length;
    const variance = acc.intervals.reduce((a, b) => a + (b - mean) ** 2, 0) / acc.intervals.length;
    const cv = Math.sqrt(variance) / (mean || 1);
    rhythm = Math.max(0, Math.min(100, Math.round((1 - cv) * 100)));
  }
  return { mastery, tempo, rhythm, accuracy };
}

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

function renderPattern(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    html += `<span class="${cls}">${esc(st.pattern[i])}</span>`;
  }
  return html;
}

function masteryLabel(v: number): string {
  if (v >= 300) return t('learn.lvl.pro');
  if (v >= 200) return t('learn.lvl.work');
  if (v >= 70) return t('learn.lvl.good');
  return t('learn.lvl.start');
}

// Кадр эмоции котика (0 грустный … 8 восторг) по точности + бонус за очки
function kidsMood(): number {
  if (acc.correct + acc.errors === 0) return 4; // старт — нейтральный
  const a = metrics().accuracy;
  let m = a >= 99 ? 8 : a >= 95 ? 7 : a >= 90 ? 6 : a >= 84 ? 5 : a >= 76 ? 4 : a >= 66 ? 3 : a >= 55 ? 2 : a >= 45 ? 1 : 0;
  if (kidsScore >= 300 && m < 8) m++;   // много очков — котик ещё счастливее
  return Math.max(0, Math.min(8, m));
}

function learnRender() {
  if (!root) return;
  const m = metrics();
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  const kids = prof === 'kids';
  root.innerHTML = `
    <div class="wrap learn">
      <header class="mode-head">
        <button id="ai-exit" class="mode-back">${t('nav.back')}</button>
        <h1>🤖 ${t('learn.title')}</h1>
      </header>
      <p class="c-intro">${kids ? t('learn.intro.kids') : t('learn.intro')}</p>
      ${kids ? '' : `<div class="hand-row">
        <span class="hand-lbl">${t('learn.hand')}:</span>
        ${(['both', 'left', 'right'] as const).map((h) => `<button class="hand-btn ${hand === h ? 'on' : ''}" data-hand="${h}">${t('learn.hand.' + h)}</button>`).join('')}
      </div>`}
      <div class="card"><div class="pattern" id="pattern">${renderPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu, null, hand === 'both' ? null : hand)}</div>
      ${kids ? `
        <div class="learn-kids">
          <div class="k-avatar">${Array.from({ length: 9 }, (_, i) => `<img class="k-frame ${i === kidsMood() ? 'on' : ''}" src="images/icons/kids-cat-${i}.jpg" alt=""/>`).join('')}</div>
          <div class="k-game">
            <div class="k-score">⭐ ${kidsScore}</div>
            <div class="k-sub"><b>${m.accuracy}%</b> ${t('st.accuracy')} · ${t('span.level')} ${kidsLvl + 1}</div>
          </div>
        </div>
      ` : `
        <div class="statsbar learn-stats">
          <div><b>${m.mastery}</b><span>${t('learn.mastery')}</span><i>${masteryLabel(m.mastery)}</i></div>
          <div><b>${m.tempo}</b><span>${t('learn.tempo')}</span></div>
          <div><b class="${m.rhythm >= 80 ? 'ok' : ''}">${m.rhythm}%</b><span>${t('learn.rhythm')}</span></div>
          <div><b>${m.accuracy}%</b><span>${t('st.accuracy')}</span></div>
          <div><b>${acc.lines}</b><span>${t('learn.lines')}</span></div>
        </div>
        <p class="hint2">${t('learn.tip')}</p>
      `}
    </div>`;
  (root.querySelector('#ai-exit') as HTMLButtonElement).onclick = () => learnExit();
  root.querySelectorAll<HTMLButtonElement>('[data-hand]').forEach((b) => {
    b.onclick = () => { hand = b.dataset.hand as 'both' | 'left' | 'right'; acc = blank(); nextLine(); learnRender(); };
  });
}
