// Структурированный курс (запрос Дениса 13.06.2026): последовательные уроки
// от домашнего ряда до предложений, каждый открывает следующий — как в
// typing.com / Mavis Beacon. Для взрослых профилей (m/f). Собирает per-key
// статистику и историю. Прогресс: localStorage tr_course_<lang>.
import { createState, pressChar, stats, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { recordKey, pushHistory } from './stats-store';
import { t, lang, type Lang } from './i18n';

type Kind = 'keys' | 'home' | 'caps' | 'digits' | 'punct' | 'words' | 'sentences';
interface Lesson { id: number; kind: Kind; newKeys: string; pool: string; titleKey: string; titleArg?: string }

// ── Программа: последовательность групп клавиш (накопительно) ──
// Латинские языки (en/es/de/fr/it/pt) — одна QWERTY-прогрессия (наша схема).
const PLAN_EN = ['fj', 'dk', 'sl', 'a', 'ei', 'gh', 'ru', 'ty', 'wo', 'qp', 'vn', 'zxcb', 'm'];
const PLAN_RU = ['ао', 'вл', 'ыд', 'фж', 'пр', 'ен', 'кг', 'уш', 'цщ', 'йз', 'яч', 'смит', 'ьбюхэъ'];
function planFor(L: Lang): string[] { return L === 'ru' ? PLAN_RU : PLAN_EN; }

// частые слова каждого языка (ASCII — печатается на нашей раскладке)
const REAL_WORDS: Record<string, string> = {
  en: 'the and you that was for are with his they have this from word what time work first water been call who now find long down day did get come made may part over new sound take only little place year live back give most very after thing our just name good through',
  ru: 'и в не на что тот быть это как она для его так вот мочь сказать год этот рука дело глаз жизнь день есть знать самый раз время слово место друг два дом стать первый вода идти большой ещё свой',
  es: 'el la de que y a en un ser se no haber por con su para como estar tener le lo todo pero mas hacer poder decir este ir otro ese si ya ver cuando muy sin vez mucho saber dia vida casa',
  de: 'der die und in den von zu das mit sich des auf fuer ist im dem nicht ein eine als auch werden aus hat dass sie nach wird bei einer um am sind noch wie einem ueber so zum war haben',
  fr: 'le de un etre et a il avoir ne je son que se qui ce dans en du elle pour pas vous par sur faire plus dire on mon lui nous comme mais pouvoir avec tout aller voir bien jour vie',
  it: 'di che la il un per in non una mi sono ho ma se ci lo come piu questo qui hai cosa noi da bene mai solo fare quando lei tutto ora vita casa anno cosi dopo essere senza primo',
  pt: 'de que do da em para com nao uma para os no se na por mais foi ele tem seu sua ou ser quando muito ja esta eu tambem pelo ate vida casa dia tempo ano coisa fazer ver bem',
};
const SENTENCES: Record<string, string[]> = {
  en: ['The quick brown fox jumps over the lazy dog.', 'Pack my box with five dozen liquor jugs.', 'How vexingly quick daft zebras jump.', 'The five boxing wizards jump quickly.', 'Sphinx of black quartz, judge my vow.'],
  ru: ['Съешь же ещё этих мягких французских булок да выпей чаю.', 'В чащах юга жил бы цитрус? Да, но фальшивый экземпляр!', 'Широкая электрификация южных губерний даст мощный толчок.', 'Эх, чужак, общий съём цен шляп юфти вдрызг!', 'Любя, съешь щипцы, — вздохнёт мэр, — кайф жгуч.'],
  es: ['El veloz murcielago comia feliz kiwi y cardo en el jardin.', 'La vida es sueno y los suenos suenos son.', 'Quien mucho abarca poco aprieta dijo el sabio anciano.', 'Cada dia tomamos cafe con pan antes de salir a trabajar.', 'Mas vale tarde que nunca por eso ten calma y paciencia.'],
  de: ['Franz jagt im total verwahrlosten taxi quer durch bayern.', 'Zwei boxkaempfer jagen eva quer durch sylt am morgen.', 'Uebung macht den meister also tippe jeden tag ein wenig.', 'Das wasser fliesst vom berg durch graue steine zum see.', 'Kleine schritte fuehren mit der zeit zu grossen zielen.'],
  fr: ['Portez ce vieux whisky au juge blond qui fume sa pipe.', 'Le coeur decu mais l ame plutot naive choisit la paix.', 'Chaque matin nous prenons un cafe avant de travailler.', 'C est en forgeant que l on devient forgeron mon ami.', 'Petit a petit l oiseau fait son nid avec patience.'],
  it: ['Ma la volpe col suo balzo ha raggiunto il quieto fido.', 'Quel vituperabile xenofobo zelante assagia il whisky.', 'La pratica rende perfetti quindi scrivi ogni giorno.', 'Chi va piano va sano e va lontano dice il proverbio.', 'L acqua del fiume scende dalla montagna verso il lago.'],
  pt: ['Um pequeno jabuti xereta viu dez cegonhas felizes.', 'A rapida raposa marrom salta sobre o cao preguicoso.', 'A pratica leva a perfeicao por isso escreve cada dia.', 'Devagar se vai ao longe diz o velho ditado popular.', 'As estrelas brilham sobre a floresta silenciosa a noite.'],
};

function buildLessons(L: Lang): Lesson[] {
  const out: Lesson[] = [];
  let id = 1;
  let acc = '';
  const plan = planFor(L);
  const reviewMark = L === 'ru' ? 'фж' : 'a';
  plan.forEach((grp, i) => {
    acc += grp;
    if (i === 0) { out.push({ id: id++, kind: 'home', newKeys: grp, pool: grp, titleKey: 'course.home' }); return; }
    out.push({ id: id++, kind: 'keys', newKeys: grp, pool: acc, titleKey: 'course.keys', titleArg: grp.toUpperCase().split('').join(' ') });
    if (grp === reviewMark) out.push({ id: id++, kind: 'home', newKeys: '', pool: acc, titleKey: 'course.review' });
  });
  const allLetters = acc;
  out.push({ id: id++, kind: 'caps', newKeys: '', pool: allLetters, titleKey: 'course.caps' });
  out.push({ id: id++, kind: 'digits', newKeys: '0123456789', pool: '0123456789', titleKey: 'course.digits' });
  out.push({ id: id++, kind: 'punct', newKeys: '', pool: allLetters, titleKey: 'course.punct' });
  out.push({ id: id++, kind: 'words', newKeys: '', pool: '', titleKey: 'course.words' });
  out.push({ id: id++, kind: 'sentences', newKeys: '', pool: '', titleKey: 'course.sentences' });
  return out;
}

// ── Генерация контента урока ──
const rnd = (n: number) => Math.floor(Math.random() * n);
function drill(pool: string, accentNew: string, lines = 5): string[] {
  const chars = (pool || 'asdf').split('');
  const bag = accentNew ? [...chars, ...accentNew.split(''), ...accentNew.split('')] : chars;
  const out: string[] = [];
  for (let l = 0; l < lines; l++) {
    const words: string[] = [];
    for (let w = 0; w < 6; w++) {
      const len = 3 + rnd(3);
      let s = '';
      for (let i = 0; i < len; i++) s += bag[rnd(bag.length)];
      words.push(s);
    }
    out.push(words.join(' '));
  }
  return out;
}
function digitDrill(lines = 5): string[] {
  const out: string[] = [];
  for (let l = 0; l < lines; l++) {
    const groups: string[] = [];
    for (let g = 0; g < 6; g++) { let s = ''; for (let i = 0; i < 3 + rnd(2); i++) s += String(rnd(10)); groups.push(s); }
    out.push(groups.join(' '));
  }
  return out;
}
function punctDrill(pool: string, lines = 4): string[] {
  const marks = [',', '.', '?', '!', ';', ':'];
  const words = drill(pool, '', lines);
  return words.map((line) => line.split(' ').map((w) => w + marks[rnd(marks.length)]).join(' '));
}
function wordLines(L: Lang, lines = 5): string[] {
  const all = (REAL_WORDS[L] ?? REAL_WORDS.en).split(/\s+/);
  const out: string[] = [];
  for (let l = 0; l < lines; l++) {
    const ws: string[] = []; for (let w = 0; w < 6; w++) ws.push(all[rnd(all.length)]);
    out.push(ws.join(' '));
  }
  return out;
}
function capsLines(pool: string, lines = 4): string[] {
  return drill(pool, '', lines).map((line) => line.split(' ').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' '));
}

