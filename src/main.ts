import './style.css';
import { loadExercises, exercisesOfBank, BANKS, type Bank, type Exercise } from './content';
import { ravenExercises } from './raven';
import { classicExercises } from './classic';
import { ruWordsExercises, ruPhrasesExercises } from './ru';
import { createState, pressChar, backspace, stats, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor, setLayout, type Layout } from './keyboard';
import { sfx, setSoundEnabled, metronome } from './sound';
import { voiceEnabled, setVoiceEnabled, VOICED_LANGS } from './voice';
import { type Profile, PROFILE_EMOJI, loadProfile, saveProfile, applyProfile } from './profiles';
import { kidsEnter, kidsHandleKey } from './kids';
import { courseEnter, courseHandleKey } from './course';
import { learnEnter, learnHandleKey } from './learn';
import { competeEnter, competeHandleKey } from './compete';
import { memorizeEnter, memorizeHandleKey } from './memorize';
import { recallEnter, recallHandleKey } from './recall';
import { companionEnter } from './companion';
import { t, lang, setLang, LANGS, LANG_LABEL, type Lang } from './i18n';
import { recordKey, heatMap, hasKeyData, weakDrill, pushHistory, progressSVG, streakDays, getTargetWpm, setTargetWpm } from './stats-store';
import { checkNewBadges, BADGES, unlockedSet, type Badge } from './achievements';
import { linkAccount, autoSync, pushSync, loadSession, clearSession, trSync, collectLocal } from './account';
import { checkForUpdate } from './updater';
import { registerCert } from './cert';
import { getChallenge, type ChallengeData } from './compete-net';

// Встроенный багфикс (webcheck bugfix-app.js, подключён в index.html ДО этого модуля,
// вендорится локально ради CSP APK). Кнопка «Сообщить о баге» снизу-слева → пишет в единый
// bug_reports → авто-задача TeamOps. enabled=true на бета/тест-фазу.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(window as any).BugfixApp?.init({
  project: 'typefree',
  version: '2.59.0',
  enabled: true,
  lang: document.documentElement.getAttribute('lang') || 'ru',
});

// P2: вызов, по ссылке которого вошли (?challenge=<id>) — передаётся в competeEnter один раз
let pendingChallenge: ChallengeData | null = null;

// ── Состояние сессии ──
let profile: Profile | null = loadProfile();
let all: Exercise[] = [];
let bank: Bank = 'abandon';
let pool: Exercise[] = [];
let idx = 0;
let st: TypingState = createState(['']);
let hidePattern = false;
let soundOn = true;
setSoundEnabled(() => soundOn);
let metroOn = false, metroBpm = 120;   // метроном (опция): ритм для темпа печати
try { metroOn = localStorage.getItem('tr_metro') === '1'; metroBpm = +(localStorage.getItem('tr_metro_bpm') ?? '120') || 120; } catch { /* */ }
function updateMetronome() {
  const active = metroOn && profile !== null && !hubMode && !modal && activeMode() === 'train';
  if (active) { if (!metronome.running()) metronome.start(metroBpm); }
  else metronome.stop();
}
// ── Раскладка клавиатуры (нац.: авто по языку интерфейса / ручной выбор) ──
let layoutPref: 'auto' | Layout = (localStorage.getItem('tr_layout') as 'auto' | Layout) || 'auto';
function resolveLayout(): Layout {
  if (layoutPref !== 'auto') return layoutPref;
  const l = lang();
  return l === 'fr' ? 'azerty' : l === 'de' ? 'qwertz' : 'qwerty';
}
function applyLayout() { setLayout(resolveLayout()); }
applyLayout();
let blockOnError = true;
let showKeyb = true; // схема клавиатуры из оригинального TypeRIGHT
let showHeat = localStorage.getItem('tr_heat') === '1'; // тепловая карта клавиш
let dark = (() => {                                       // тёмная тема: выбор юзера, иначе по системе
  const v = localStorage.getItem('tr_dark');
  if (v === '1') return true; if (v === '0') return false;
  return !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
})();
let statsTimer: number | null = null;

// Спец-режимы: 'weak' (адаптив по слабым клавишам) / 'custom' (свой текст)
let special: null | 'weak' | 'custom' = null;
let customText = '';
let modal: null | 'custom' | 'progress' | 'settings' | 'account' | 'ach' = null;
let accMsg = '';        // статус-сообщение формы аккаунта
let accBusy = false;    // идёт сетевой запрос (блокирует кнопки)
function accErr(err: string | undefined, ru: boolean): string {
  switch (err) {
    case 'nick_taken': return ru ? 'Ник занят' : 'Nick taken';
    case 'no_user': return ru ? 'Ник не найден' : 'No such nick';
    case 'bad_pin': return ru ? 'Неверный PIN' : 'Wrong PIN';
    case 'nick_short': return ru ? 'Ник слишком короткий' : 'Nick too short';
    case 'pin_short': return ru ? 'PIN слишком короткий (мин. 4)' : 'PIN too short (min 4)';
    default: return ru ? 'Ошибка сети' : 'Network error';
  }
}

// ── Режим «Поток» (как Stamina) ──
let flowMode = localStorage.getItem('tr_flow') === '1';
let flow = { typed: 0, errors: 0, ms: 0, count: 0 };
function flowReset() { flow = { typed: 0, errors: 0, ms: 0, count: 0 }; }

// ── Экзаменационный режим (Typing Test) ──
interface Exam {
  phase: 'setup' | 'run' | 'result';
  durMin: number; target: number; name: string; endAt: number;
  typed: number; errors: number; count: number;
  pool: Exercise[]; pi: number; timer: number | null;
}
let exam: Exam | null = null;

function examStats() {
  const s = exam && exam.phase === 'run' ? stats(st) : { typed: 0, errors: 0 };
  const typed = (exam?.typed ?? 0) + s.typed;
  const errors = (exam?.errors ?? 0) + s.errors;
  const elapsedMs = exam ? exam.durMin * 60000 - Math.max(0, exam.endAt - Date.now()) : 0;
  const minutes = Math.max(elapsedMs / 60000, 1 / 600);
  const gross = Math.round((typed + errors) / 5 / minutes);
  const net = Math.round(typed / 5 / minutes);
  const total = typed + errors;
  const accuracy = total > 0 ? Math.round((typed / total) * 100) : 100;
  return { typed, errors, gross, net, accuracy, elapsedMs };
}

function startExam(durMin: number, target: number, name: string) {
  const sentences = exercisesOfBank(all, 'abandon');
  const shuffled = [...sentences].sort(() => Math.random() - 0.5);
  exam = { phase: 'run', durMin, target, name, endAt: Date.now() + durMin * 60000, typed: 0, errors: 0, count: 0, pool: shuffled, pi: 0, timer: null };
  try { localStorage.setItem('tr_name', name); } catch { /* quota */ }
  st = createState([shuffled[0].lines.join(' ')]);
  exam.timer = window.setInterval(() => {
    if (!exam || exam.phase !== 'run') return;
    if (Date.now() >= exam.endAt) { finishExam(); return; }
    updateExamHud();
  }, 250);
  render();
}

function finishExam() {
  if (!exam) return;
  const s = stats(st);
  exam.typed += s.typed; exam.errors += s.errors;
  if (exam.timer) { clearInterval(exam.timer); exam.timer = null; }
  exam.phase = 'result';
  const r = examStats();
  pushHistory(r.net, r.accuracy, Date.now());
  notifyBadges();
  render();
}

