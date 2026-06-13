import './style.css';
import { loadExercises, exercisesOfBank, BANKS, type Bank, type Exercise } from './content';
import { createState, pressChar, backspace, stats, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { type Profile, PROFILE_EMOJI, loadProfile, saveProfile, applyProfile } from './profiles';
import { kidsEnter, kidsHandleKey } from './kids';
import { courseEnter, courseHandleKey } from './course';
import { learnEnter, learnHandleKey } from './learn';
import { t, lang, setLang, type Lang } from './i18n';
import { recordKey, heatMap, hasKeyData, weakDrill, pushHistory, progressSVG } from './stats-store';

// ── Состояние сессии ──
let profile: Profile | null = loadProfile();
let all: Exercise[] = [];
let bank: Bank = 'abandon';
let pool: Exercise[] = [];
let idx = 0;
let st: TypingState = createState(['']);
let hidePattern = false;
let soundOn = true;
let blockOnError = true;
let showKeyb = true; // схема клавиатуры из оригинального TypeRIGHTing
let showHeat = localStorage.getItem('tr_heat') === '1'; // тепловая карта клавиш
let dark = localStorage.getItem('tr_dark') === '1';      // тёмная тема (опция)
let statsTimer: number | null = null;

// Спец-режимы: 'weak' (адаптив по слабым клавишам) / 'custom' (свой текст)
let special: null | 'weak' | 'custom' = null;
let customText = '';
let modal: null | 'custom' | 'progress' = null;

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
  render();
}

