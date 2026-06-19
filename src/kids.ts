// Детский игровой режим (этап 3 плана трёх версий, согласован 12.06.2026).
// Принципы: точность > скорость (зн/мин не показываем), короткие слова,
// уровни со звёздами 1–3, котик-маскот, клавиатура всегда на экране,
// мягкая пауза после 3 уровней подряд. Прогресс: localStorage `tr_kids`.
import { createState, pressChar, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar } from './keyboard';
import { t, lang } from './i18n';

// ── Банк слов (3–5 букв, проверено тестом длины/дублей) ──
const RU3 = ['кот', 'дом', 'сок', 'лес', 'мяч', 'сыр', 'нос', 'рот', 'лук', 'мак', 'жук', 'дым', 'сон', 'мир', 'кит'];
const RU4 = ['мама', 'папа', 'каша', 'зима', 'лето', 'луна', 'небо', 'море', 'гора', 'рыба', 'окно', 'сова', 'лиса', 'волк', 'утка'];
const RU5 = ['весна', 'осень', 'школа', 'книга', 'песня', 'чашка', 'ложка', 'мышка', 'кошка', 'зебра', 'лампа', 'шапка', 'санки', 'горка', 'речка'];
// EN-банк расширен до 40 слов на длину (рынок EN-школьников): 8 уровней на длину
const EN3 = ['cat', 'dog', 'sun', 'box', 'red', 'run', 'mom', 'dad', 'egg', 'ice',
  'car', 'bus', 'fox', 'bee', 'owl', 'hat', 'pen', 'map', 'cup', 'jam',
  'sea', 'sky', 'toy', 'zoo', 'kid', 'leg', 'arm', 'eye', 'ear', 'nut',
  'pig', 'hen', 'cow', 'ant', 'bat', 'big', 'hot', 'wet', 'six', 'ten'];
const EN4 = ['ball', 'fish', 'bird', 'cake', 'milk', 'tree', 'star', 'moon', 'rain', 'snow',
  'frog', 'duck', 'bear', 'lion', 'wolf', 'book', 'game', 'blue', 'pink', 'rose',
  'door', 'desk', 'lamp', 'sofa', 'kite', 'ship', 'road', 'park', 'hand', 'foot',
  'nose', 'face', 'hair', 'king', 'gold', 'fast', 'slow', 'warm', 'cold', 'five'];
const EN5 = ['apple', 'house', 'smile', 'happy', 'water', 'bread', 'candy', 'tiger', 'mouse', 'horse',
  'sheep', 'green', 'white', 'black', 'music', 'table', 'chair', 'plant', 'grass', 'cloud',
  'river', 'beach', 'stone', 'train', 'plane', 'pizza', 'juice', 'sugar', 'lemon', 'mango',
  'zebra', 'panda', 'koala', 'eagle', 'shark', 'dance', 'sleep', 'dream', 'light', 'seven'];

interface KidsLevel { id: number; lang: 'ru' | 'en'; title: string; words: string[] }

function slice5(arr: string[], part: number): string[] { return arr.slice(part * 5, part * 5 + 5); }

export const KIDS_LEVELS: KidsLevel[] = [];
{
  let id = 1;
  const blocks: Array<[string[], 'ru' | 'en']> = [[RU3, 'ru'], [RU4, 'ru'], [RU5, 'ru'], [EN3, 'en'], [EN4, 'en'], [EN5, 'en']];
  for (const [bank, blockLang] of blocks) {
    for (let part = 0; part * 5 < bank.length; part++) {
      KIDS_LEVELS.push({ id, lang: blockLang, title: String(id), words: slice5(bank, part) });
      id++;
    }
  }
}

// ── Прогресс ──
interface KidsProgress { stars: Record<number, number> }
let prog: KidsProgress = { stars: {} };
function loadProg() {
  try {
    const p = JSON.parse(localStorage.getItem('tr_kids') ?? '');
    if (p && p.stars) prog = p;
  } catch { /* первый запуск */ }
}
function saveProg() { try { localStorage.setItem('tr_kids', JSON.stringify(prog)); } catch { /* quota */ } }
function unlocked(id: number): boolean { return id === 1 || (prog.stars[id - 1] ?? 0) > 0; }

// ── Состояние сессии режима ──
type Screen = 'map' | 'level' | 'done';
let screen: Screen = 'map';
let level: KidsLevel | null = null;
let wordIdx = 0;
let st: TypingState = createState(['']);
let levelErrors = 0;
let levelChars = 0;
let lastStars = 0;
let playedThisSession = 0; // для мягкого «передохни» после 3 уровней
let mascotSay = '';
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