function exitExam() {
  if (exam?.timer) clearInterval(exam.timer);
  exam = null;
  reset();
}

// ── Достижения: проверка новых бейджей + награда-тост ──
function notifyBadges() {
  const fresh = checkNewBadges();
  if (!fresh.length) return;
  sfx.star();
  let el = document.getElementById('badge-toast') as (HTMLElement & { _t?: number }) | null;
  if (!el) { el = document.createElement('div') as HTMLElement & { _t?: number }; el.id = 'badge-toast'; el.className = 'badge-toast'; document.body.appendChild(el); }
  el.innerHTML = fresh.map((b: Badge) => `<div class="bt-item"><span class="bt-ic">${b.icon}</span><span><b>${esc(t('ach.unlocked'))}</b><br>${esc(t('ach.' + b.id))}</span></div>`).join('');
  el.classList.add('show');
  window.clearTimeout(el._t);
  el._t = window.setTimeout(() => el && el.classList.remove('show'), 4500);
}

// ── Прогресс по банку: ключ tr_progress_<bank> ──
interface Progress { bestWpm: number; bestAcc: number; done: string[]; lastIdx: number; }
let prog: Progress = { bestWpm: 0, bestAcc: 0, done: [], lastIdx: 0 };

function loadProgress(b: Bank): Progress {
  try {
    const p = JSON.parse(localStorage.getItem(`tr_progress_${b}`) ?? '');
    if (p && Array.isArray(p.done)) return { bestWpm: p.bestWpm | 0, bestAcc: p.bestAcc | 0, done: p.done, lastIdx: p.lastIdx | 0 };
  } catch { /* нет сохранения */ }
  return { bestWpm: 0, bestAcc: 0, done: [], lastIdx: 0 };
}
function saveProgress() {
  try { localStorage.setItem(`tr_progress_${bank}`, JSON.stringify(prog)); } catch { /* quota */ }
}
function recordFinish(ex: Exercise) {
  const s = stats(st);
  const isRecord = s.wpm > 0 && s.wpm > prog.bestWpm;
  if (s.wpm > prog.bestWpm) prog.bestWpm = s.wpm;
  if (s.accuracy > prog.bestAcc) prog.bestAcc = s.accuracy;
  if (!prog.done.includes(ex.id)) prog.done.push(ex.id);
  saveProgress();
  if (isRecord) sfx.record(); else sfx.success();   // звук завершения / рекорда
  void pushSync();   // тихий облачный синк прогресса (если вошёл в аккаунт)
}

function viewStats() {
  const s = stats(st);
  if (!flowMode) return s;
  const typed = flow.typed + s.typed;
  const errors = flow.errors + s.errors;
  const elapsedMs = flow.ms + s.elapsedMs;
  const minutes = elapsedMs / 60000;
  const wpm = minutes > 0 ? Math.round(typed / 5 / minutes) : 0;
  const total = typed + errors;
  return { typed, errors, elapsedMs, wpm, accuracy: total > 0 ? Math.round((typed / total) * 100) : 100 };
}

// ── Звук ошибки ──
let audioCtx: AudioContext | null = null;
function beep() {
  if (!soundOn) return;
  try {
    audioCtx ??= new AudioContext();
    const o = audioCtx.createOscillator(); const g = audioCtx.createGain();
    o.frequency.value = 220; o.type = 'square'; g.gain.value = 0.06;
    o.connect(g); g.connect(audioCtx.destination);
    o.start(); o.stop(audioCtx.currentTime + 0.07);
  } catch { /* no audio */ }
}

const app = document.getElementById('app')!;
let kidsActive = false;
let courseMode = false;  // пользователь открыл курс
let courseInit = false;  // courseEnter уже вызван (курс рисует себя сам)
let aiMode = false;      // пользователь открыл AI-обучение
let aiInit = false;
let compMode = false;    // пользователь открыл соревнование
let compInit = false;
let memMode = false;     // пользователь открыл режим «Наизусть»
let memInit = false;
let spanMode = false;    // пользователь открыл режим «Память» (списки слов)
let spanInit = false;
let hubMode = true;      // стартовый экран «С чего начать?» (главное меню режимов)
// Адаптивный компаньон: на телефоне без физической клавиатуры печати не научиться —
// стартуем в компаньоне (прогресс/метод/рейтинг), тренажёр за кнопкой ИЛИ при детекте клавиатуры.
let companionMode = false;
let companionInit = false;

// эвристика «телефон без клавиатуры»: тач + грубый указатель + нет hover + узкий экран.
// планшет (широкий) и десктоп → тренажёр (модель Дениса). Ручной выбор запоминаем в tr_mode.
function isPhoneNoKeyboard(): boolean {
  try {
    const mm = (q: string) => !!(window.matchMedia && window.matchMedia(q).matches);
    const touch = (navigator.maxTouchPoints || 0) > 0;
    // < 600 по меньшей стороне = телефон (портрет ~360–430); планшет (768+) → тренажёр (модель Дениса)
    const phone = Math.min(window.innerWidth, window.innerHeight) < 600;
    return touch && mm('(pointer: coarse)') && mm('(hover: none)') && phone;
  } catch { return false; }
}
// уйти из компаньона в тренажёр (кнопка/детект клавиатуры), запомнить выбор
function openTrainerFromCompanion(): void {
  companionMode = false; companionInit = false; hubMode = true;
  try { localStorage.setItem('tr_mode', 'trainer'); } catch { /* quota */ }
  render();
}

function ruCtx(): boolean { return /[а-яё]/i.test(st.pattern); }
function kbShowRu(rc: boolean): boolean { return lang() === 'ru' || rc; }

function applyDark() {
  if (dark) document.documentElement.dataset.theme = 'dark';
  else delete document.documentElement.dataset.theme;
}

function langSwitcherHtml(): string {
  return `<select id="lang" title="Language">${LANGS.map((l) => `<option value="${l}" ${lang() === l ? 'selected' : ''}>${LANG_LABEL[l]}</option>`).join('')}</select>`;
}
function bindLang(after: () => void) {
  const el = document.getElementById('lang') as HTMLSelectElement | null;
  if (el) el.onchange = () => { setLang(el.value as Lang); after(); };
}

// Текущее «упражнение» с учётом спец-режимов
function curExercise(): Exercise | null {
  if (special === 'weak') return { id: 'weak', bank, title: t('weak.title'), lines: weakLines };
  if (special === 'custom') return { id: 'custom', bank, title: t('custom.title'), lines: customLines };
  return pool[idx] ?? null;
}
let weakLines: string[] = [];
let customLines: string[] = [];

