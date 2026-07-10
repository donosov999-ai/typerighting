// Долгосрочная статистика (доработки 13.06.2026 по запросу Дениса):
//  • per-key статистика → тепловая карта + адаптивный режим «слабые клавиши»
//  • история сессий → график прогресса по дням
// Всё в localStorage, без сервера.
import { letterKeys } from './keyboard';
import { buildModel, generate } from './ngram';
import { CORPUS } from './corpus';
import type { Lang } from './i18n';

// ── Per-key: keyId → {ok, err, t?, nt?} ──
//  ok/err — счётчики точности (было).
//  t  — EMA среднего межклавишного интервала (мс) ТОЛЬКО по ВЕРНЫМ нажатиям
//       (как histogram.ts у keybr: опечатки из тайминга исключаются).
//  nt — число валидных замеров времени (для доверия к t).
//  bt — ЛУЧШЕЕ (мин) EMA-время за всю историю клавиши (keybr bestTimeToType):
//       отличает «никогда не умел» от «умел, но просел» → режим восстановления.
//  Зачем: раньше «слабость» считалась ТОЛЬКО по ошибкам — медленная-но-верная
//  буква не попадала в дрилл. Теперь скорость и точность объединены в один скор
//  (см. keyWeakness). keybr берёт только скорость, мы — только ошибки; берём оба.
type KeyStat = { ok: number; err: number; t?: number; nt?: number; bt?: number };
const KS_KEY = 'tr_keystats';
let keystats: Record<string, KeyStat> = load();

// EMA-сглаживание тайминга (alpha=0.1 — свежие нажатия весят больше; рекуррентная
// рецентность вместо голого кумулятивного среднего, как filter.ts у keybr).
const EMA_ALPHA = 0.1;
// Валидный межклавишный интервал: <40 мс = «прострел»/автоповтор, >12 с = пауза.
const MIN_MS = 40, MAX_MS = 12000;
// Вклад в единый скор слабости: точность важнее скорости (тренажёр называется
// TypeRIGHTing — «RIGHT»); но скорость участвует. keybr игнорит точность вовсе.
const ERR_W = 0.6, SPEED_W = 0.4;
let lastKeyTs = 0;
// Гейт валидности сессии (keybr Result.Filter minLength=10): микро-проходы в
// 2-3 символа не должны пачкать график WPM / макс / стрик. Считаем нажатия с
// прошлой записи в историю — правки 7 вызовов pushHistory не требуется.
const MIN_SESSION_KEYS = 10;
let keysSinceHist = 0;

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

export function recordKey(keyId: string, ok: boolean, now = Date.now()) {
  const s = keystats[keyId] ?? (keystats[keyId] = { ok: 0, err: 0 });
  const gap = now - lastKeyTs;
  lastKeyTs = now;
  keysSinceHist++;
  if (ok) {
    s.ok++;
    // тайминг копим только по верным нажатиям и только валидный интервал
    if (gap >= MIN_MS && gap <= MAX_MS) {
      s.t = s.t === undefined ? gap : EMA_ALPHA * gap + (1 - EMA_ALPHA) * s.t;
      s.nt = (s.nt ?? 0) + 1;
      s.bt = s.bt === undefined ? s.t : Math.min(s.bt, s.t); // рекорд клавиши
    }
  } else {
    s.err++;
  }
  persist();
}

/** Клавиши, которые ПРОСЕЛИ от своего рекорда (t хуже bt на >порог) — для
 *  режима «восстановление». Отличается от weakKeys: клавиша может быть быстрее
 *  медианы (не «слабая»), но заметно медленнее СЕБЯ-прошлой. keybr: bestConfidence. */
export function recoveryKeys(lang: 'en' | 'ru', count = 3, drop = 0.25): string[] {
  const scored = letterKeys(lang)
    .map(({ id, ch }) => {
      const s = keystats[id];
      const reg = s && s.bt !== undefined && s.t !== undefined && (s.nt ?? 0) >= 3
        ? (s.t - s.bt) / s.bt : 0;
      return { ch, reg };
    })
    .filter((x) => x.reg > drop)
    .sort((a, b) => b.reg - a.reg);
  return scored.slice(0, count).map((x) => x.ch);
}