const PRAISE_L: Record<string, string[]> = {
  ru: ['Молодец!', 'Здорово!', 'Так держать!', 'Ты супер!', 'Отлично!', 'Вот это да!'],
  en: ['Well done!', 'Great!', 'Keep it up!', 'You rock!', 'Awesome!', 'Wow!'],
};
const OOPS_L: Record<string, string[]> = {
  ru: ['Ой! Попробуй ещё', 'Чуть-чуть мимо', 'Не спеши', 'Почти попал!'],
  en: ['Oops! Try again', 'Almost!', 'Take your time', 'So close!'],
};
const PRAISE = () => PRAISE_L[lang()];
const OOPS = () => OOPS_L[lang()];
const pick = (a: string[]) => a[Math.floor(Math.random() * a.length)];

// ── Звук (Web Audio, весёлый) ──
let ctx: AudioContext | null = null;
function tone(freq: number, at: number, dur: number, gain = 0.07) {
  if (!ctx) return;
  const o = ctx.createOscillator(); const g = ctx.createGain();
  o.type = 'triangle'; o.frequency.value = freq;
  g.gain.setValueAtTime(gain, ctx.currentTime + at);
  g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + at + dur);
  o.connect(g); g.connect(ctx.destination);
  o.start(ctx.currentTime + at); o.stop(ctx.currentTime + at + dur + 0.02);
}
function sndWord() { try { ctx ??= new AudioContext(); [523.25, 659.25, 783.99].forEach((f, i) => tone(f, i * 0.09, 0.18)); } catch { /* no audio */ } }
function sndLevel() { try { ctx ??= new AudioContext(); [523.25, 587.33, 659.25, 783.99, 1046.5].forEach((f, i) => tone(f, i * 0.11, 0.22, 0.08)); } catch { /* no audio */ } }
function sndOops() { try { ctx ??= new AudioContext(); tone(196, 0, 0.12, 0.05); } catch { /* no audio */ } }

// ── API для main.ts ──
let onAI: (() => void) | null = null;
export function kidsEnter(container: HTMLElement, exitToProfile: () => void, aiCb?: () => void) {
  root = container; onExit = exitToProfile; onAI = aiCb ?? null;
  loadProg();
  screen = 'map';
  kidsRender();
}

export function kidsHandleKey(e: KeyboardEvent): void {
  if (screen !== 'level' || !level || st.finishedAt !== null) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; } // блок всегда вкл
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();

  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected); // раскладка ОС не мешает ребёнку
  const r = pressChar(st, ch, true);
  if (r.wrong) { levelErrors++; mascotSay = pick(OOPS()); sndOops(); }
  if (r.finished) {
    levelChars += st.pattern.length;
    mascotSay = pick(PRAISE());
    if (wordIdx + 1 < level.words.length) {
      sndWord();
      wordIdx++;
      st = createState([level.words[wordIdx]]);
    } else {
      finishLevel();
    }
  }
  kidsRender();
}

function finishLevel() {
  if (!level) return;
  sndLevel();
  lastStars = levelErrors === 0 ? 3 : (1 - levelErrors / Math.max(levelChars, 1)) >= 0.9 ? 2 : 1;
  if (lastStars > (prog.stars[level.id] ?? 0)) { prog.stars[level.id] = lastStars; saveProg(); }
  playedThisSession++;
  screen = 'done';
}