// ── Верхняя панель: режимы (видны и переключаются ВЕЗДЕ) + Поток + настройки ──
let chromeEl: HTMLElement | null = null;
function activeMode(): string {
  if (hubMode) return 'hub';
  if (exam) return 'exam';
  if (aiMode) return 'learn';
  if (compMode) return 'compete';
  if (memMode) return 'memorize';
  if (spanMode) return 'span';
  if (courseMode) return 'course';
  if (profile === 'kids') return 'kids';
  return 'train';
}
const MODE_ICON: Record<string, string> = { train: 'train', course: 'course', learn: 'ai', compete: 'compete', memorize: 'memorize', span: 'span', exam: 'exam', progress: 'progress' };
function profDir(): string { return profile === 'f' ? 'f/' : profile === 'kids' ? 'kids/' : ''; } // иконки под профиль (М/Ж/дети)
function modeIcon(g: string, cls = 'mode-ic'): string { return `<img class="${cls}" src="images/icons/${profDir()}mode-${MODE_ICON[g] ?? g}.webp" alt=""/>`; }
function uiIcon(name: string): string { return `<img class="tb-ic" src="images/icons/${profDir()}${name}.webp" alt=""/>`; }
function renderTopbar() {
  if (!chromeEl) { chromeEl = document.createElement('div'); chromeEl.id = 'topbar'; document.body.prepend(chromeEl); }
  // В компаньоне (телефон без клавы) верхний бар режимов не нужен — они требуют клавиатуры.
  chromeEl.style.display = companionMode ? 'none' : '';
  if (companionMode) return;
  if (profile === null) { chromeEl.innerHTML = ''; return; } // на онбординге скрыта
  const act = activeMode();
  const modes: Array<[string, string]> = [
    ['train', t('hub.train')], ['course', t('course.title')],
    ['learn', t('learn.title')], ['compete', t('compete.title')],
    ['memorize', t('mem.title')], ['span', t('span.title')], ['exam', t('ex.title')],
  ];
  chromeEl.innerHTML = `
    <button id="tb-home" class="tb-icon" title="${t('hub.home')}">${uiIcon('ui-home')}</button>
    <div class="tb-modes">
      ${modes.map(([g, label]) => `<button class="tb-mode ${act === g ? 'active' : ''}" data-goto="${g}">${modeIcon(g)}<span>${label}</span></button>`).join('')}
    </div>
    <span class="tb-sp"></span>
    <button id="tb-flow" class="tb-btn ${flowMode ? 'on' : ''}" title="${t('hint.flow')}">${uiIcon('ui-flow')} ${t('tb.flow')}</button>
    <button id="tb-progress" class="tb-icon" title="${t('prog.title')}">${uiIcon('ui-progress')}</button>
    <button id="tb-ach" class="tb-icon" title="${t('ach.title')}">🏆</button>
    <button id="tb-account" class="tb-icon" title="${lang() === 'ru' ? 'Аккаунт' : 'Account'}">${loadSession() ? '👤' : '☁️'}</button>
    <button id="tb-settings" class="tb-icon" title="${t('hub.settings')}">${uiIcon('ui-settings')}</button>
    <button id="tb-dark" class="tb-icon" title="${t('tb.dark')}">${uiIcon('ui-dark')}</button>
    <select id="tb-profile" title="Profile">
      ${(Object.keys(PROFILE_EMOJI) as Profile[]).map((p) => `<option value="${p}" ${p === profile ? 'selected' : ''}>${PROFILE_EMOJI[p]}</option>`).join('')}
    </select>
    <select id="tb-lang" title="Language">${LANGS.map((l) => `<option value="${l}" ${lang() === l ? 'selected' : ''}>${LANG_LABEL[l]}</option>`).join('')}</select>`;
  chromeEl.querySelectorAll<HTMLButtonElement>('[data-goto]').forEach((b) => { b.onclick = () => goTo(b.dataset.goto!); });
  (document.getElementById('tb-home') as HTMLButtonElement).onclick = () => goTo('hub');
  (document.getElementById('tb-flow') as HTMLButtonElement).onclick = () => { flowMode = !flowMode; try { localStorage.setItem('tr_flow', flowMode ? '1' : '0'); } catch { /* */ } flowReset(); reapplyGlobal(); };
  (document.getElementById('tb-progress') as HTMLButtonElement).onclick = () => { modal = 'progress'; render(); };
  (document.getElementById('tb-ach') as HTMLButtonElement).onclick = () => { modal = 'ach'; render(); };
  (document.getElementById('tb-settings') as HTMLButtonElement).onclick = () => { modal = 'settings'; render(); };
  (document.getElementById('tb-account') as HTMLButtonElement).onclick = () => { modal = 'account'; accMsg = ''; render(); };
  (document.getElementById('tb-dark') as HTMLButtonElement).onclick = () => { dark = !dark; try { localStorage.setItem('tr_dark', dark ? '1' : '0'); } catch { /* */ } applyDark(); renderTopbar(); };
  const tp = document.getElementById('tb-profile') as HTMLSelectElement;
  tp.onchange = () => { profile = tp.value as Profile; saveProfile(profile); reapplyGlobal(); };
  const tl = document.getElementById('tb-lang') as HTMLSelectElement;
  tl.onchange = () => { setLang(tl.value as Lang); reapplyGlobal(); };
}

// прямой переход в любой режим из любого (одним кликом по верхней панели)
function goTo(target: string) {
  special = null;
  if (exam?.timer) clearInterval(exam.timer);
  exam = null; aiMode = false; compMode = false; memMode = false; spanMode = false; courseMode = false;
  aiInit = false; compInit = false; memInit = false; spanInit = false; courseInit = false; kidsActive = false;
  hubMode = false;
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  if (target === 'hub') hubMode = true;
  else if (target === 'train') { /* основной экран; банк уже загружен */ }
  else if (target === 'course') courseMode = true;
  else if (target === 'learn') aiMode = true;
  else if (target === 'compete') compMode = true;
  else if (target === 'memorize') memMode = true;
  else if (target === 'span') spanMode = true;
  else if (target === 'exam') exam = { phase: 'setup', durMin: 10, target: 35, name: '', endAt: 0, typed: 0, errors: 0, count: 0, pool: [], pi: 0, timer: null };
  if (target === 'train') reset(); else render();
}
// перерисовать активный режим (язык/поток/профиль сменились) — рестартует текущий режим
function reapplyGlobal() {
  applyLayout();   // раскладка авто-следует за языком интерфейса (если pref=auto)
  aiInit = false; courseInit = false; compInit = false; memInit = false; spanInit = false; kidsActive = false;
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  if (!hubMode && !aiMode && !compMode && !memMode && !spanMode && !courseMode && !exam && profile !== 'kids') { if (special) { special === 'weak' ? startWeak() : startCustom(customText); } else if (bank === 'poemHymn' || bank === 'classic') loadBank(); else reset(); }
  render();
}