function lessonLines(L: Lang, les: Lesson): string[] {
  switch (les.kind) {
    case 'digits': return digitDrill();
    case 'punct': return punctDrill(les.pool);
    case 'words': return wordLines(L);
    case 'sentences': return SENTENCES[L] ?? SENTENCES.en;
    case 'caps': return capsLines(les.pool);
    default: return drill(les.pool, les.newKeys);
  }
}

// ── Прогресс ──
interface CourseProgress { stars: Record<number, number> }
let prog: CourseProgress = { stars: {} };
let curLang: Lang = 'en';
let lessons: Lesson[] = [];
function loadProg() {
  curLang = lang();
  lessons = buildLessons(curLang);
  try { const p = JSON.parse(localStorage.getItem(`tr_course_${curLang}`) ?? ''); if (p && p.stars) prog = p; else prog = { stars: {} }; }
  catch { prog = { stars: {} }; }
}
function saveProg() { try { localStorage.setItem(`tr_course_${curLang}`, JSON.stringify(prog)); } catch { /* quota */ } }
function unlocked(id: number): boolean { return id === 1 || (prog.stars[id - 1] ?? 0) > 0; }

// ── Состояние ──
type Screen = 'map' | 'lesson' | 'done';
let screen: Screen = 'map';
let lesson: Lesson | null = null;
let lines: string[] = [];
let lineIdx = 0;
let st: TypingState = createState(['']);
let errs = 0;
let chars = 0;
let lastStars = 0;
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;

