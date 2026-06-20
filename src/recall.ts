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

type Screen = 'menu' | 'play' | 'result';
let screen: Screen = 'menu';
let revealMode = false;   // true — фаза показа слов, false — печать по памяти (один экран, без дёрганья)
function levelNo(n = span): number { return n - MIN_SPAN + 1; }
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
  st = createState([words]);   // состояние создаём сразу — слова появятся в самом поле ввода
  errs = 0; startedAt = 0;
  revealMode = true;
  screen = 'play';
  render();
  // авто-скрытие ~1.2 c на слово (плюс кнопка «Запомнил»)
  timer = window.setTimeout(toType, Math.max(2500, span * 1200));
}

function toType() {
  clearTimer();
  revealMode = false;
  startedAt = 0;
  render();   // ТОТ ЖЕ экран — только слова гаснут (буквы → ·), без смены окна
}

export function recallHandleKey(e: KeyboardEvent) {
  if (screen === 'result') {   // на результате — Enter/пробел сразу следующий раунд
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); startRound(); }
    return;
  }
  if (screen !== 'play' || revealMode || st.finishedAt !== null) return;
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

// reveal — слова видны (запоминаешь); type — будущие буквы скрыты (печать по памяти).
// И то и другое в ОДНОМ поле, поэтому переход без смены окна.
function renderPlayPattern(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const ch = st.pattern[i];
    if (revealMode) { html += ch === ' ' ? '<span class="pend"> </span>' : `<span class="reveal">${esc(ch)}</span>`; continue; }
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
  else if (screen === 'play') renderPlay();
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

// Единый экран: показ слов и печать по памяти — одно поле, клавиатура всегда на месте.
function renderPlay() {
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  const showMs = Math.max(2500, span * 1200);
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="sp-back" class="mode-back">${t('nav.back')}</button>
        <span class="c-progress">🧩 ${t('span.level')} ${levelNo()}</span>
        <span class="c-acc">${span} ${t('span.words')} · ★${levelNo(bestSpan)}</span>
      </header>
      <div class="sp-phase ${revealMode ? 'reveal' : 'type'}">
        ${revealMode
          ? `<span class="sp-tag">👀 ${t('span.show')}</span><div class="sp-timer"><i style="animation-duration:${showMs}ms"></i></div>`
          : `<span class="sp-tag">⌨️ ${t('span.recall')}</span>`}
      </div>
      <div class="card"><div class="pattern pattern-big" id="pattern">${renderPlayPattern()}</div></div>
      <div class="keyb">${keyboardSVG(!revealMode && st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
      ${revealMode ? `<div class="donebtns"><button id="sp-ready" class="primary">${t('span.ready')} →</button></div>` : ''}
    </div>`;
  (root!.querySelector('#sp-back') as HTMLButtonElement).onclick = () => { clearTimer(); screen = 'menu'; render(); };
  const rb = root!.querySelector('#sp-ready') as HTMLButtonElement | null;
  if (rb) rb.onclick = () => toType();
}

function renderResult() {
  const stars = lastRecall === 100 ? 3 : lastRecall >= 90 ? 2 : lastRecall >= 70 ? 1 : 0;
  void prof;
  root!.innerHTML = `
    <div class="wrap compete">
      <div class="cp-result">
        <div class="sp-stars">${'★'.repeat(stars)}${'☆'.repeat(3 - stars)}</div>
        <h2>🧩 ${t('span.level')} ${levelNo()}</h2>
        <div class="cp-record">${lastUp ? t('span.up') : t('span.down')}</div>
        <div class="statsbar">
          <div><b>${lastRecall}%</b><span>${t('mem.recall')}</span></div>
          <div><b>${levelNo()}</b><span>${t('span.level')}</span></div>
          <div><b>${levelNo(bestSpan)}</b><span>${t('span.best')}</span></div>
        </div>
        <div class="donebtns">
          <button id="sp-next" class="primary">${t('span.next')} →</button>
          <button id="sp-menu" class="ghost">${t('k.map')}</button>
        </div>
        <p class="k-autonext">${t('k.autonext')}</p>
      </div>
    </div>`;
  (root!.querySelector('#sp-next') as HTMLButtonElement).onclick = () => { clearTimer(); startRound(); };
  (root!.querySelector('#sp-menu') as HTMLButtonElement).onclick = () => { clearTimer(); screen = 'menu'; render(); };
  clearTimer();
  timer = window.setTimeout(startRound, 3500);   // игровой поток: следующий раунд сам через 3.5 с
}
