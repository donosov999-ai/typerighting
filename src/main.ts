import './style.css';
import { loadExercises, exercisesOfBank, BANK_LABELS, BANK_DESC, type Bank, type Exercise } from './content';
import { createState, pressChar, backspace, stats, MARK, type TypingState } from './typing';
import { keyboardSVG } from './keyboard';
import { type Profile, PROFILE_META, loadProfile, saveProfile, applyProfile, doneTitle } from './profiles';

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
let statsTimer: number | null = null;

// ── Прогресс по банку (Задача 3 ТЗ): ключ tr_progress_<bank> ──
interface Progress {
  bestWpm: number;   // лучшая скорость (зн/мин ÷5)
  bestAcc: number;   // лучшая точность, %
  done: string[];    // id пройденных упражнений (без дублей)
  lastIdx: number;   // продолжить с места
}
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

// ── Звук ошибки (Web Audio, без внешних файлов) ──
let audioCtx: AudioContext | null = null;
function beep() {
  if (!soundOn) return;
  try {
    audioCtx ??= new AudioContext();
    const o = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    o.frequency.value = 220;
    o.type = 'square';
    g.gain.value = 0.06;
    o.connect(g); g.connect(audioCtx.destination);
    o.start();
    o.stop(audioCtx.currentTime + 0.07);
  } catch { /* no audio */ }
}

const app = document.getElementById('app')!;

function render() {
  if (profile === null) { renderOnboarding(); return; }
  const ex = pool[idx];
  const s = stats(st);
  app.innerHTML = `
    <div class="wrap">
      <header>
        <h1>Type<span>RIGHT</span>ing</h1>
        <div class="headctl">
          <select id="bank">
            ${(Object.keys(BANK_LABELS) as Bank[]).map((b) =>
              `<option value="${b}" ${b === bank ? 'selected' : ''}>${BANK_LABELS[b]}</option>`).join('')}
          </select>
          <select id="profile" title="Профиль">
            ${(Object.keys(PROFILE_META) as Profile[]).map((p) =>
              `<option value="${p}" ${p === profile ? 'selected' : ''}>${PROFILE_META[p].emoji} ${PROFILE_META[p].label}</option>`).join('')}
          </select>
        </div>
      </header>
      <p class="bankdesc">${BANK_DESC[bank]} · <b>${pool.length}</b> упражнений
        · пройдено <b>${prog.done.length}</b>${prog.bestWpm > 0 ? ` · рекорд <b>${prog.bestWpm}</b> зн/мин · <b>${prog.bestAcc}%</b>` : ''}</p>

      <div class="toolbar">
        <label><input type="checkbox" id="hide" ${hidePattern ? 'checked' : ''}/> Спрятать образец</label>
        <label><input type="checkbox" id="sound" ${soundOn ? 'checked' : ''}/> Звук ошибки</label>
        <label><input type="checkbox" id="block" ${blockOnError ? 'checked' : ''}/> Блок при ошибке</label>
        <label><input type="checkbox" id="keyb" ${showKeyb ? 'checked' : ''}/> Клавиатура</label>
        <span class="spacer"></span>
        <button id="prev" class="ghost">‹ Пред</button>
        <span class="counter">${idx + 1} / ${pool.length}</span>
        <button id="next" class="ghost">След ›</button>
      </div>

      <div class="card">
        <div class="exhead">
          <span class="extitle">${esc(ex?.title ?? '')}</span>
          ${ex?.hint ? `<span class="exhint">${esc(ex.hint)}</span>` : ''}
        </div>
        <div class="pattern ${hidePattern ? 'hidden' : ''}" id="pattern">${renderPattern()}</div>
      </div>

      ${showKeyb ? `<div class="keyb">${keyboardSVG(
        st.finishedAt === null ? st.pattern[st.pos] ?? null : null,
        /[а-яё]/i.test(st.pattern),
      )}</div>` : ''}

      <div class="statsbar">
        <div><b>${s.wpm}</b><span>зн/мин ÷5</span></div>
        <div><b>${s.accuracy}%</b><span>точность</span></div>
        <div><b class="${s.errors > 0 ? 'err' : ''}">${s.errors}</b><span>ошибок</span></div>
        <div><b>${(s.elapsedMs / 1000).toFixed(0)}с</b><span>время</span></div>
      </div>

      ${st.finishedAt !== null ? renderDone(s) : `<p class="hint2">Печатай по образцу. ${blockOnError ? 'Неверный символ не пропускается.' : 'Backspace — исправить.'}</p>`}
    </div>
  `;
  bindControls();
}

function esc(s: string) {
  return s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
}

function renderPattern(): string {
  if (hidePattern) return '<span class="hidden-note">образец скрыт — печатай по памяти</span>';
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const ch = st.pattern[i];
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    if (ch === '\n') { html += `<span class="${cls} nl">↵</span><br/>`; }
    else { html += `<span class="${cls}">${esc(ch)}</span>`; }
  }
  return html;
}

