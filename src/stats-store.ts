// Долгосрочная статистика (доработки 13.06.2026 по запросу Дениса):
//  • per-key статистика → тепловая карта + адаптивный режим «слабые клавиши»
//  • история сессий → график прогресса по дням
// Всё в localStorage, без сервера.
import { letterKeys } from './keyboard';

// ── Per-key: keyId → {ok, err} ──
type KeyStat = { ok: number; err: number };
const KS_KEY = 'tr_keystats';
let keystats: Record<string, KeyStat> = load();

function load(): Record<string, KeyStat> {
  try {
    const o = JSON.parse(localStorage.getItem(KS_KEY) ?? '{}');
    return o && typeof o === 'object' ? o : {};
  } catch { return {}; }
}
let saveTimer: number | null = null;
function persist() {
  // батчим запись (вызывается на каждое нажатие)
  if (saveTimer) return;
  saveTimer = window.setTimeout(() => {
    saveTimer = null;
    try { localStorage.setItem(KS_KEY, JSON.stringify(keystats)); } catch { /* quota */ }
  }, 800);
}

export function recordKey(keyId: string, ok: boolean) {
  const s = keystats[keyId] ?? (keystats[keyId] = { ok: 0, err: 0 });
  if (ok) s.ok++; else s.err++;
  persist();
}

/** errRate по клавишам с достаточными данными — для тепловой карты. */
export function heatMap(minSamples = 6): Record<string, number> {
  const heat: Record<string, number> = {};
  for (const [id, s] of Object.entries(keystats)) {
    const n = s.ok + s.err;
    if (n >= minSamples) heat[id] = s.err / n;
  }
  return heat;
}

export function hasKeyData(minSamples = 6): boolean {
  return Object.values(keystats).some((s) => s.ok + s.err >= minSamples);
}

/** Топ слабых клавиш (по errRate, затем по объёму) для адаптивного режима. */
export function weakKeys(lang: 'en' | 'ru', count = 6): string[] {
  const letters = letterKeys(lang);
  const scored = letters
    .map(({ id, ch }) => {
      const s = keystats[id]; const n = s ? s.ok + s.err : 0;
      const rate = n >= 3 ? s!.err / n : 0;
      return { ch, rate, n };
    })
    .filter((x) => x.rate > 0)
    .sort((a, b) => b.rate - a.rate || b.n - a.n);
  return scored.slice(0, count).map((x) => x.ch);
}

/** Веса букв для n-граммного генератора: слабые (по errRate) встречаются чаще. */
export function letterWeights(lang: 'en' | 'ru', boost = 6): Record<string, number> {
  const heat = heatMap(4);
  const w: Record<string, number> = {};
  for (const { id, ch } of letterKeys(lang)) {
    const rate = heat[id]; // errRate 0..1 или undefined
    if (rate !== undefined && rate > 0) w[ch] = 1 + rate * boost;
  }
  return w;
}

/** Сгенерировать адаптивные строки из слабых букв + домашнего ряда. */
export function weakDrill(lang: 'en' | 'ru', lines = 5): string[] {
  let weak = weakKeys(lang, 6);
  const home = lang === 'en' ? ['a', 's', 'd', 'f', 'j', 'k', 'l'] : ['ф', 'ы', 'в', 'а', 'о', 'л', 'д'];
  if (weak.length === 0) weak = home.slice(0, 4); // нет данных — тренируем домашний ряд
  const pool = [...weak, ...weak, ...home]; // слабые встречаются чаще
  // детерминированный псевдослучай (Math.random есть в браузере, не в воркфлоу)
  const pick = () => pool[Math.floor(Math.random() * pool.length)];
  const out: string[] = [];
  for (let l = 0; l < lines; l++) {
    const words: string[] = [];
    for (let w = 0; w < 6; w++) {
      const len = 3 + Math.floor(Math.random() * 3);
      let s = '';
      for (let i = 0; i < len; i++) s += pick();
      words.push(s);
    }
    out.push(words.join(' '));
  }
  return out;
}

// ── История сессий: график прогресса ──
export type HistPoint = { t: number; wpm: number; acc: number };
const H_KEY = 'tr_history';

export function pushHistory(wpm: number, acc: number, now: number) {
  if (wpm <= 0) return;
  let h: HistPoint[] = [];
  try { h = JSON.parse(localStorage.getItem(H_KEY) ?? '[]'); } catch { h = []; }
  if (!Array.isArray(h)) h = [];
  h.push({ t: now, wpm, acc });
  if (h.length > 300) h = h.slice(h.length - 300);
  try { localStorage.setItem(H_KEY, JSON.stringify(h)); } catch { /* quota */ }
}

export function history(): HistPoint[] {
  try {
    const h = JSON.parse(localStorage.getItem(H_KEY) ?? '[]');
    return Array.isArray(h) ? h : [];
  } catch { return []; }
}

/** Дней подряд с активностью (стрик, как в Duolingo). now — Date.now(). */
export function streakDays(now: number): number {
  const h = history();
  if (!h.length) return 0;
  const days = new Set(h.map((p) => Math.floor(p.t / 86400000)));
  const today = Math.floor(now / 86400000);
  let d = today;
  if (!days.has(d)) { if (days.has(d - 1)) d -= 1; else return 0; } // сегодня ещё не занимался — считаем со вчера
  let streak = 0;
  while (days.has(d)) { streak++; d -= 1; }
  return streak;
}

/** SVG-спарклайн WPM по последним N сесс(ms). */
export function progressSVG(maxPoints = 40): string {
  const h = history().slice(-maxPoints);
  if (h.length < 2) return '';
  const W = 600, H = 120, pad = 8;
  const wpms = h.map((p) => p.wpm);
  const max = Math.max(...wpms), min = Math.min(...wpms);
  const span = max - min || 1;
  const x = (i: number) => pad + (i / (h.length - 1)) * (W - 2 * pad);
  const y = (v: number) => H - pad - ((v - min) / span) * (H - 2 * pad);
  const line = h.map((p, i) => `${i === 0 ? 'M' : 'L'} ${x(i).toFixed(1)} ${y(p.wpm).toFixed(1)}`).join(' ');
  const area = `${line} L ${x(h.length - 1).toFixed(1)} ${H - pad} L ${x(0).toFixed(1)} ${H - pad} Z`;
  const best = Math.max(...wpms), last = wpms[wpms.length - 1];
  return `<svg class="spark" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
    <path d="${area}" class="spark-area"/>
    <path d="${line}" class="spark-line"/>
    <circle cx="${x(h.length - 1).toFixed(1)}" cy="${y(last).toFixed(1)}" r="4" class="spark-dot"/>
  </svg>
  <div class="spark-meta"><span>сессий: <b>${history().length}</b></span><span>макс: <b>${best}</b></span><span>последняя: <b>${last}</b> WPM</span></div>`;
}
