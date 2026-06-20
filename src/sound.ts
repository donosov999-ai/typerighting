// Звуки тренажёра — Web Audio синтез (без файлов), тихо по умолчанию (выбор Дениса).
// Общий тумблер — settings «Звук» (soundOn) пробрасывается через setSoundEnabled.
let ctx: AudioContext | null = null;
let enabled: () => boolean = () => true;
export function setSoundEnabled(fn: () => boolean) { enabled = fn; }

const VOL = 0.05; // тихо

// AudioContext создаётся suspended (политика автоплея) — нужен resume() после жеста.
function ensureCtx(): AudioContext {
  ctx ??= new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
  if (ctx.state === 'suspended') void ctx.resume();
  return ctx;
}
// разблокировать звук на ПЕРВОЕ взаимодействие (печать/клик) — иначе тишина
if (typeof document !== 'undefined') {
  const unlock = () => { try { ensureCtx(); } catch { /* */ } };
  (['keydown', 'pointerdown', 'touchstart'] as const).forEach((e) => document.addEventListener(e, unlock, { passive: true }));
}

function tone(freq: number, start: number, dur: number, vol = VOL, type: OscillatorType = 'sine') {
  try {
    const c = ensureCtx();
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.value = freq;
    o.connect(g); g.connect(c.destination);
    const t0 = c.currentTime + start;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(vol, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.start(t0); o.stop(t0 + dur + 0.03);
  } catch { /* нет аудио — молча */ }
}
function play(fn: () => void) { if (enabled()) fn(); }

export const sfx = {
  // конец упражнения/строки — короткий приятный взлёт
  success: () => play(() => { [523.25, 659.25].forEach((f, i) => tone(f, i * 0.08, 0.16)); }),
  // уровень пройден — мини-фанфары
  fanfare: () => play(() => { [523.25, 587.33, 659.25, 783.99, 1046.5].forEach((f, i) => tone(f, i * 0.1, 0.22, 0.06)); }),
  // звезда получена — звон
  star: () => play(() => { [1318.5, 1760].forEach((f, i) => tone(f, i * 0.07, 0.14, 0.05, 'triangle')); }),
  // старт раунда / обратный отсчёт показа (Память)
  start: () => play(() => { tone(440, 0, 0.1, 0.04); tone(660, 0.08, 0.12, 0.04); }),
  // повышение уровня сложности (AI-лесенка)
  upgrade: () => play(() => { [659.25, 880, 1108.7].forEach((f, i) => tone(f, i * 0.06, 0.14, 0.05, 'triangle')); }),
  // рекорд WPM — триумф
  record: () => play(() => { [659.25, 880, 1046.5, 1318.5].forEach((f, i) => tone(f, i * 0.09, 0.2, 0.06, 'triangle')); }),
  // котик радуется (мяу вверх) / грустит (вниз) — детский
  catHappy: () => play(() => { tone(700, 0, 0.1, 0.05); tone(1000, 0.07, 0.14, 0.05); }),
  catSad: () => play(() => { tone(420, 0, 0.12, 0.05); tone(280, 0.09, 0.18, 0.05); }),
};

// ── Метроном (опция): ровный тик для удержания темпа печати ──
function tick() {
  try {
    ensureCtx();
    const o = ctx!.createOscillator(), g = ctx!.createGain();
    o.type = 'square'; o.frequency.value = 1600;
    o.connect(g); g.connect(ctx!.destination);
    const t0 = ctx!.currentTime;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(0.05, t0 + 0.004);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.05);
    o.start(t0); o.stop(t0 + 0.06);
  } catch { /* нет аудио */ }
}
let metroTimer: number | null = null;
export const metronome = {
  start(bpm: number) {
    this.stop();
    const ms = 60000 / Math.max(40, Math.min(240, bpm));
    tick();
    metroTimer = window.setInterval(tick, ms);
  },
  stop() { if (metroTimer) { clearInterval(metroTimer); metroTimer = null; } },
  running(): boolean { return metroTimer !== null; },
};
