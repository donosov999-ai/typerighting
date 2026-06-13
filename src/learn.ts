// AI-режим обучения (запрос Дениса 13.06.2026) — VerseQ-подобный «умный» режим:
// бесконечный поток фонетически связных строк (n-граммы), адаптивно
// подмешивающих слабые буквы пользователя, с метриками Мастерство / Ритмичность
// / Темп. Адаптируется под профиль (м/ж/дети). Прогресс/статистика — общие.
import { createState, pressChar, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { recordKey, pushHistory, letterWeights } from './stats-store';
import { buildModel, generate, type NgramModel } from './ngram';
import { CORPUS_RU, CORPUS_EN } from './corpus';
import { t, lang } from './i18n';
import type { Profile } from './profiles';

let model: NgramModel | null = null;
let modelLang: 'en' | 'ru' | null = null;
function ensureModel(L: 'en' | 'ru') {
  if (model && modelLang === L) return;
  model = buildModel(L === 'ru' ? CORPUS_RU : CORPUS_EN, L, 3);
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
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

function curLang(): 'en' | 'ru' { return lang() === 'ru' ? 'ru' : 'en'; }

function genLine(): string {
  const L = curLang();
  ensureModel(L);
  const chars = prof === 'kids' ? 24 : prof === 'f' ? 40 : 50;
  const maxWord = prof === 'kids' ? 5 : 8;
  return generate(model!, { chars, weight: letterWeights(L), maxWord });
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
      <header class="c-head">
        <h1>🤖 ${t('learn.title')}</h1>
        <button id="ai-exit" class="ghost">${t('course.exit')}</button>
      </header>
      <p class="c-intro">${kids ? t('learn.intro.kids') : t('learn.intro')}</p>
      <div class="card"><div class="pattern" id="pattern">${renderPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
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
}
