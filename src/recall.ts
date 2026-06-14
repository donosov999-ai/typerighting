// Режим «Память» (вариант A, запрос Дениса 13.06.2026): тренировка рабочей памяти.
// Показывается список из N случайных слов языка → исчезает → набираешь по памяти.
// Справился (recall ≥ 90%) — слов становится больше (span растёт), ошибся — меньше.
// Метрика: достигнутый span (объём рабочей памяти) + личный рекорд.
import { createState, pressChar, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { recordKey, pushHistory } from './stats-store';
import { t, lang } from './i18n';
import { CORPUS } from './corpus';
import type { Profile } from './profiles';

const MIN_SPAN = 3, MAX_SPAN = 9;
let span = 3;
let bestSpan = ((): number => { const n = +(localStorage.getItem('tr_span_best') ?? '3'); return n >= 3 ? n : 3; })();
function saveBest() { try { localStorage.setItem('tr_span_best', String(bestSpan)); } catch { /* */ } }

const rnd = (n: number) => Math.floor(Math.random() * n);

// пул слов языка: уникальные, длиной 3–7 букв, из корпуса
function wordPool(L: string): string[] {
  const corpus = CORPUS[L] ?? CORPUS.en;
  const set = new Set<string>();
  for (const w of corpus.toLowerCase().split(/[^\p{L}]+/u)) {
    if (w.length >= 3 && w.length <= 7) set.add(w);
  }
  return [...set];
}
function pickWords(n: number): string {
  const pool = wordPool(lang());
  const out: string[] = [];
  let guard = 0;
  while (out.length < n && guard++ < n * 20) {
    const w = pool[rnd(pool.length)];
    if (w && !out.includes(w)) out.push(w); // без повторов в одном списке
  }
  return out.join(' ');
}

type Screen = 'menu' | 'show' | 'recall' | 'result';
let screen: Screen = 'menu';
let words = '';
let st: TypingState = createState(['']);
let errs = 0;
let startedAt = 0;
let timer: number | null = null;
let lastRecall = 0;
let lastUp = false;
let prof: Profile = 'm';
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

function clearTimer() { if (timer) { clearTimeout(timer); timer = null; } }

export function recallEnter(container: HTMLElement, profile: Profile, exit: () => void) {
  root = container; onExit = exit; prof = profile;
  clearTimer(); screen = 'menu';
  render();
}

function startRound() {
  clearTimer();
  words = pickWords(span);
  screen = 'show';
  render();
  // авто-переход к набору: ~1.2 c на слово (плюс есть кнопка «Запомнил»)
  timer = window.setTimeout(toRecall, Math.max(2500, span * 1200));
}

function toRecall() {
  clearTimer();
  st = createState([words]);
  errs = 0; startedAt = 0;
  screen = 'recall';
  render();
}

export function recallHandleKey(e: KeyboardEvent) {
  if (screen !== 'recall' || st.finishedAt !== null) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; }
  let ch: string | null = null;
  if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();
  if (startedAt === 0) startedAt = Date.now();
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  const rc = /[а-яё]/i.test(st.pattern);
  const r = pressChar(st, ch, true); // блок при ошибке
  if (expected && expected !== ' ') { const id = keyIdFor(expected, rc); if (id) recordKey(id, !r.wrong); }
  if (r.wrong) errs++;
  if (r.finished) finishRound();
  render();
}

function accNow(): number {
  const chars = st.pattern.replace(/\s/g, '').length;
  const total = chars + errs;
  return total > 0 ? Math.round((chars / total) * 100) : 100;
}