/** Референс скорости — медиана EMA-времён пользователя (порог «медленно»).
 *  Самоотносительно: адаптируется к уровню (новичок/ребёнок vs про), в отличие
 *  от фикс. 175 cpm у keybr, который для смешанной аудитории неадекватен. */
function speedRef(): number {
  const ts = Object.values(keystats)
    .filter((s) => s.t !== undefined && (s.nt ?? 0) >= 3)
    .map((s) => s.t as number)
    .sort((a, b) => a - b);
  if (ts.length < 3) return 0; // мало данных о скорости — скоростной сигнал выключен
  return ts[Math.floor(ts.length / 2)];
}

/** Единый скор слабости клавиши 0..~1: ошибки + медленность.
 *  speedWeak = насколько клавиша медленнее своей медианы (2× медианы = максимум).
 *  При недостатке тайминга (ref=0 / nt<3) вырождается в чистый errRate — обратная
 *  совместимость: порядок клавиш по ошибкам сохраняется. */
function keyWeakness(s: KeyStat, ref: number): number {
  const n = s.ok + s.err;
  const errRate = n > 0 ? s.err / n : 0;
  let speedWeak = 0;
  if (ref > 0 && s.t !== undefined && (s.nt ?? 0) >= 3) {
    speedWeak = Math.min(1, Math.max(0, (s.t - ref) / ref));
  }
  return ERR_W * errRate + SPEED_W * speedWeak;
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

/** Топ слабых клавиш (по единому скору: ошибки + медленность) для адаптива. */
export function weakKeys(lang: 'en' | 'ru', count = 6): string[] {
  const ref = speedRef();
  const scored = letterKeys(lang)
    .map(({ id, ch }) => {
      const s = keystats[id]; const n = s ? s.ok + s.err : 0;
      const weak = s && n >= 3 ? keyWeakness(s, ref) : 0;
      return { ch, weak, n };
    })
    .filter((x) => x.weak > 0)
    .sort((a, b) => b.weak - a.weak || b.n - a.n);
  return scored.slice(0, count).map((x) => x.ch);
}

/** Веса букв для n-граммного генератора: слабые (ошибки+скорость) встречаются чаще. */
export function letterWeights(lang: 'en' | 'ru', boost = 6): Record<string, number> {
  const ref = speedRef();
  const w: Record<string, number> = {};
  for (const { id, ch } of letterKeys(lang)) {
    const s = keystats[id];
    if (!s || s.ok + s.err < 4) continue;
    const weak = keyWeakness(s, ref); // 0..~1
    if (weak > 0) w[ch] = 1 + weak * boost;
  }
  return w;
}

// модель n-грамм кэшируется по языку (как в AI-режиме)
let weakModel: ReturnType<typeof buildModel> | null = null;
let weakModelLang: Lang | null = null;

/**
 * Адаптивные строки для режима «Слабые клавиши» (усилено 13.06.2026):
 * n-граммная генерация СВЯЗНЫХ слов языка с сильным упором на слабые буквы —
 * вместо прежней случайной абракадабры. Если данных мало — обычные слова языка.
 */
export function weakDrill(L: Lang, lines = 5): string[] {
  const kb: 'en' | 'ru' = L === 'ru' ? 'ru' : 'en';
  if (!weakModel || weakModelLang !== L) {
    weakModel = buildModel(CORPUS[L] ?? CORPUS.en, kb, 3);
    weakModelLang = L;
  }
  const weight = letterWeights(kb, 12); // сильнее, чем в AI (×12), — это прицельная тренировка слабых
  // форсим слабые (ошибки+скорость) + просевшие от рекорда (восстановление)
  const force = [...new Set([...weakKeys(kb, 4), ...recoveryKeys(kb, 2)])];
  const out: string[] = [];
  for (let l = 0; l < lines; l++) out.push(generate(weakModel, { chars: 44, weight, maxWord: 8, force }));
  return out.filter((s) => s.length > 0);
}

// ── История сессий: график прогресса ──
export type HistPoint = { t: number; wpm: number; acc: number };
const H_KEY = 'tr_history';

export function pushHistory(wpm: number, acc: number, now: number) {
  if (wpm <= 0) return;
  // микро-сессия (<10 нажатий с прошлой записи) — мусор, не пишем в график/стрик
  if (keysSinceHist < MIN_SESSION_KEYS) { keysSinceHist = 0; return; }
  keysSinceHist = 0;
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
