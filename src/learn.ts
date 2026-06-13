// AI-режим обучения (запрос Дениса 13.06.2026) — VerseQ-подобный «умный» режим:
// бесконечный поток фонетически связных строк (n-граммы), адаптивно
// подмешивающих слабые буквы пользователя, с метриками Мастерство / Ритмичность
// / Темп. Адаптируется под профиль (м/ж/дети). Прогресс/статистика — общие.
import { createState, pressChar, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor, handLetters } from './keyboard';
import { recordKey, pushHistory, letterWeights } from './stats-store';
import { buildModel, generate, type NgramModel } from './ngram';
import { CORPUS } from './corpus';
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

function genLine(): string {
  const L = lang();              // корпус — по языку интерфейса (7 языков)
  const KL = kbLang();           // алфавит клавиш — ru или латиница
  const chars = prof === 'kids' ? 24 : prof === 'f' ? 40 : 50;
  const maxWord = prof === 'kids' ? 5 : 8;
  if (hand === 'both') {
    ensureModel(L);
    return generate(model!, { chars, weight: letterWeights(KL), maxWord });
  }
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
  st = createState([genLine()]);
  lineStart = 0; lastStroke = 0;
}

export function learnEnter(container: HTMLElement, profile: Profile, exit: () => void) {
  root = container; onExit = exit; prof = profile;
  acc = blank();
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

  if (r.finished) {
    acc.ms += now - lineStart;
    acc.lines++;
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
        <div class="learn-kids"><span class="k-cat">😺</span> <b>${m.accuracy}%</b> ${t('st.accuracy')} · ${acc.lines} ${t('learn.lines')}</div>
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