function renderOnboarding() {
  app.innerHTML = `
    <div class="wrap onboard">
      <h1 class="ob-title">Type<span>RIGHT</span>ing</h1>
      <p class="ob-sub">Тренажёр слепой печати. Для кого настроить?</p>
      <div class="ob-cards">
        ${(Object.keys(PROFILE_META) as Profile[]).map((p) => `
          <button class="ob-card" data-profile-pick="${p}">
            <span class="ob-emoji">${PROFILE_META[p].emoji}</span>
            <span class="ob-name">${PROFILE_META[p].label}</span>
            <span class="ob-desc">${PROFILE_META[p].desc}</span>
          </button>`).join('')}
      </div>
      <p class="ob-note">Профиль можно сменить в любой момент в шапке.</p>
    </div>`;
  app.querySelectorAll<HTMLButtonElement>('[data-profile-pick]').forEach((btn) => {
    btn.onclick = () => { profile = btn.dataset.profilePick as Profile; saveProfile(profile); render(); };
  });
}

function renderDone(s: ReturnType<typeof stats>): string {
  return `
    <div class="done">
      <h2>${doneTitle(profile)}</h2>
      <div class="donestats">
        <span><b>${s.wpm}</b> зн/мин÷5</span>
        <span><b>${s.accuracy}%</b> точность</span>
        <span><b>${s.errors}</b> ошибок</span>
        <span><b>${(s.elapsedMs / 1000).toFixed(1)}с</b></span>
      </div>
      <div class="donebtns">
        <button id="again">↻ Заново</button>
        <button id="nextdone" class="primary">Следующее →</button>
      </div>
    </div>`;
}

function bindControls() {
  (document.getElementById('bank') as HTMLSelectElement).onchange = (e) => {
    bank = (e.target as HTMLSelectElement).value as Bank;
    loadBank();
  };
  (document.getElementById('profile') as HTMLSelectElement).onchange = (e) => {
    profile = (e.target as HTMLSelectElement).value as Profile;
    saveProfile(profile);
    render();
  };
  document.getElementById('hide')!.onchange = (e) => { hidePattern = (e.target as HTMLInputElement).checked; render(); };
  document.getElementById('sound')!.onchange = (e) => { soundOn = (e.target as HTMLInputElement).checked; };
  document.getElementById('block')!.onchange = (e) => { blockOnError = (e.target as HTMLInputElement).checked; };
  document.getElementById('keyb')!.onchange = (e) => { showKeyb = (e.target as HTMLInputElement).checked; render(); };
  document.getElementById('prev')!.onclick = () => { idx = (idx - 1 + pool.length) % pool.length; reset(); };
  document.getElementById('next')!.onclick = () => { idx = (idx + 1) % pool.length; reset(); };
  const again = document.getElementById('again'); if (again) again.onclick = () => reset();
  const nd = document.getElementById('nextdone'); if (nd) nd.onclick = () => { idx = (idx + 1) % pool.length; reset(); };
}

function loadBank() {
  pool = exercisesOfBank(all, bank);
  prog = loadProgress(bank);
  idx = Math.min(Math.max(prog.lastIdx, 0), Math.max(pool.length - 1, 0)); // продолжить с места
  reset();
}

function reset() {
  const ex = pool[idx];
  st = createState(ex ? ex.lines : ['']);
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
  if (prog.lastIdx !== idx) { prog.lastIdx = idx; saveProgress(); }
  render();
}

// ── Ввод с клавиатуры ──
document.addEventListener('keydown', (e) => {
  if (st.finishedAt !== null) return;
  const tag = (e.target as HTMLElement)?.tagName;
  if (tag === 'SELECT' || tag === 'INPUT') return; // не перехватываем настройки

  if (e.key === 'Backspace') {
    e.preventDefault();
    if (!blockOnError) { backspace(st); render(); }
    return;
  }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;

  e.preventDefault();
  if (st.startedAt === null && !statsTimer) {
    statsTimer = window.setInterval(() => { if (st.finishedAt === null) updateStatsOnly(); }, 250);
  }
  const r = pressChar(st, ch, blockOnError);
  if (r.wrong) beep();
  if (r.finished) {
    if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
    const ex = pool[idx];
    if (ex) recordFinish(ex);
  }
  render();
});

// лёгкое обновление статистики без полного перерендера паттерна (таймер)
function updateStatsOnly() {
  const s = stats(st);
  const bar = document.querySelector('.statsbar');
  if (!bar) return;
  bar.innerHTML = `
    <div><b>${s.wpm}</b><span>зн/мин ÷5</span></div>
    <div><b>${s.accuracy}%</b><span>точность</span></div>
    <div><b class="${s.errors > 0 ? 'err' : ''}">${s.errors}</b><span>ошибок</span></div>
    <div><b>${(s.elapsedMs / 1000).toFixed(0)}с</b><span>время</span></div>`;
}

// ── Старт ──
applyProfile(profile);
loadExercises().then((data) => {
  all = data;
  loadBank();
}).catch((err) => {
  app.innerHTML = `<div class="wrap"><p class="err">Не удалось загрузить упражнения: ${esc(String(err))}</p></div>`;
});