function finishRound() {
  lastRecall = accNow();
  const min = (Date.now() - startedAt) / 60000;
  const wpm = min > 0 ? Math.round((st.pattern.replace(/\s/g, '').length / 5) / min) : 0;
  pushHistory(wpm, lastRecall, Date.now());
  if (lastRecall >= 90 && span < MAX_SPAN) { span++; lastUp = true; if (span > bestSpan) { bestSpan = span; saveBest(); } }
  else if (lastRecall < 90 && span > MIN_SPAN) { span--; lastUp = false; }
  else lastUp = lastRecall >= 90;
  screen = 'result';
  render();
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

// в фазе recall будущие буквы скрыты (печать по памяти), напечатанное — видно
function renderRecallPattern(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const ch = st.pattern[i];
    const m = st.marks[i];
    if (i < st.pos) html += `<span class="${m === MARK.WRONG ? 'bad' : 'ok'}">${esc(ch)}</span>`;
    else if (ch === ' ') html += '<span class="pend"> </span>';
    else if (i === st.pos) html += '<span class="cur">·</span>';
    else html += '<span class="mask">·</span>';
  }
  return html;
}

function render() {
  if (!root) return;
  if (screen === 'menu') renderMenu();
  else if (screen === 'show') renderShow();
  else if (screen === 'recall') renderRecall();
  else renderResult();
}

function renderMenu() {
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="sp-exit" class="mode-back">${t('nav.back')}</button>
        <h1>🧩 ${t('span.title')}</h1>
      </header>
      <p class="c-intro">${t('span.intro')}</p>
      <div class="cp-result">
        <div class="cp-medal">🧩</div>
        <div class="statsbar">
          <div><b>${span}</b><span>${t('span.words')}</span></div>
          <div><b>${bestSpan}</b><span>${t('span.best')}</span></div>
        </div>
        <div class="donebtns"><button id="sp-start" class="primary">${t('span.start')}</button></div>
      </div>
    </div>`;
  (root!.querySelector('#sp-exit') as HTMLButtonElement).onclick = () => { clearTimer(); onExit?.(); };
  (root!.querySelector('#sp-start') as HTMLButtonElement).onclick = () => startRound();
}

function renderShow() {
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="sp-back" class="mode-back">${t('nav.back')}</button>
        <span class="c-progress">🧩 ${t('span.show')}</span>
        <span class="c-acc">${span} ${t('span.words')}</span>
      </header>
      <div class="card"><div class="span-words">${esc(words)}</div></div>
      <div class="donebtns"><button id="sp-ready" class="primary">${t('span.ready')} →</button></div>
    </div>`;
  (root!.querySelector('#sp-back') as HTMLButtonElement).onclick = () => { clearTimer(); screen = 'menu'; render(); };
  (root!.querySelector('#sp-ready') as HTMLButtonElement).onclick = () => toRecall();
}

function renderRecall() {
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="sp-back" class="mode-back">${t('nav.back')}</button>
        <span class="c-progress">🧩 ${t('span.recall')}</span>
        <span class="c-acc">${span} ${t('span.words')}</span>
      </header>
      <div class="card"><div class="pattern pattern-big" id="pattern">${renderRecallPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
    </div>`;
  (root!.querySelector('#sp-back') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
}

function renderResult() {
  const medal = lastRecall === 100 ? '🥇' : lastRecall >= 90 ? '🥈' : lastRecall >= 70 ? '🥉' : '🎖';
  void prof;
  root!.innerHTML = `
    <div class="wrap compete">
      <div class="cp-result">
        <div class="cp-medal">${medal}</div>
        <h2>🧩 ${t('span.title')}</h2>
        <div class="cp-record">${lastUp ? t('span.up') : t('span.down')}</div>
        <div class="statsbar">
          <div><b>${lastRecall}%</b><span>${t('mem.recall')}</span></div>
          <div><b>${span}</b><span>${t('span.words')}</span></div>
          <div><b>${bestSpan}</b><span>${t('span.best')}</span></div>
        </div>
        <div class="donebtns">
          <button id="sp-next" class="primary">${t('span.next')} →</button>
          <button id="sp-menu" class="ghost">${t('k.map')}</button>
        </div>
      </div>
    </div>`;
  (root!.querySelector('#sp-next') as HTMLButtonElement).onclick = () => startRound();
  (root!.querySelector('#sp-menu') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
}