// модалки (настройки/прогресс/свой текст) — поверх ЛЮБОГО режима
let modalEl: HTMLElement | null = null;
function renderModalGlobal() {
  if (!modalEl) { modalEl = document.createElement('div'); modalEl.id = 'modal-root'; document.body.appendChild(modalEl); }
  if (!modal) { modalEl.innerHTML = ''; return; }
  modalEl.innerHTML = renderModal();
  const close = () => { modal = null; renderModalGlobal(); };
  const mb = document.getElementById('modal-bg'); if (mb) mb.onclick = (e) => { if (e.target === mb) close(); };
  onClick('set-close', close); onClick('prog-close', close); onClick('custom-cancel', close); onClick('ach-close', close);
  onClick('sound-test', () => sfx.record());   // явная проверка звука (клик = жест, разблокирует аудио)
  onClick('custom-go', () => startCustom((document.getElementById('custom-ta') as HTMLTextAreaElement).value));
  // аккаунт: вход / создание / синк / выход
  const accDo = async (mode: 'login' | 'register') => {
    const nick = (document.getElementById('acc-nick') as HTMLInputElement)?.value.trim() ?? '';
    const pin = (document.getElementById('acc-pin') as HTMLInputElement)?.value ?? '';
    const ru = lang() === 'ru';
    if (nick.length < 2) { accMsg = ru ? 'Ник минимум 2 символа' : 'Nick min 2 chars'; renderModalGlobal(); return; }
    if (pin.length < 4) { accMsg = ru ? 'PIN минимум 4 цифры' : 'PIN min 4 digits'; renderModalGlobal(); return; }
    accBusy = true; accMsg = ru ? 'Связь…' : 'Connecting…'; renderModalGlobal();
    const r = await linkAccount(nick, pin, mode);
    accBusy = false;
    if (r.ok) { accMsg = ru ? 'Прогресс синхронизирован ✓' : 'Progress synced ✓'; renderTopbar(); renderModalGlobal(); }
    else { accMsg = accErr(r.err, ru); renderModalGlobal(); }
  };
  onClick('acc-login', () => void accDo('login'));
  onClick('acc-register', () => void accDo('register'));
  onClick('acc-logout', () => { clearSession(); accMsg = ''; renderTopbar(); renderModalGlobal(); });
  onClick('acc-sync', () => void (async () => {
    const sess = loadSession(); if (!sess) return;
    const ru = lang() === 'ru';
    accBusy = true; accMsg = ru ? 'Синхронизация…' : 'Syncing…'; renderModalGlobal();
    const r = await trSync(sess.nick, sess.pin, collectLocal());
    accBusy = false; accMsg = r.ok ? (ru ? 'Готово ✓' : 'Done ✓') : (ru ? 'Ошибка сети' : 'Network error'); renderModalGlobal();
  })());
  // настройки применяются сразу к активному экрану
  const cb = (id: string, fn: (v: boolean) => void) => onChange(id, (el) => { fn(el.checked); reapplyGlobal(); });
  cb('hide', (v) => { hidePattern = v; });
  cb('sound', (v) => { soundOn = v; });
  cb('block', (v) => { blockOnError = v; });
  cb('keyb', (v) => { showKeyb = v; });
  cb('heat', (v) => { showHeat = v; try { localStorage.setItem('tr_heat', showHeat ? '1' : '0'); } catch { /* */ } });
  cb('hardkeys', (v) => { try { localStorage.setItem('tr_hardkeys', v ? '1' : '0'); } catch { /* */ } });
  cb('metro', (v) => { metroOn = v; try { localStorage.setItem('tr_metro', v ? '1' : '0'); } catch { /* */ } });
  cb('bridge', (v) => { try { localStorage.setItem('tr_bridge', v ? '1' : '0'); } catch { /* */ } });
  cb('voice', (v) => setVoiceEnabled(v));
  onChange('layoutsel', (el) => {
    layoutPref = el.value as 'auto' | Layout;
    try { localStorage.setItem('tr_layout', layoutPref); } catch { /* */ }
    applyLayout(); reapplyGlobal();
  });
  onChange('metrobpm', (el) => {
    metroBpm = +el.value || 120;
    try { localStorage.setItem('tr_metro_bpm', String(metroBpm)); } catch { /* */ }
    const lbl = document.getElementById('metrobpmval'); if (lbl) lbl.textContent = String(metroBpm);
    if (metronome.running()) metronome.start(metroBpm);
  });
  onChange('targetwpm', (el) => { const v = +el.value; if (v >= 10 && v <= 200) setTargetWpm(v); }); // цель для forecast() в прогрессе
}

function render() {
  renderTopbar();
  renderModalGlobal();
  updateMetronome();
  if (profile === null) { kidsActive = false; renderOnboarding(); return; }
  if (aiMode) {
    if (!aiInit) { aiInit = true; learnEnter(app, profile ?? 'm', () => { aiMode = false; aiInit = false; render(); }); }
    return; // AI-режим рисует себя сам (учитывает профиль, в т.ч. детский)
  }
  aiInit = false;
  if (compMode) {
    if (!compInit) { compInit = true; const pc = pendingChallenge; pendingChallenge = null; competeEnter(app, profile ?? 'm', () => { compMode = false; compInit = false; render(); }, pc); }
    return; // соревнование рисует себя сам
  }
  compInit = false;
  if (memMode) {
    if (!memInit) { memInit = true; memorizeEnter(app, profile ?? 'm', () => { memMode = false; memInit = false; render(); }); }
    return; // режим «Наизусть» рисует себя сам
  }
  memInit = false;
  if (spanMode) {
    if (!spanInit) { spanInit = true; recallEnter(app, profile ?? 'm', () => { spanMode = false; spanInit = false; render(); }); }
    return; // режим «Память» рисует себя сам
  }
  spanInit = false;
  if (profile === 'kids') {
    if (!kidsActive) {
      kidsActive = true;
      kidsEnter(app,
        () => { kidsActive = false; profile = null; applyProfile(null); render(); },
        () => { kidsActive = false; aiMode = true; render(); });
    }
    return;
  }
  kidsActive = false;
  if (courseMode) {
    if (!courseInit) { courseInit = true; courseEnter(app, () => { courseMode = false; courseInit = false; render(); }); }
    return; // курс рисует себя сам
  }
  courseInit = false;
  if (exam) { renderExam(); return; }
  if (companionMode) {
    if (!companionInit) {
      companionInit = true;
      companionEnter(app, {
        openTrainer: openTrainerFromCompanion,
        openLearn: () => { companionInit = false; aiMode = true; aiInit = false; render(); },
        openCompete: () => { companionInit = false; compMode = true; compInit = false; render(); },
      });
    }
    return; // компаньон рисует себя сам; learn/compete открываются поверх и возвращаются сюда
  }
  companionInit = false;
  if (hubMode) { renderHub(); return; }
  const ex = curExercise();
  const s = viewStats();
  const inSpecial = special !== null;
  app.innerHTML = `
    <div class="wrap">
      <header>
        <h1>Type<span>RIGHT</span>ing</h1>
        <select id="bank" class="bank-sel">
          ${BANKS.map((b) => `<option value="${b}" ${b === bank && !inSpecial ? 'selected' : ''}>${t('bank.' + b)}</option>`).join('')}
        </select>
      </header>
      <p class="bankdesc">${inSpecial ? (special === 'weak' ? t('weak.hint') : '') : t('bank.' + bank + '.desc')} ${inSpecial ? '' : `· <b>${pool.length}</b> ${t('st.exercises')} · ${t('st.done')} <b>${prog.done.length}</b>${prog.bestWpm > 0 ? ` · ${t('st.record')} <b>${prog.bestWpm}</b> ${t('st.wpm')} · <b>${prog.bestAcc}%</b>` : ''}`}</p>

      <div class="nav-row">
        <div class="modes-tools">
          <button id="weak" class="tool-btn ${special === 'weak' ? 'on' : ''}">${t('tb.weak')}</button>
          <button id="custom" class="tool-btn ${special === 'custom' ? 'on' : ''}">${t('tb.custom')}</button>
        </div>
        <span class="spacer"></span>
        <button id="prev" class="ghost">${t('tb.prev')}</button>
        <span class="counter">${inSpecial ? '•' : `${idx + 1} / ${pool.length}`}</span>
        <button id="next" class="ghost">${t('tb.next')}</button>
      </div>

      <div class="card">
        <div class="exhead">
          <span class="extitle">${esc(ex?.title ?? '')}</span>
          ${ex?.hint ? `<span class="exhint">${esc(ex.hint)}</span>` : ''}
        </div>
        <div class="pattern ${hidePattern ? 'hidden' : ''}" id="pattern">${renderPattern()}</div>
      </div>

      ${keybBlock()}

      <div class="statsbar">${statsCells(s)}</div>

      ${st.finishedAt !== null ? renderDone(s) : `<p class="hint2">${special === 'weak' && weakLines.length && weakNoData ? t('weak.none') : flowMode ? t('hint.flow') : t('hint.type')} ${blockOnError ? t('hint.block') : t('hint.bs')}</p>`}
    </div>
  `;
  bindControls();
}

