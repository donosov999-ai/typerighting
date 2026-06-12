import './style.css';
import { loadExercises, exercisesOfBank, BANK_LABELS, BANK_DESC, type Bank, type Exercise } from './content';
import { createState, pressChar, backspace, stats, MARK, type TypingState } from './typing';

// ── Состояние сессии ──
let all: Exercise[] = [];
let bank: Bank = 'abandon';
let pool: Exercise[] = [];
let idx = 0;
let st: TypingState = createState(['']);
let hidePattern = false;
let soundOn = true;
let blockOnError = true;
let statsTimer: number | null = null;

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
  const ex = pool[idx];
  const s = stats(st);
  app.innerHTML = `
    <div class="wrap">
      <header>
        <h1>Type<span>RIGHT</span>ing</h1>
        <select id="bank">
          ${(Object.keys(BANK_LABELS) as Bank[]).map((b) =>
            `<option value="${b}" ${b === bank ? 'selected' : ''}>${BANK_LABELS[b]}</option>`).join('')}
        </select>
      </header>
      <p class="bankdesc">${BANK_DESC[bank]} · <b>${pool.length}</b> упражнений</p>

      <div class="toolbar">
        <label><input type="checkbox" id="hide" ${hidePattern ? 'checked' : ''}/> Спрятать образец</label>
        <label><input type="checkbox" id="sound" ${soundOn ? 'checked' : ''}/> Звук ошибки</label>
        <label><input type="checkbox" id="block" ${blockOnError ? 'checked' : ''}/> Блок при ошибке</label>
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

function renderDone(s: ReturnType<typeof stats>): string {
  return `
    <div class="done">
      <h2>✓ Готово</h2>
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
  document.getElementById('hide')!.onchange = (e) => { hidePattern = (e.target as HTMLInputElement).checked; render(); };
  document.getElementById('sound')!.onchange = (e) => { soundOn = (e.target as HTMLInputElement).checked; };
  document.getElementById('block')!.onchange = (e) => { blockOnError = (e.target as HTMLInputElement).checked; };
  document.getElementById('prev')!.onclick = () => { idx = (idx - 1 + pool.length) % pool.length; reset(); };
  document.getElementById('next')!.onclick = () => { idx = (idx + 1) % pool.length; reset(); };
  const again = document.getElementById('again'); if (again) again.onclick = () => reset();
  const nd = document.getElementById('nextdone'); if (nd) nd.onclick = () => { idx = (idx + 1) % pool.length; reset(); };
}

function loadBank() {
  pool = exercisesOfBank(all, bank);
  idx = 0;
  reset();
}

function reset() {
  const ex = pool[idx];
  st = createState(ex ? ex.lines : ['']);
  if (statsTimer) { clearInterval(statsTimer); statsTimer = null; }
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
  if (r.finished && statsTimer) { clearInterval(statsTimer); statsTimer = null; }
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
loadExercises().then((data) => {
  all = data;
  loadBank();
}).catch((err) => {
  app.innerHTML = `<div class="wrap"><p class="err">Не удалось загрузить упражнения: ${esc(String(err))}</p></div>`;
});