function exitExam() {
  if (exam?.timer) clearInterval(exam.timer);
  exam = null;
  reset();
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
  if (s.wpm > prog.bestWpm) prog.bestWpm = s.wpm;
  if (s.accuracy > prog.bestAcc) prog.bestAcc = s.accuracy;
  if (!prog.done.includes(ex.id)) prog.done.push(ex.id);
  saveProgress();
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

function ruCtx(): boolean { return /[а-яё]/i.test(st.pattern); }
function kbShowRu(rc: boolean): boolean { return lang() === 'ru' || rc; }

function applyDark() {
  if (dark) document.documentElement.dataset.theme = 'dark';
  else delete document.documentElement.dataset.theme;
}

function langSwitcherHtml(): string {
  return `<select id="lang" title="Language">
    <option value="ru" ${lang() === 'ru' ? 'selected' : ''}>RU</option>
    <option value="en" ${lang() === 'en' ? 'selected' : ''}>EN</option>
  </select>`;
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

function render() {
  if (profile === null) { kidsActive = false; renderOnboarding(); return; }
  if (aiMode) {
    if (!aiInit) { aiInit = true; learnEnter(app, profile ?? 'm', () => { aiMode = false; aiInit = false; render(); }); }
    return; // AI-режим рисует себя сам (учитывает профиль, в т.ч. детский)
  }
  aiInit = false;
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
  const ex = curExercise();
  const s = viewStats();
  const inSpecial = special !== null;
  app.innerHTML = `
    <div class="wrap">
      <header>
        <h1>Type<span>RIGHT</span>ing</h1>
        <div class="headctl">
          <select id="bank">
            ${BANKS.map((b) => `<option value="${b}" ${b === bank && !inSpecial ? 'selected' : ''}>${t('bank.' + b)}</option>`).join('')}
          </select>
          <select id="profile" title="Profile">
            ${(Object.keys(PROFILE_EMOJI) as Profile[]).map((p) => `<option value="${p}" ${p === profile ? 'selected' : ''}>${PROFILE_EMOJI[p]} ${t('profile.' + p)}</option>`).join('')}
          </select>
          <button id="dark" class="iconbtn" title="${t('tb.dark')}">${dark ? '☀️' : '🌙'}</button>
          ${langSwitcherHtml()}
        </div>
      </header>
      <p class="bankdesc">${inSpecial ? (special === 'weak' ? t('weak.hint') : '') : t('bank.' + bank + '.desc')} ${inSpecial ? '' : `· <b>${pool.length}</b> ${t('st.exercises')} · ${t('st.done')} <b>${prog.done.length}</b>${prog.bestWpm > 0 ? ` · ${t('st.record')} <b>${prog.bestWpm}</b> ${t('st.wpm')} · <b>${prog.bestAcc}%</b>` : ''}`}</p>

      <div class="toolbar">
        <label><input type="checkbox" id="hide" ${hidePattern ? 'checked' : ''}/> ${t('tb.hide')}</label>
        <label><input type="checkbox" id="sound" ${soundOn ? 'checked' : ''}/> ${t('tb.sound')}</label>
        <label><input type="checkbox" id="block" ${blockOnError ? 'checked' : ''}/> ${t('tb.block')}</label>
        <label><input type="checkbox" id="keyb" ${showKeyb ? 'checked' : ''}/> ${t('tb.keyb')}</label>
        <label title="errRate"><input type="checkbox" id="heat" ${showHeat ? 'checked' : ''}/> ${t('tb.heat')}</label>
        <label title="Stamina-style"><input type="checkbox" id="flow" ${flowMode ? 'checked' : ''}/> ${t('tb.flow')}</label>
        <span class="spacer"></span>
        <button id="prev" class="ghost">${t('tb.prev')}</button>
        <span class="counter">${inSpecial ? '•' : `${idx + 1} / ${pool.length}`}</span>
        <button id="next" class="ghost">${t('tb.next')}</button>
      </div>

      <div class="toolbar toolbar2">
        <button id="learn" class="ghost">${t('tb.learn')}</button>
        <button id="course" class="ghost">${t('tb.course')}</button>
        <button id="weak" class="ghost ${special === 'weak' ? 'on' : ''}">${t('tb.weak')}</button>
        <button id="custom" class="ghost ${special === 'custom' ? 'on' : ''}">${t('tb.custom')}</button>
        <button id="progress" class="ghost">${t('tb.progress')}</button>
        <button id="exam" class="ghost">⏱ ${t('tb.exam')}</button>
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
    ${modal ? renderModal() : ''}
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
        <button id="ex-retry">${t('ex.again')}</button>
        <button id="ex-exit" class="ghost">${t('ex.cancel')}</button>
      </div>
    </div></div>`;
  (document.getElementById('ex-cert') as HTMLButtonElement).onclick = () => downloadCertificate(s, pass);
  (document.getElementById('ex-retry') as HTMLButtonElement).onclick = () => { exam!.phase = 'setup'; render(); };
  (document.getElementById('ex-exit') as HTMLButtonElement).onclick = () => exitExam();
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
  g.font = '700 28px Georgia, serif'; g.fillText('TypeRIGHTing', 600, 110);
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
  a.download = `TypeRIGHTing-test-${s.net}wpm.png`; a.href = c.toDataURL('image/png'); a.click();
}

// ── Спец-режимы ──
function startWeak() {
  special = 'weak'; exam = null;
  weakLines = weakDrill(lang() === 'ru' ? 'ru' : 'en');
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

function bindControls() {
  (document.getElementById('bank') as HTMLSelectElement).onchange = (e) => {
    special = null; bank = (e.target as HTMLSelectElement).value as Bank; loadBank();
  };
  (document.getElementById('profile') as HTMLSelectElement).onchange = (e) => {
    profile = (e.target as HTMLSelectElement).value as Profile; saveProfile(profile); render();
  };
  (document.getElementById('dark') as HTMLButtonElement).onclick = () => {
    dark = !dark; try { localStorage.setItem('tr_dark', dark ? '1' : '0'); } catch { /* quota */ }
    applyDark(); render();
  };
  bindLang(() => render());
  document.getElementById('hide')!.onchange = (e) => { hidePattern = (e.target as HTMLInputElement).checked; render(); };
  document.getElementById('sound')!.onchange = (e) => { soundOn = (e.target as HTMLInputElement).checked; };
  document.getElementById('block')!.onchange = (e) => { blockOnError = (e.target as HTMLInputElement).checked; };
  document.getElementById('keyb')!.onchange = (e) => { showKeyb = (e.target as HTMLInputElement).checked; render(); };
  document.getElementById('heat')!.onchange = (e) => { showHeat = (e.target as HTMLInputElement).checked; try { localStorage.setItem('tr_heat', showHeat ? '1' : '0'); } catch { /* */ } render(); };
  document.getElementById('flow')!.onchange = (e) => {
    flowMode = (e.target as HTMLInputElement).checked;
    try { localStorage.setItem('tr_flow', flowMode ? '1' : '0'); } catch { /* quota */ }
    flowReset();
    if (special) { special === 'weak' ? startWeak() : startCustom(customText); } else reset();
  };
  document.getElementById('learn')!.onclick = () => { special = null; exam = null; aiMode = true; if (statsTimer) { clearInterval(statsTimer); statsTimer = null; } render(); };
  document.getElementById('course')!.onclick = () => { special = null; exam = null; courseMode = true; if (statsTimer) { clearInterval(statsTimer); statsTimer = null; } render(); };
  document.getElementById('weak')!.onclick = () => { special === 'weak' ? exitSpecial() : startWeak(); };
  document.getElementById('custom')!.onclick = () => { modal = 'custom'; render(); };
  document.getElementById('progress')!.onclick = () => { modal = 'progress'; render(); };
  document.getElementById('exam')!.onclick = () => {
    special = null;
    exam = { phase: 'setup', durMin: 10, target: 35, name: '', endAt: 0, typed: 0, errors: 0, count: 0, pool: [], pi: 0, timer: null };
    if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
    render();
  };
  document.getElementById('prev')!.onclick = () => { if (special) { nextSpecial(); return; } idx = (idx - 1 + pool.length) % pool.length; reset(); };
  document.getElementById('next')!.onclick = () => { if (special) { nextSpecial(); return; } idx = (idx + 1) % pool.length; reset(); };
  const again = document.getElementById('again'); if (again) again.onclick = () => { special ? nextSpecial(true) : reset(); };
  const nd = document.getElementById('nextdone'); if (nd) nd.onclick = () => { if (special) { nextSpecial(); return; } idx = (idx + 1) % pool.length; reset(); };
  // модалки
  const mb = document.getElementById('modal-bg');
  if (mb) mb.onclick = (e) => { if (e.target === mb) { modal = null; render(); } };
  const cg = document.getElementById('custom-go'); if (cg) cg.onclick = () => startCustom((document.getElementById('custom-ta') as HTMLTextAreaElement).value);
  const cc = document.getElementById('custom-cancel'); if (cc) cc.onclick = () => { modal = null; render(); };
  const pc = document.getElementById('prog-close'); if (pc) pc.onclick = () => { modal = null; render(); };
}

function nextSpecial(repeat = false) {
  if (special === 'weak' && !repeat) { startWeak(); return; }
  if (special === 'weak') { startWeak(); return; }
  // custom: повторить тот же текст
  st = createState(flowMode ? [customLines.join(' ')] : customLines);
  render();
}

function loadBank() {
  pool = exercisesOfBank(all, bank);
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
  if (modal) { if (e.key === 'Escape') { modal = null; render(); } return; }
  if (courseMode) { courseHandleKey(e); return; }
  if (aiMode) { learnHandleKey(e); return; }
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
      pushHistory(s.wpm, s.accuracy, Date.now());
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
loadExercises().then((data) => { all = data; loadBank(); }).catch((err) => {
  app.innerHTML = `<div class="wrap"><p class="err">${t('err.load')}: ${esc(String(err))}</p></div>`;
});