let weakNoData = false;

function keybBlock(): string {
  if (!showKeyb) return '';
  const rc = ruCtx();
  const heat = showHeat && hasKeyData() ? heatMap() : null;
  return `<div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, kbShowRu(rc), heat)}</div>
    ${heat ? `<p class="heat-legend"><i class="g">освоено</i> · <i class="r">слабые клавиши</i></p>` : ''}`;
}

function statsCells(s: ReturnType<typeof viewStats>): string {
  return `
    <div><b>${s.wpm}</b><span>${t('st.wpm')}</span></div>
    <div><b>${s.accuracy}%</b><span>${t('st.accuracy')}</span></div>
    <div><b class="${s.errors > 0 ? 'err' : ''}">${s.errors}</b><span>${t('st.errors')}</span></div>
    <div><b>${(s.elapsedMs / 1000).toFixed(0)}s</b><span>${t('st.time')}</span></div>
    ${flowMode ? `<div><b>🔥 ${flow.count}</b><span>${t('st.streak')}</span></div>` : ''}`;
}

function esc(s: string) {
  return s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
}

function renderPattern(): string {
  if (hidePattern) return `<span class="hidden-note">${t('hint.hidden')}</span>`;
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const ch = st.pattern[i];
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    if (ch === '\n') html += `<span class="${cls} nl">↵</span><br/>`;
    else html += `<span class="${cls}">${esc(ch)}</span>`;
  }
  return html;
}

function renderModal(): string {
  if (modal === 'account') {
    const sess = loadSession();
    const ru = lang() === 'ru';
    const body = sess ? `
      <p class="acc-in">${ru ? 'Вы вошли как' : 'Signed in as'} <b>${esc(sess.nick)}</b></p>
      <p class="hint2">${ru ? 'Прогресс синхронизируется между устройствами под этим ником.' : 'Progress syncs across devices under this nick.'}</p>
      ${accMsg ? `<p class="acc-msg">${esc(accMsg)}</p>` : ''}
      <div class="donebtns">
        <button id="acc-logout" class="ghost">${ru ? 'Выйти' : 'Sign out'}</button>
        <button id="acc-sync" class="primary" ${accBusy ? 'disabled' : ''}>${accBusy ? '…' : (ru ? 'Синхронизировать' : 'Sync now')}</button>
      </div>` : `
      <p class="hint2">${ru ? 'Ник + короткий PIN — и прогресс будет на любом устройстве. Без почты.' : 'Nick + short PIN — your progress on any device. No email.'}</p>
      <input id="acc-nick" class="acc-inp" placeholder="${ru ? 'Ник' : 'Nick'}" maxlength="24" autocomplete="off"/>
      <input id="acc-pin" class="acc-inp" type="password" inputmode="numeric" placeholder="PIN" maxlength="12" autocomplete="off"/>
      ${accMsg ? `<p class="acc-msg">${esc(accMsg)}</p>` : ''}
      <div class="donebtns">
        <button id="acc-login" class="ghost" ${accBusy ? 'disabled' : ''}>${ru ? 'Войти' : 'Sign in'}</button>
        <button id="acc-register" class="primary" ${accBusy ? 'disabled' : ''}>${ru ? 'Создать' : 'Create'}</button>
      </div>`;
    return `<div class="modal-bg" id="modal-bg"><div class="modal">
      <h2>${sess ? '👤' : '☁️'} ${ru ? 'Аккаунт' : 'Account'}</h2>${body}
    </div></div>`;
  }
  if (modal === 'ach') {
    const un = unlockedSet();
    return `<div class="modal-bg" id="modal-bg"><div class="modal">
      <h2>🏆 ${t('ach.title')}</h2>
      <p class="hint2">${esc(t('ach.sub'))} — ${un.size}/${BADGES.length}</p>
      <div class="ach-grid">
        ${BADGES.map((b) => `<div class="ach-badge ${un.has(b.id) ? 'on' : ''}"><span class="ach-ic">${b.icon}</span><span class="ach-t">${esc(t('ach.' + b.id))}</span></div>`).join('')}
      </div>
      <div class="donebtns"><button id="ach-close" class="primary">${t('prog.close')}</button></div>
    </div></div>`;
  }
  if (modal === 'settings') {
    return `<div class="modal-bg" id="modal-bg"><div class="modal">
      <h2>⚙ ${t('hub.settings')}</h2>
      <div class="settings-list">
        <label><input type="checkbox" id="hide" ${hidePattern ? 'checked' : ''}/> ${t('tb.hide')}</label>
        <label><input type="checkbox" id="sound" ${soundOn ? 'checked' : ''}/> ${t('tb.sound')}</label>
        ${VOICED_LANGS.has(lang()) ? `<label><input type="checkbox" id="voice" ${voiceEnabled() ? 'checked' : ''}/> ${lang() === 'ru' ? '🔊 Озвучка букв' : '🔊 Letter voice'}</label>` : ''}
        <label><input type="checkbox" id="block" ${blockOnError ? 'checked' : ''}/> ${t('tb.block')}</label>
        <label><input type="checkbox" id="keyb" ${showKeyb ? 'checked' : ''}/> ${t('tb.keyb')}</label>
        <label><input type="checkbox" id="heat" ${showHeat ? 'checked' : ''}/> ${t('tb.heat')}</label>
        <label><input type="checkbox" id="hardkeys" ${localStorage.getItem('tr_hardkeys') === '1' ? 'checked' : ''}/> ${t('set.hardkeys')}</label>
        <label><input type="checkbox" id="metro" ${metroOn ? 'checked' : ''}/> ${t('set.metro')}</label>
        <label class="set-range">${t('set.metro.bpm')}: <input type="range" id="metrobpm" min="60" max="200" step="10" value="${metroBpm}"/> <b id="metrobpmval">${metroBpm}</b></label>
        <label><input type="checkbox" id="bridge" ${localStorage.getItem('tr_bridge') !== '0' ? 'checked' : ''}/> ${t('set.bridge')}</label>
        <label class="set-range">${lang() === 'ru' ? 'Раскладка' : 'Layout'}: <select id="layoutsel">
          <option value="auto" ${layoutPref === 'auto' ? 'selected' : ''}>${lang() === 'ru' ? 'Авто (по языку)' : 'Auto (by language)'}</option>
          <option value="qwerty" ${layoutPref === 'qwerty' ? 'selected' : ''}>QWERTY</option>
          <option value="azerty" ${layoutPref === 'azerty' ? 'selected' : ''}>AZERTY · FR</option>
          <option value="qwertz" ${layoutPref === 'qwertz' ? 'selected' : ''}>QWERTZ · DE</option>
        </select></label>
        <label class="set-range">🎯 ${lang() === 'ru' ? 'Целевой WPM (для прогноза)' : 'Target WPM (for forecast)'}: <input type="number" id="targetwpm" min="10" max="200" step="5" value="${getTargetWpm()}" style="width:62px"/></label>
        <button id="sound-test" class="ghost" style="margin-top:6px">🔊 ${t('set.soundtest')}</button>
      </div>
      <div class="donebtns"><button id="set-close" class="primary">${t('prog.close')}</button></div>
    </div></div>`;
  }
  if (modal === 'custom') {
    return `<div class="modal-bg" id="modal-bg"><div class="modal">
      <h2>${t('custom.title')}</h2>
      <textarea id="custom-ta" placeholder="${t('custom.ph')}">${esc(customText)}</textarea>
      <div class="donebtns">
        <button id="custom-cancel" class="ghost">${t('custom.cancel')}</button>
        <button id="custom-go" class="primary">${t('custom.start')}</button>
      </div>
    </div></div>`;
  }
  // progress
  const chart = progressSVG();
  return `<div class="modal-bg" id="modal-bg"><div class="modal">
    <h2>${t('prog.title')}</h2>
    ${chart || `<p class="hint2">${t('prog.empty')}</p>`}
    <div class="donebtns"><button id="prog-close" class="primary">${t('prog.close')}</button></div>
  </div></div>`;
}