function startLevel(l: KidsLevel) {
  level = l; wordIdx = 0; levelErrors = 0; levelChars = 0;
  mascotSay = l.lang === 'ru' ? t('k.startRu') : t('k.startEn');
  st = createState([l.words[0]]);
  screen = 'level';
  kidsRender();
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

function starsStr(n: number): string { return n > 0 ? '⭐'.repeat(n) : ''; }

function kidsRender() {
  if (!root) return;
  if (screen === 'map') renderMap();
  else if (screen === 'level') renderLevel();
  else renderDone();
}

function renderMap() {
  const blocks = [
    { lang: 'ru' as const, title: t('k.block.ru'), levels: KIDS_LEVELS.filter((l) => l.lang === 'ru') },
    { lang: 'en' as const, title: t('k.block.en'), levels: KIDS_LEVELS.filter((l) => l.lang === 'en') },
  ];
  const rest = playedThisSession > 0 && playedThisSession % 3 === 0
    ? `<div class="k-rest">${t('k.rest')}</div>` : '';
  root!.innerHTML = `
    <div class="wrap kids">
      <header class="mode-head">
        <button id="k-exit" class="mode-back">${t('nav.back')}</button>
        <h1>${t('k.title')}</h1>
        <div class="mode-actions">${onAI ? `<button id="k-ai" class="ghost">${t('learn.title')} 🤖</button>` : ''}</div>
      </header>
      <p class="k-hello">${t('k.hello')}</p>
      ${rest}
      ${blocks.map((b) => `
        <h2 class="k-block">${b.title}</h2>
        <div class="k-map">
          ${b.levels.map((l) => {
            const open = unlocked(l.id);
            const s = prog.stars[l.id] ?? 0;
            return `<button class="k-lvl ${open ? 'open' : 'locked'} ${s > 0 ? 'passed' : ''}" data-level="${l.id}" ${open ? '' : 'disabled'}>
              <span class="k-num">${open ? l.id : '🔒'}</span>
              <span class="k-stars">${starsStr(s)}</span>
            </button>`;
          }).join('')}
        </div>`).join('')}
    </div>`;
  root!.querySelectorAll<HTMLButtonElement>('[data-level]').forEach((b) => {
    b.onclick = () => { const l = KIDS_LEVELS.find((x) => x.id === Number(b.dataset.level)); if (l) startLevel(l); };
  });
  (root!.querySelector('#k-exit') as HTMLButtonElement).onclick = () => onExit?.();
  const aiBtn = root!.querySelector('#k-ai') as HTMLButtonElement | null;
  if (aiBtn) aiBtn.onclick = () => onAI?.();
}

function renderWord(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    html += `<span class="${cls}">${esc(st.pattern[i])}</span>`;
  }
  return html;
}

function renderLevel() {
  const l = level!;
  const nextCh = st.finishedAt === null ? st.pattern[st.pos] ?? null : null;
  const showRu = lang() === 'ru' || l.lang === 'ru';
  root!.innerHTML = `
    <div class="wrap kids">
      <header class="mode-head">
        <button id="k-back" class="mode-back">${t('nav.tomap')}</button>
        <span class="k-progress">${t('k.level')} ${l.title} · ${t('k.word')} ${wordIdx + 1} / ${l.words.length}</span>
        <span class="k-acc">${levelErrors === 0 ? t('k.noerr') : `${t('k.errors')}: ${levelErrors}`}</span>
      </header>
      <div class="k-mascot"><img class="k-cat-img${levelErrors > 0 && mascotSay && OOPS().includes(mascotSay) ? ' oops' : ''}" src="images/mascot.jpg" alt=""/> <span class="k-say">${esc(mascotSay)}</span></div>
      <div class="k-word">${renderWord()}</div>
      <div class="keyb">${keyboardSVG(nextCh, l.lang === 'ru', showRu)}</div>
    </div>`;
  (root!.querySelector('#k-back') as HTMLButtonElement).onclick = () => { screen = 'map'; kidsRender(); };
}

function renderDone() {
  const l = level!;
  root!.innerHTML = `
    <div class="wrap kids">
      <div class="k-done">
        <div class="k-cat-big"><img src="images/mascot.jpg" alt="" class="k-mascot-img"/></div>
        <h2>${t('k.level')} ${l.title} ${t('k.passed')}</h2>
        <div class="k-stars-big">${'⭐'.repeat(lastStars)}${'☆'.repeat(3 - lastStars)}</div>
        <p class="k-done-note">${lastStars === 3 ? t('k.note3') : lastStars === 2 ? t('k.note2') : t('k.note1')}</p>
        <div class="donebtns">
          <button id="k-again">${t('k.again')}</button>
          <button id="k-map2" class="ghost">${t('k.map')}</button>
          ${KIDS_LEVELS.find((x) => x.id === l.id + 1) ? `<button id="k-next" class="primary">${t('k.next')}</button>` : ''}
        </div>
      </div>
    </div>`;
  (root!.querySelector('#k-again') as HTMLButtonElement).onclick = () => startLevel(l);
  (root!.querySelector('#k-map2') as HTMLButtonElement).onclick = () => { screen = 'map'; kidsRender(); };
  const nx = root!.querySelector('#k-next') as HTMLButtonElement | null;
  if (nx) nx.onclick = () => { const n = KIDS_LEVELS.find((x) => x.id === l.id + 1); if (n) startLevel(n); };
}
