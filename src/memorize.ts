// Режим «Наизусть» (запрос Дениса 13.06.2026): печать по памяти с затуханием опоры.
// Берёшь литературный отрывок (Ворон / Классика на языке интерфейса) и проходишь
// его 5 раз — с каждым проходом подсказка скрывается всё сильнее:
//   1) весь текст  2) скрыто каждое 3-е слово  3) половина  4) только первые буквы
//   5) пусто — по памяти.
// Тренирует закрепление текста через повторение (моторно + смысл). Метрика —
// recall (точность слепого прохода) + прирост скорости от 1-го прохода к финалу.
import { createState, pressChar, stats, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { recordKey, pushHistory } from './stats-store';
import { t, lang } from './i18n';
import { RAVEN, RAVEN_TITLE } from './raven';
import { CLASSIC, CLASSIC_TITLE } from './classic';
import type { Profile } from './profiles';

type Src = 'raven' | 'classic';
type LevelKey = 'full' | 'third' | 'half' | 'first' | 'blind';
const LEVELS: LevelKey[] = ['full', 'third', 'half', 'first', 'blind'];

// какие будущие буквы показывать на уровне level для слова #wi (и первая ли это буква)
function showLetter(level: LevelKey, wi: number, isFirst: boolean): boolean {
  switch (level) {
    case 'full': return true;
    case 'third': return wi % 3 !== 2;       // скрыто каждое 3-е слово
    case 'half': return wi % 2 === 0;        // скрыта половина
    case 'first': return isFirst;            // только первые буквы слов
    case 'blind': return false;              // всё по памяти
  }
}

type Screen = 'menu' | 'run' | 'between' | 'result';
let screen: Screen = 'menu';
let src: Src = 'raven';
let pieceIdx = 0;
let level = 0;                 // индекс в LEVELS
let st: TypingState = createState(['']);
let startedAt = 0;
let errs = 0;
// карты слов для текущего текста (по индексу символа в pattern)
let wordOf: number[] = [];
let firstLetter: boolean[] = [];
let isAlpha: boolean[] = [];
let passWpm: number[] = [];    // WPM каждого пройденного уровня
let prof: Profile = 'm';
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

const LENS = [5, 7, 10, 0]; // длина отрывка в словах; 0 = вся строфа. Растёт по мере успеха.
let lenIdx = ((): number => { const n = +(localStorage.getItem('tr_mem_len') ?? '0'); return n >= 0 && n < 4 ? n : 0; })();
function saveLen() { try { localStorage.setItem('tr_mem_len', String(lenIdx)); } catch { /* */ } }
function curLen(): number { return LENS[lenIdx]; }
function lenLabel(): string { return curLen() === 0 ? t('mem.len.full') : `${curLen()} ${t('mem.len.words')}`; }
let curText = '';      // выбранный отрывок (без пунктуации)
let lastRecall = 0;    // recall последнего слепого прохода (для прогрессии длины)
let lenUp = false;     // на этом отрывке длина повысилась
function L(): string { return lang(); }
function rawStanzas(): string[][] { return (src === 'raven' ? RAVEN[L()] : CLASSIC[L()]) ?? (src === 'raven' ? RAVEN.en : CLASSIC.en); }
// чистый поток слов: знаки препинания убраны (по памяти они только мешают)
function cleanWords(lines: string[]): string[] {
  const t = lines.join(' ').replace(/[-–—]/g, ' ').replace(/[^\p{L}\p{N}\s]/gu, '');
  return t.split(/\s+/).filter(Boolean);
}
// весь источник нарезан на отрывки текущей длины (curLen слов; 0 = строфа целиком)
function pieces(): string[] {
  const len = curLen();
  if (len === 0) { // вся строфа как один отрывок
    return rawStanzas().map((st) => cleanWords(st).join(' ')).filter((s) => s.split(' ').length >= 3);
  }
  const words = rawStanzas().flatMap((st) => cleanWords(st));
  const segs: string[] = [];
  for (let i = 0; i < words.length; i += len) {
    const seg = words.slice(i, i + len);
    if (seg.length >= 3) segs.push(seg.join(' ')); // хвостовой огрызок <3 слов отбрасываем
  }
  return segs;
}
function pieceTitle(): string { return (src === 'raven' ? RAVEN_TITLE[L()] : CLASSIC_TITLE[L()]) ?? ''; }

export function memorizeEnter(container: HTMLElement, profile: Profile, exit: () => void) {
  root = container; onExit = exit; prof = profile;
  screen = 'menu';
  render();
}

function buildMaps(lines: string[]) {
  const text = lines.join('\n');
  wordOf = new Array(text.length).fill(-1);
  firstLetter = new Array(text.length).fill(false);
  isAlpha = new Array(text.length).fill(false);
  let wi = -1, inWord = false;
  for (let i = 0; i < text.length; i++) {
    const a = /[\p{L}\p{N}]/u.test(text[i]);
    isAlpha[i] = a;
    if (a) {
      if (!inWord) { wi++; inWord = true; firstLetter[i] = true; }
      wordOf[i] = wi;
    } else { inWord = false; }
  }
}

function startPiece(s: Src, idx: number) {
  src = s; pieceIdx = idx; level = 0; passWpm = [];
  curText = pieces()[idx] ?? '';
  beginLevel();
}

function beginLevel() {
  const lines = [curText];
  buildMaps(lines);
  st = createState(lines);
  startedAt = 0; errs = 0;
  screen = 'run';
  render();
}

export function memorizeHandleKey(e: KeyboardEvent) {
  if (screen !== 'run' || st.finishedAt !== null) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();
  if (startedAt === 0) startedAt = Date.now();
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  const rc = /[а-яё]/i.test(st.pattern);
  const r = pressChar(st, ch, true); // блок при ошибке — иначе слепой проход не имеет смысла
  if (expected && expected !== ' ' && expected !== '\n') { const id = keyIdFor(expected, rc); if (id) recordKey(id, !r.wrong); }
  if (r.wrong) errs++;
  if (r.finished) finishLevel();
  render();
}

function finishLevel() {
  const ms = Date.now() - startedAt;
  const min = ms / 60000;
  const chars = st.pattern.replace(/\s/g, '').length;
  passWpm[level] = min > 0 ? Math.round((chars / 5) / min) : 0;
  pushHistory(passWpm[level], accNow(), Date.now());
  if (level >= LEVELS.length - 1) {
    screen = 'result';
    lastRecall = accNow();
    lenUp = false;
    // отрывок выучен на ≥85% по памяти → удлиняем (5→7→10→строфа)
    if (lastRecall >= 85 && lenIdx < LENS.length - 1) { lenIdx++; saveLen(); lenUp = true; }
  } else { screen = 'between'; }
  render();
}

function accNow(): number {
  const chars = st.pattern.replace(/\s/g, '').length;
  const total = chars + errs;
  return total > 0 ? Math.round((chars / total) * 100) : 100;
}

function nextLevel() { level++; beginLevel(); }
function startNext() {
  const list = pieces();
  if (!list.length) { screen = 'menu'; render(); return; }
  startPiece(src, (pieceIdx + 1) % list.length); // следующий отрывок (уже текущей длины)
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

// pattern с маскировкой будущих символов по текущему уровню
function renderPattern(): string {
  const lv = LEVELS[level];
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const ch = st.pattern[i];
    if (ch === '\n') { html += '<br/>'; continue; }
    const m = st.marks[i];
    if (i < st.pos) { // уже напечатано — всегда видно
      html += `<span class="${m === MARK.WRONG ? 'bad' : 'ok'}">${esc(ch)}</span>`;
    } else if (i === st.pos) { // курсор: на full виден символ, дальше — точка-плейсхолдер
      const vis = lv === 'full' || !isAlpha[i] || showLetter(lv, wordOf[i], firstLetter[i]);
      html += `<span class="cur">${vis ? esc(ch) : '·'}</span>`;
    } else { // будущее
      if (!isAlpha[i]) { html += `<span class="pend">${esc(ch)}</span>`; continue; } // пробелы/знаки — структура видна
      const vis = showLetter(lv, wordOf[i], firstLetter[i]);
      html += vis ? `<span class="pend">${esc(ch)}</span>` : `<span class="mask">·</span>`;
    }
  }
  return html;
}

function render() {
  if (!root) return;
  if (screen === 'menu') renderMenu();
  else if (screen === 'run') renderRun();
  else if (screen === 'between') renderBetween();
  else renderResult();
}

function renderMenu() {
  const list = pieces();
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="mz-exit" class="mode-back">${t('nav.back')}</button>
        <h1>🧠 ${t('mem.title')}</h1>
      </header>
      <p class="c-intro">${t('mem.intro')}</p>
      <div class="mz-tabs">
        <button class="mz-tab ${src === 'raven' ? 'on' : ''}" data-src="raven">📜 ${RAVEN_TITLE[L()] ?? 'The Raven'}</button>
        <button class="mz-tab ${src === 'classic' ? 'on' : ''}" data-src="classic">${t('bank.classic')}</button>
      </div>
      <div class="mz-len">📏 ${t('mem.len.label')}: <b>${esc(lenLabel())}</b></div>
      <div class="cp-grid">
        ${list.slice(0, 12).map((seg, i) => `<button class="cp-disc" data-i="${i}">
          <span class="cp-name">${esc(pieceTitle())} — ${i + 1}</span>
          <span class="cp-best">${esc(seg)}</span>
        </button>`).join('')}
      </div>
    </div>`;
  root!.querySelectorAll<HTMLButtonElement>('[data-src]').forEach((b) => { b.onclick = () => { src = b.dataset.src as Src; render(); }; });
  root!.querySelectorAll<HTMLButtonElement>('[data-i]').forEach((b) => { b.onclick = () => startPiece(src, +b.dataset.i!); });
  (root!.querySelector('#mz-exit') as HTMLButtonElement).onclick = () => onExit?.();
}

function renderRun() {
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  const lv = LEVELS[level];
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="mz-back" class="mode-back">${t('nav.tomap')}</button>
        <span class="c-progress">🧠 ${t('mem.pass')} ${level + 1}/${LEVELS.length}</span>
        <span class="c-acc">${t('mem.lvl.' + lv)}</span>
      </header>
      <div class="mz-bar">${LEVELS.map((_, i) => `<span class="mz-dot ${i < level ? 'done' : i === level ? 'cur' : ''}"></span>`).join('')}</div>
      <div class="card"><div class="pattern pattern-big" id="pattern">${renderPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
    </div>`;
  (root!.querySelector('#mz-back') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
}

function renderBetween() {
  root!.innerHTML = `
    <div class="wrap compete">
      <div class="cp-result">
        <div class="cp-medal">✅</div>
        <h2>${t('mem.pass')} ${level + 1}/${LEVELS.length}</h2>
        <div class="statsbar">
          <div><b>${passWpm[level] ?? 0}</b><span>${t('st.wpm')}</span></div>
          <div><b>${accNow()}%</b><span>${t('st.accuracy')}</span></div>
        </div>
        <p class="c-intro">${t('mem.next.hint')} <b>${t('mem.lvl.' + LEVELS[level + 1])}</b></p>
        <div class="donebtns">
          <button id="mz-next" class="primary">${t('mem.next')} →</button>
          <button id="mz-menu" class="ghost">${t('k.map')}</button>
        </div>
      </div>
    </div>`;
  (root!.querySelector('#mz-next') as HTMLButtonElement).onclick = () => nextLevel();
  (root!.querySelector('#mz-menu') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
}

function renderResult() {
  const blind = passWpm[LEVELS.length - 1] ?? 0;
  const full = passWpm[0] ?? 0;
  const recall = accNow();
  const medal = recall === 100 ? '🥇' : recall >= 90 ? '🥈' : recall >= 75 ? '🥉' : '🎖';
  const gain = full > 0 ? Math.round((blind / full) * 100) : 0;
  void prof; void stats;
  root!.innerHTML = `
    <div class="wrap compete">
      <div class="cp-result">
        <div class="cp-medal">${medal}</div>
        <h2>🧠 ${esc(pieceTitle())} — ${pieceIdx + 1}</h2>
        <div class="cp-record">${lenUp ? `🔼 ${t('mem.lenup')} <b>${esc(lenLabel())}</b>` : t('mem.done')}</div>
        <div class="statsbar">
          <div><b>${recall}%</b><span>${t('mem.recall')}</span></div>
          <div><b>${blind}</b><span>${t('mem.blind.wpm')}</span></div>
          <div><b>${gain}%</b><span>${t('mem.gain')}</span></div>
        </div>
        <p class="c-intro">${t('mem.gain.hint')}</p>
        <div class="donebtns">
          <button id="mz-again">${t('k.again')}</button>
          <button id="mz-menu" class="ghost">${t('k.map')}</button>
        </div>
      </div>
    </div>`;
  (root!.querySelector('#mz-again') as HTMLButtonElement).onclick = () => startNext();
  (root!.querySelector('#mz-menu') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
}