function renderOnboarding() {
  app.innerHTML = `
    <div class="wrap onboard">
      <div class="ob-lang">${langSwitcherHtml()}</div>
      <h1 class="ob-title">Type<span>RIGHT</span>ing</h1>
      <p class="ob-sub">${t('ob.sub')}</p>
      <div class="ob-cards">
        ${(Object.keys(PROFILE_EMOJI) as Profile[]).map((p) => `
          <button class="ob-card" data-profile-pick="${p}">
            <span class="ob-emoji">${PROFILE_EMOJI[p]}</span>
            <span class="ob-name">${t('profile.' + p)}</span>
            <span class="ob-desc">${t('profile.' + p + '.desc')}</span>
          </button>`).join('')}
      </div>
      <p class="ob-note">${t('ob.note')}</p>
    </div>`;
  app.querySelectorAll<HTMLButtonElement>('[data-profile-pick]').forEach((btn) => {
    btn.onclick = () => { profile = btn.dataset.profilePick as Profile; saveProfile(profile); render(); };
  });
  bindLang(() => renderOnboarding());
}

function renderDone(s: ReturnType<typeof viewStats>): string {
  return `
    <div class="done">
      <h2>${profile === 'f' ? t('done.title.f') : t('done.title')}</h2>
      <div class="donestats">
        <span><b>${s.wpm}</b> ${t('st.wpm')}</span>
        <span><b>${s.accuracy}%</b> ${t('st.accuracy')}</span>
        <span><b>${s.errors}</b> ${t('st.errors')}</span>
        <span><b>${(s.elapsedMs / 1000).toFixed(1)}s</b></span>
      </div>
      <div class="donebtns">
        <button id="again">${t('done.again')}</button>
        <button id="nextdone" class="primary">${t('done.next')}</button>
      </div>
    </div>`;
}

// ── Экзамен: экраны ──
function renderExam() {
  if (!exam) return;
  if (exam.phase === 'setup') {
    const savedName = localStorage.getItem('tr_name') ?? '';
    app.innerHTML = `
      <div class="wrap"><div class="exam-setup">
        <h2>⏱ ${t('ex.title')}</h2>
        <p class="ex-desc">${t('ex.desc')}</p>
        <div class="ex-form">
          <label>${t('ex.duration')}:
            <select id="ex-dur"><option value="1">1 ${t('ex.min')}</option><option value="5">5 ${t('ex.min')}</option><option value="10" selected>10 ${t('ex.min')}</option></select>
          </label>
          <label>${t('ex.target')}: <input id="ex-target" type="number" value="35" min="5" max="120"/></label>
          <label>${t('ex.name')}: <input id="ex-name" type="text" value="${esc(savedName)}" placeholder="—"/></label>
        </div>
        <div class="donebtns">
          <button id="ex-cancel" class="ghost">${t('ex.cancel')}</button>
          <button id="ex-go" class="primary">${t('ex.start')}</button>
        </div>
      </div></div>`;
    (document.getElementById('ex-go') as HTMLButtonElement).onclick = () => {
      const dur = Number((document.getElementById('ex-dur') as HTMLSelectElement).value);
      const target = Number((document.getElementById('ex-target') as HTMLInputElement).value) || 35;
      const name = (document.getElementById('ex-name') as HTMLInputElement).value.trim();
      startExam(dur, target, name);
    };
    (document.getElementById('ex-cancel') as HTMLButtonElement).onclick = () => exitExam();
    return;
  }
  if (exam.phase === 'run') {
    const ex = exam.pool[exam.pi];
    const s = examStats();
    app.innerHTML = `
      <div class="wrap">
        <div class="exam-hud">
          <span class="ex-timer" id="ex-timer">${fmtTime(Math.max(0, exam.endAt - Date.now()))}</span>
          <span class="ex-hudstats" id="ex-hudstats">${t('ex.net')} <b>${s.net}</b> · ${t('st.accuracy')} <b>${s.accuracy}%</b> · ${t('ex.target.short')} ${exam.target}</span>
          <button id="ex-stop" class="ghost">${t('ex.cancel')}</button>
        </div>
        <div class="card"><div class="exhead"><span class="extitle">${esc(ex?.title ?? '')}</span></div>
          <div class="pattern" id="pattern">${renderPattern()}</div></div>
        ${keybBlock()}
      </div>`;
    (document.getElementById('ex-stop') as HTMLButtonElement).onclick = () => finishExam();
    return;
  }
  const s = examStats();
  const pass = s.net >= exam.target;
  app.innerHTML = `
    <div class="wrap"><div class="exam-result">
      <h2>${t('ex.result')}</h2>
      <div class="ex-verdict ${pass ? 'pass' : 'fail'}">${pass ? t('ex.pass') : t('ex.fail')} <small>(${t('ex.target.short')} ${exam.target} ${t('ex.net')})</small></div>
      <div class="statsbar">
        <div><b>${s.net}</b><span>${t('ex.net')}</span></div>
        <div><b>${s.gross}</b><span>${t('ex.gross')}</span></div>
        <div><b>${s.accuracy}%</b><span>${t('st.accuracy')}</span></div>
        <div><b>${s.typed + s.errors}</b><span>${t('ex.keystrokes')}</span></div>
        <div><b>${exam.durMin} ${t('ex.min')}</b><span>${t('st.time')}</span></div>
      </div>
      <div class="donebtns">
        <button id="ex-cert" class="primary">${t('ex.cert')}</button>
        <button id="ex-share">${lang() === 'ru' ? '🔗 Поделиться' : '🔗 Share'}</button>
        <button id="ex-retry">${t('ex.again')}</button>
        <button id="ex-exit" class="ghost">${t('ex.cancel')}</button>
      </div>
      <div id="ex-sharebox" hidden style="margin-top:14px"></div>
    </div></div>`;
  (document.getElementById('ex-cert') as HTMLButtonElement).onclick = () => downloadCertificate(s, pass);
  bindShare(s);
  (document.getElementById('ex-retry') as HTMLButtonElement).onclick = () => { exam!.phase = 'setup'; render(); };
  (document.getElementById('ex-exit') as HTMLButtonElement).onclick = () => exitExam();
}