export function courseEnter(container: HTMLElement, exit: () => void) {
  root = container; onExit = exit;
  loadProg();
  screen = 'map';
  courseRender();
}

export function courseHandleKey(e: KeyboardEvent) {
  if (screen !== 'lesson' || !lesson || st.finishedAt !== null) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  const rc = /[а-яё]/i.test(st.pattern);
  const r = pressChar(st, ch, true);
  if (expected && expected !== ' ' && expected !== '\n') { const id = keyIdFor(expected, rc); if (id) recordKey(id, !r.wrong); }
  if (r.wrong) errs++;
  if (r.finished) {
    chars += st.pattern.length;
    if (lineIdx + 1 < lines.length) { lineIdx++; st = createState([lines[lineIdx]]); }
    else finishLesson();
  }
  courseRender();
}

function finishLesson() {
  if (!lesson) return;
  const s = stats(st);
  lastStars = errs === 0 ? 3 : (1 - errs / Math.max(chars, 1)) >= 0.92 ? 2 : 1;
  if (lastStars > (prog.stars[lesson.id] ?? 0)) { prog.stars[lesson.id] = lastStars; saveProg(); }
  if (s.wpm > 0) pushHistory(s.wpm, s.accuracy, Date.now());
  screen = 'done';
}

function startLesson(les: Lesson) {
  lesson = les; lineIdx = 0; errs = 0; chars = 0;
  lines = lessonLines(curLang, les);
  st = createState([lines[0]]);
  screen = 'lesson';
  courseRender();
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
const lessonTitle = (les: Lesson) => les.titleArg ? `${t(les.titleKey)}: ${les.titleArg}` : t(les.titleKey);

function courseRender() {
  if (!root) return;
  if (screen === 'map') renderMap();
  else if (screen === 'lesson') renderLesson();
  else renderDone();
}

function renderMap() {
  const passed = Object.values(prog.stars).filter((s) => s > 0).length;
  root!.innerHTML = `
    <div class="wrap course">
      <header class="mode-head">
        <button id="c-exit" class="mode-back">${t('nav.back')}</button>
        <h1>📚 ${t('course.title')}</h1>
      </header>
      <p class="c-intro">${t('course.intro')} · ${t('st.done')} <b>${passed}/${lessons.length}</b></p>
      <div class="c-map">
        ${lessons.map((l) => {
          const open = unlocked(l.id); const s = prog.stars[l.id] ?? 0;
          return `<button class="c-les ${open ? 'open' : 'locked'} ${s > 0 ? 'passed' : ''}" data-les="${l.id}" ${open ? '' : 'disabled'}>
            <span class="c-num">${open ? l.id : '🔒'}</span>
            <span class="c-name">${esc(lessonTitle(l))}</span>
            <span class="c-stars">${s > 0 ? '⭐'.repeat(s) : ''}</span>
          </button>`;
        }).join('')}
      </div>
    </div>`;
  root!.querySelectorAll<HTMLButtonElement>('[data-les]').forEach((b) => {
    b.onclick = () => { const l = lessons.find((x) => x.id === Number(b.dataset.les)); if (l) startLesson(l); };
  });
  (root!.querySelector('#c-exit') as HTMLButtonElement).onclick = () => onExit?.();
}

function renderPattern(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    const ch = st.pattern[i];
    if (ch === '\n') html += `<span class="${cls} nl">↵</span><br/>`;
    else html += `<span class="${cls}">${esc(ch)}</span>`;
  }
  return html;
}

