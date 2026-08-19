// Аккаунты + облачный синк прогресса (вход по нику + PIN — выбор Дениса 20.06).
// Бэкенд: Supabase personal-nzt, таблица tr_users закрыта RLS, доступ только
// через SECURITY DEFINER RPC tr_register / tr_login / tr_sync. PIN хранится
// на сервере bcrypt-хэшем; локально ник+PIN кэшируются для авто-синка
// (осознанный компромисс — это детский тренажёр, не банк).
const SUPA_URL = 'https://iuvvheeocobhiothfgei.supabase.co';
const SUPA_KEY = 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1';

const headers = {
  apikey: SUPA_KEY,
  Authorization: `Bearer ${SUPA_KEY}`,
  'Content-Type': 'application/json',
};

export interface RpcResult { ok: boolean; err?: string; progress?: Snapshot; }
export type Snapshot = Record<string, string>; // ключ localStorage → сырое значение

// Настройки устройства — НЕ синхронизируем (звук/тема/раскладка/метроном локальны).
const DEVICE_ONLY = new Set([
  'tr_bridge', 'tr_hardkeys', 'tr_metro', 'tr_metro_bpm', 'tr_dark', 'tr_flow', 'tr_lang', 'tr_acc',
]);

async function callRpc(fn: string, body: Record<string, unknown>): Promise<RpcResult> {
  try {
    const res = await fetch(`${SUPA_URL}/rest/v1/rpc/${fn}`, {
      method: 'POST', headers, body: JSON.stringify(body),
    });
    if (!res.ok) return { ok: false, err: 'net' };
    return (await res.json()) as RpcResult;
  } catch { return { ok: false, err: 'net' }; }
}

export const trRegister = (nick: string, pin: string) => callRpc('tr_register', { p_nick: nick, p_pin: pin });
export const trLogin = (nick: string, pin: string) => callRpc('tr_login', { p_nick: nick, p_pin: pin });
export const trSync = (nick: string, pin: string, progress: Snapshot) =>
  callRpc('tr_sync', { p_nick: nick, p_pin: pin, p_progress: progress });

// ── Снимок локального прогресса ──
export function collectLocal(): Snapshot {
  const snap: Snapshot = {};
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (!k || !k.startsWith('tr_') || DEVICE_ONLY.has(k)) continue;
    const v = localStorage.getItem(k);
    if (v != null) snap[k] = v;
  }
  return snap;
}

export function applyLocal(snap: Snapshot): void {
  for (const [k, v] of Object.entries(snap)) {
    if (k.startsWith('tr_') && !DEVICE_ONLY.has(k)) localStorage.setItem(k, v);
  }
}

// ── Слияние прогресса: рекорды/звёзды/уровни растут только вверх ──
// ⚠️ key-aware: 'bt' (лучшее EMA-время клавиши, keystats) — это МИНИМУМ (рекорд), НЕ максимум,
// иначе вход на 2-м устройстве портил адаптив-модель (слабые клавиши/восстановление/прогноз врали).
// tr_history — ОБЪЕДИНЕНИЕ сессий по таймстампу t, а не «более длинный массив» (иначе сессии
// второго устройства выбрасывались).
function mergeHistoryByTs(a: unknown[], b: unknown[]): unknown[] {
  const seen = new Set<number>();
  const merged: unknown[] = [];
  for (const rec of [...a, ...b]) {
    const ts = rec && typeof rec === 'object' ? (rec as { t?: number }).t : undefined;
    if (typeof ts === 'number') { if (seen.has(ts)) continue; seen.add(ts); }
    merged.push(rec);
  }
  merged.sort((x, y) => ((x as { t?: number })?.t ?? 0) - ((y as { t?: number })?.t ?? 0));
  return merged.length > 500 ? merged.slice(-500) : merged;
}

function deepMergeMax(a: unknown, b: unknown, key?: string): unknown {
  if (typeof a === 'number' && typeof b === 'number') return key === 'bt' ? Math.min(a, b) : Math.max(a, b);
  if (Array.isArray(a) && Array.isArray(b)) return key === 'tr_history' ? mergeHistoryByTs(a, b) : (a.length >= b.length ? a : b);
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const out: Record<string, unknown> = { ...(a as object) };
    for (const [k, vb] of Object.entries(b as Record<string, unknown>)) {
      out[k] = k in out ? deepMergeMax((a as Record<string, unknown>)[k], vb, k) : vb;
    }
    return out;
  }
  return b ?? a;
}

function mergeValue(a: string, b: string, key?: string): string {
  try {
    return JSON.stringify(deepMergeMax(JSON.parse(a), JSON.parse(b), key));
  } catch {
    const na = Number(a), nb = Number(b);
    if (!Number.isNaN(na) && !Number.isNaN(nb)) return String(Math.max(na, nb));
    return b || a; // предпочесть непустое
  }
}

/** Слить серверный и локальный снимки (объединение ключей, прогресс по максимуму). */
export function mergeProgress(server: Snapshot, local: Snapshot): Snapshot {
  const out: Snapshot = { ...server };
  for (const [k, lv] of Object.entries(local)) {
    out[k] = k in out ? mergeValue(out[k], lv, k) : lv;
  }
  return out;
}

// ── Сессия (ник+PIN в localStorage для авто-синка) ──
export interface Session { nick: string; pin: string; }
export function loadSession(): Session | null {
  try { const s = localStorage.getItem('tr_acc'); return s ? JSON.parse(s) as Session : null; } catch { return null; }
}
export function saveSession(s: Session): void { localStorage.setItem('tr_acc', JSON.stringify(s)); }
export function clearSession(): void { localStorage.removeItem('tr_acc'); }

/**
 * Войти/создать и слить прогресс. mode='login'|'register'.
 * При успехе: server∪local → применить локально → отправить обратно → запомнить сессию.
 */
export async function linkAccount(nick: string, pin: string, mode: 'login' | 'register'): Promise<RpcResult> {
  const r = mode === 'register' ? await trRegister(nick, pin) : await trLogin(nick, pin);
  if (!r.ok) return r;
  const merged = mergeProgress(r.progress ?? {}, collectLocal());
  applyLocal(merged);
  const saved = await trSync(nick, pin, merged);
  if (saved.ok) saveSession({ nick, pin });
  return saved;
}

/** Тихий авто-синк при старте (если есть сессия). Возвращает true при успехе. */
export async function autoSync(): Promise<boolean> {
  const s = loadSession();
  if (!s) return false;
  const r = await trLogin(s.nick, s.pin);
  if (!r.ok) return false;
  const merged = mergeProgress(r.progress ?? {}, collectLocal());
  applyLocal(merged);
  await trSync(s.nick, s.pin, merged);
  return true;
}

/** Отправить текущий локальный прогресс (после завершённого упражнения). Тихо. */
export async function pushSync(): Promise<void> {
  const s = loadSession();
  if (!s) return;
  await trSync(s.nick, s.pin, collectLocal());
}
