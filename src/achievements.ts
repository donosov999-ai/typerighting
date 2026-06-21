// Достижения (бейджи за вехи) — ретеншн. Считаются из истории сессий (tr_history),
// стрика и опробованных языков. Разблокированные хранятся в tr_ach и синкаются
// через аккаунт (не в DEVICE_ONLY). Новые бейджи → награда (звук + тост) в main.ts.
import { history, streakDays } from './stats-store';

export interface Badge { id: string; icon: string; }
interface AchStats { streak: number; maxWpm: number; maxAcc: number; sessions: number; langs: number; }

// порядок = порядок показа; need проверяет разблокировку
const RULES: Array<Badge & { need: (s: AchStats) => boolean }> = [
  { id: 'first', icon: '🌱', need: (s) => s.sessions >= 1 },
  { id: 'sessions10', icon: '📈', need: (s) => s.sessions >= 10 },
  { id: 'sessions50', icon: '🏅', need: (s) => s.sessions >= 50 },
  { id: 'streak3', icon: '🔥', need: (s) => s.streak >= 3 },
  { id: 'streak7', icon: '🔥', need: (s) => s.streak >= 7 },
  { id: 'streak30', icon: '💎', need: (s) => s.streak >= 30 },
  { id: 'wpm30', icon: '⚡', need: (s) => s.maxWpm >= 30 },
  { id: 'wpm50', icon: '🚀', need: (s) => s.maxWpm >= 50 },
  { id: 'wpm70', icon: '👑', need: (s) => s.maxWpm >= 70 },
  { id: 'acc99', icon: '🎯', need: (s) => s.maxAcc >= 99 },
  { id: 'polyglot', icon: '🌍', need: (s) => s.langs >= 3 },
];
export const BADGES: Badge[] = RULES.map(({ id, icon }) => ({ id, icon }));

function langsTried(): number {
  try {
    const seen = new Set<string>();
    for (let i = 0; i < localStorage.length; i++) {
      const m = (localStorage.key(i) || '').match(/^tr_(?:progress|course)_(\w+)$/);
      if (m) seen.add(m[1]);
    }
    return seen.size;
  } catch { return 0; }
}

function gather(): AchStats {
  const h = history();
  return {
    streak: streakDays(Date.now()),
    maxWpm: h.reduce((m, p) => Math.max(m, p.wpm), 0),
    maxAcc: h.reduce((m, p) => Math.max(m, p.acc), 0),
    sessions: h.length,
    langs: langsTried(),
  };
}

/** id всех разблокированных на данный момент бейджей. */
export function unlockedIds(): string[] {
  const s = gather();
  return RULES.filter((r) => r.need(s)).map((r) => r.id);
}

const ACH_KEY = 'tr_ach';
function savedIds(): string[] {
  try { return JSON.parse(localStorage.getItem(ACH_KEY) || '[]') as string[]; } catch { return []; }
}

/** Проверить и зафиксировать новые бейджи. Возвращает только что разблокированные. */
export function checkNewBadges(): Badge[] {
  const now = unlockedIds();
  const before = new Set(savedIds());
  const fresh = RULES.filter((r) => now.includes(r.id) && !before.has(r.id));
  if (fresh.length) { try { localStorage.setItem(ACH_KEY, JSON.stringify(now)); } catch { /* quota */ } }
  return fresh.map(({ id, icon }) => ({ id, icon }));
}

/** Множество разблокированных id (для отрисовки сетки достижений). */
export function unlockedSet(): Set<string> {
  return new Set(unlockedIds());
}