function renderLesson() {
  const l = lesson!;
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  const s = stats(st);
  root!.innerHTML = `
    <div class="wrap course">
      <header class="mode-head">
        <button id="c-back" class="mode-back">${t('nav.tomap')}</button>
        <span class="c-progress">${t('course.lesson')} ${l.id} · ${esc(lessonTitle(l))} · ${t('course.line')} ${lineIdx + 1}/${lines.length}</span>
        <span class="c-acc">${s.wpm} ${t('st.wpm')} · ${s.accuracy}%</span>
      </header>
      <div class="card"><div class="pattern" id="pattern">${renderPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
      <p class="hint2">${t('course.tip')}</p>
    </div>`;
  (root!.querySelector('#c-back') as HTMLButtonElement).onclick = () => { screen = 'map'; courseRender(); };
}

function renderDone() {
  const l = lesson!;
  const next = lessons.find((x) => x.id === l.id + 1);
  root!.innerHTML = `
    <div class="wrap course">
      <div class="c-done">
        <h2>${t('course.lesson')} ${l.id} ${t('k.passed')}</h2>
        <div class="k-stars-big">${'⭐'.repeat(lastStars)}${'☆'.repeat(3 - lastStars)}</div>
        <p class="k-done-note">${lastStars === 3 ? t('k.note3') : lastStars === 2 ? t('k.note2') : t('k.note1')}</p>
        <div class="donebtns">
          <button id="c-again">${t('k.again')}</button>
          <button id="c-map" class="ghost">${t('k.map')}</button>
          ${next ? `<button id="c-next" class="primary">${t('k.next')}</button>` : ''}
        </div>
      </div>
    </div>`;
  (root!.querySelector('#c-again') as HTMLButtonElement).onclick = () => startLesson(l);
  (root!.querySelector('#c-map') as HTMLButtonElement).onclick = () => { screen = 'map'; courseRender(); };
  const nx = root!.querySelector('#c-next') as HTMLButtonElement | null;
  if (nx && next) nx.onclick = () => startLesson(next);
}