// P1 сертификат-виралка: регистрируем результат → показываем шеринг-ссылку + кнопки соцсетей.
function bindShare(s: ReturnType<typeof examStats>) {
  const btn = document.getElementById('ex-share') as HTMLButtonElement | null;
  const box = document.getElementById('ex-sharebox');
  if (!btn || !box || !exam) return;
  const L = lang() === 'ru';
  btn.onclick = async () => {
    btn.disabled = true;
    const orig = btn.textContent;
    btn.textContent = '…';
    const url = await registerCert(exam!.name, 'exam', lang(), s.net, s.accuracy);
    btn.disabled = false;
    btn.textContent = orig;
    box.hidden = false;
    if (!url) { box.textContent = L ? 'Не удалось создать ссылку (нет сети?)' : 'Could not create link (offline?)'; return; }
    const enc = encodeURIComponent(url);
    const txt = encodeURIComponent(
      L ? `Моя скорость печати: ${s.net} зн/мин, точность ${s.accuracy}%! А ты сможешь быстрее?`
        : `My typing speed: ${s.net} WPM, ${s.accuracy}% accuracy! Can you beat it?`
    );
    box.innerHTML =
      `<div style="display:flex;gap:8px;margin-bottom:8px">
         <input id="sh-url" readonly value="${esc(url)}" style="flex:1;padding:9px 11px;border-radius:8px;border:1px solid var(--line,#3a4152);background:var(--surface,#1a2233);color:inherit;font-size:13px"/>
         <button id="sh-copy">${L ? 'Копировать' : 'Copy'}</button>
       </div>
       <div style="display:flex;gap:8px;flex-wrap:wrap">
         <a class="sh-soc" href="https://t.me/share/url?url=${enc}&text=${txt}" target="_blank" rel="noopener">Telegram</a>
         <a class="sh-soc" href="https://vk.com/share.php?url=${enc}" target="_blank" rel="noopener">ВКонтакте</a>
       </div>`;
    (document.getElementById('sh-copy') as HTMLButtonElement).onclick = () => {
      const i = document.getElementById('sh-url') as HTMLInputElement;
      i.select();
      navigator.clipboard?.writeText(i.value).then(() => {
        const b = document.getElementById('sh-copy'); if (b) b.textContent = L ? '✓ Скопировано' : '✓ Copied';
      }).catch(() => {});
    };
  };
}

function fmtTime(ms: number): string {
  const sec = Math.ceil(ms / 1000);
  return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
}
function updateExamHud() {
  if (!exam || exam.phase !== 'run') return;
  const tEl = document.getElementById('ex-timer'); const sEl = document.getElementById('ex-hudstats');
  if (!tEl || !sEl) return;
  const s = examStats();
  tEl.textContent = fmtTime(Math.max(0, exam.endAt - Date.now()));
  sEl.innerHTML = `${t('ex.net')} <b>${s.net}</b> · ${t('st.accuracy')} <b>${s.accuracy}%</b> · ${t('ex.target.short')} ${exam.target}`;
}

function downloadCertificate(s: ReturnType<typeof examStats>, pass: boolean) {
  if (!exam) return;
  const c = document.createElement('canvas'); c.width = 1200; c.height = 850;
  const g = c.getContext('2d')!;
  g.fillStyle = '#faf7f0'; g.fillRect(0, 0, 1200, 850);
  g.strokeStyle = '#b9962e'; g.lineWidth = 6; g.strokeRect(30, 30, 1140, 790);
  g.lineWidth = 1.5; g.strokeRect(44, 44, 1112, 762);
  g.fillStyle = '#2a2a33'; g.textAlign = 'center';
  g.font = '700 28px Georgia, serif'; g.fillText('TypeRIGHT', 600, 110);
  g.font = '800 64px Georgia, serif'; g.fillStyle = '#b9962e'; g.fillText(t('ex.cert.title'), 600, 200);
  g.font = '400 26px Georgia, serif'; g.fillStyle = '#555'; g.fillText(t('ex.cert.sub'), 600, 240);
  g.font = '700 52px Georgia, serif'; g.fillStyle = '#2a2a33'; g.fillText(exam.name || '—', 600, 350);
  g.font = '800 110px Georgia, serif'; g.fillStyle = pass ? '#2f7d4f' : '#b3443a'; g.fillText(`${s.net} ${t('ex.net')}`, 600, 500);
  g.font = '400 30px Georgia, serif'; g.fillStyle = '#444';
  g.fillText(`${t('ex.gross')}: ${s.gross}   ·   ${t('st.accuracy')}: ${s.accuracy}%   ·   ${exam.durMin} ${t('ex.min')}`, 600, 570);
  g.font = '700 36px Georgia, serif'; g.fillStyle = pass ? '#2f7d4f' : '#b3443a';
  g.fillText(pass ? `✔ ${t('ex.pass')}` : `✘ ${t('ex.fail')}`, 600, 650);
  g.font = '400 22px Georgia, serif'; g.fillStyle = '#777';
  g.fillText(`${t('ex.cert.date')}: ${new Date().toLocaleDateString()}`, 600, 740);
  const a = document.createElement('a');
  a.download = `TypeRIGHT-test-${s.net}wpm.png`; a.href = c.toDataURL('image/png'); a.click();
}

// ── Спец-режимы ──
function startWeak() {
  special = 'weak'; exam = null;
  weakLines = weakDrill(lang());
  weakNoData = !hasKeyData(3);
  st = createState(flowMode ? [weakLines.join(' ')] : weakLines);
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  render();
}
function startCustom(text: string) {
  customText = text;
  customLines = text.split(/\r?\n/).map((l) => l.trimEnd()).filter((l) => l.length > 0);
  if (customLines.length === 0) return;
  special = 'custom'; exam = null; modal = null;
  st = createState(flowMode ? [customLines.join(' ')] : customLines);
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  render();
}
function exitSpecial() { special = null; loadBank(); }

// хелперы для опциональных элементов (часть кнопок есть только на отдельных экранах)
function onClick(id: string, fn: () => void) { const el = document.getElementById(id); if (el) (el as HTMLButtonElement).onclick = fn; }
function onChange(id: string, fn: (el: HTMLInputElement) => void) { const el = document.getElementById(id) as HTMLInputElement | null; if (el) el.onchange = () => fn(el); }

function bindControls() {
  onChange('bank', (el) => { special = null; bank = el.value as Bank; loadBank(); });
  onClick('weak', () => { special === 'weak' ? exitSpecial() : startWeak(); });
  onClick('custom', () => { modal = 'custom'; render(); });
  onClick('prev', () => { if (special) { nextSpecial(); return; } idx = (idx - 1 + pool.length) % pool.length; reset(); });
  onClick('next', () => { if (special) { nextSpecial(); return; } idx = advanceIdx(); reset(); });
  onClick('again', () => { special ? nextSpecial(true) : reset(); });
  onClick('nextdone', () => { if (special) { nextSpecial(); return; } idx = advanceIdx(); reset(); });
}

// Словесные банки (равная сложность) — случайный порядок; связные тексты (стихи/проза) — последовательно.
const SHUFFLE_BANKS = new Set<Bank>(['abandon', 'engRus', 'ruWords']);
function advanceIdx(): number {
  if (SHUFFLE_BANKS.has(bank) && pool.length > 1) {
    let n = idx; while (n === idx) n = Math.floor(Math.random() * pool.length);
    return n;
  }
  return (idx + 1) % pool.length;   // poemHymn/classic/letterByLetter — по порядку (место остановки в lastIdx)
}

// ── Стартовый хаб «С чего начать?» ──
function renderHub() {
  const streak = streakDays(Date.now());
  const cards: Array<[string, string, string]> = [
    ['train', t('hub.train'), t('hub.train.d')],
    ['course', t('course.title'), t('hub.course.d')],
    ['learn', t('learn.title'), t('hub.learn.d')],
    ['compete', t('compete.title'), t('hub.compete.d')],
    ['exam', t('ex.title'), t('hub.exam.d')],
    ['progress', t('prog.title'), t('hub.progress.d')],
  ];
  app.innerHTML = `
    <div class="wrap hub">
      <header><h1>Type<span>RIGHT</span>ing</h1></header>
      <p class="hub-q">${t('hub.q')}${streak >= 2 ? ` &nbsp;·&nbsp; <b class="streak">🔥 ${streak} ${t('hub.streak')}</b>` : ''}</p>
      <div class="hub-cards">
        ${cards.map(([go, name, desc], i) => `
          <button class="hub-card ${i === 0 ? 'hub-primary' : ''}" data-go="${go}">
            ${modeIcon(go, 'hub-ic')}
            <span class="hub-name">${esc(name)}</span>
            <span class="hub-desc">${esc(desc)}</span>
          </button>`).join('')}
      </div>
    </div>`;
  app.querySelectorAll<HTMLButtonElement>('[data-go]').forEach((b) => {
    b.onclick = () => {
      const go = b.dataset.go!;
      if (go === 'progress') { modal = 'progress'; render(); }
      else goTo(go);
    };
  });
}

function nextSpecial(repeat = false) {
  if (special === 'weak' && !repeat) { startWeak(); return; }
  if (special === 'weak') { startWeak(); return; }
  // custom: повторить тот же текст
  st = createState(flowMode ? [customLines.join(' ')] : customLines);
  render();
}

function loadBank() {
  // мультиязычные банки готовых текстов на языке интерфейса
  pool = bank === 'poemHymn' ? ravenExercises(lang())
       : bank === 'classic' ? classicExercises(lang())
       : bank === 'ruWords' ? ruWordsExercises()
       : bank === 'ruPhrases' ? ruPhrasesExercises()
       : exercisesOfBank(all, bank);
  prog = loadProgress(bank);
  idx = Math.min(Math.max(prog.lastIdx, 0), Math.max(pool.length - 1, 0));
  reset();
}

function exState(ex: Exercise | undefined) {
  if (!ex) return createState(['']);
  return createState(flowMode ? [ex.lines.join(' ')] : ex.lines);
}
function reset() {
  st = exState(pool[idx]);
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  if (prog.lastIdx !== idx) { prog.lastIdx = idx; saveProgress(); }
  render();
}

// ── Ввод с клавиатуры ──
document.addEventListener('keydown', (e) => {
  const tag = (e.target as HTMLElement)?.tagName;
  if (tag === 'SELECT' || tag === 'INPUT' || tag === 'TEXTAREA') return;
  // Компаньон: первый реальный физ-keydown (печатный символ с реальным кодом, не IME 229) =
  // подключена BT-клавиатура → открываем полный тренажёр. Tab/Enter (не length-1) не трогаем.
  if (companionMode) {
    if (e.key && e.key.length === 1 && e.keyCode !== 229 && !e.ctrlKey && !e.metaKey && !e.altKey) {
      e.preventDefault(); openTrainerFromCompanion();
    }
    return;
  }
  if (modal) { if (e.key === 'Escape') { modal = null; render(); } return; }
  if (courseMode) { courseHandleKey(e); return; }
  if (aiMode) { learnHandleKey(e); return; }
  if (compMode) { competeHandleKey(e); return; }
  if (memMode) { memorizeHandleKey(e); return; }
  if (spanMode) { recallHandleKey(e); return; }
  if (profile === 'kids') { kidsHandleKey(e); return; }
  if (exam && exam.phase !== 'run') return;
  if (st.finishedAt !== null) return;

  if (e.key === 'Backspace') {
    e.preventDefault();
    if (exam || !blockOnError) { backspace(st); render(); }
    return;
  }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;

  e.preventDefault();
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  const rc = ruCtx();

  if (exam) {
    const r = pressChar(st, ch, false);
    statTrack(expected, r.wrong, rc);
    if (r.wrong) beep();
    if (r.finished) {
      const s = stats(st);
      exam.typed += s.typed; exam.errors += s.errors; exam.count++;
      exam.pi = (exam.pi + 1) % exam.pool.length;
      st = createState([exam.pool[exam.pi].lines.join(' ')]);
    }
    render();
    return;
  }

  if (st.startedAt === null && !statsTimer) {
    statsTimer = window.setInterval(() => { if (st.finishedAt === null) updateStatsOnly(); }, 250);
  }
  const r = pressChar(st, ch, blockOnError);
  statTrack(expected, r.wrong, rc);
  if (r.wrong) beep();
  if (r.finished) {
    const s = stats(st);
    if (flowMode && !special) {
      const ex = pool[idx];
      flow.typed += s.typed; flow.errors += s.errors; flow.ms += s.elapsedMs; flow.count++;
      if (ex && !prog.done.includes(ex.id)) prog.done.push(ex.id);
      idx = (idx + 1) % pool.length; prog.lastIdx = idx; saveProgress();
      st = exState(pool[idx]);
    } else {
      if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
      pushHistory(s.wpm, s.accuracy, Date.now()); notifyBadges();
      if (!special) { const ex = pool[idx]; if (ex) recordFinish(ex); }
    }
  }
  render();
});

// фиксируем per-key статистику только для печатных небелых символов
function statTrack(expected: string, wrong: boolean, rc: boolean) {
  if (!expected || expected === '\n' || expected === ' ') return;
  const id = keyIdFor(expected, rc);
  if (id) recordKey(id, !wrong);
}

function updateStatsOnly() {
  const bar = document.querySelector('.statsbar');
  if (bar) bar.innerHTML = statsCells(viewStats());
}

// ── Старт ──
applyProfile(profile);
applyDark();
// Адаптивный старт: телефон без физ-клавиатуры → компаньон, если пользователь не выбрал тренажёр явно.
try {
  const savedMode = localStorage.getItem('tr_mode');
  if (savedMode !== 'trainer' && (savedMode === 'companion' || isPhoneNoKeyboard())) {
    companionMode = true; hubMode = false;
  }
} catch { /* localStorage off */ }
loadExercises().then((data) => { all = data; loadBank(); }).catch((err) => {
  app.innerHTML = `<div class="wrap"><p class="err">${t('err.load')}: ${esc(String(err))}</p></div>`;
});
// тихо подтянуть облачный прогресс при старте, если вошёл в аккаунт
void autoSync().then((ok) => { if (ok) { reapplyGlobal(); renderTopbar(); } });
// авто-проверка обновлений — только в нативном приложении (в браузере/PWA молча выходит)
void checkForUpdate();
// P2: вход по ссылке-вызову ?challenge=<id> → грузим вызов и открываем соревнование
void (async () => {
  const cid = new URLSearchParams(location.search).get('challenge');
  if (!cid || !/^[0-9a-f-]{36}$/i.test(cid)) return;
  const ch = await getChallenge(cid);
  if (ch) { pendingChallenge = ch; compMode = true; compInit = false; render(); }
})();
