/* typerighting-session-log · VER 1 · 17.09.2026 */
/**
 * Облачная история тренировок → Supabase `tr_sessions` (задача TeamOps 612e065f).
 *
 * 🔴 ЗАЧЕМ. До этого аккаунт хранил только СНИМОК прогресса (tr_users.progress): ни истории
 * сессий, ни кривой роста, ни данных для отчёта учителю не было нигде, кроме localStorage
 * одного устройства. Таблица — фундамент дашбордов и режима класса (21e88738).
 *
 * КАК УСТРОЕНО.
 * • Источник — событие `onSession` из stats-store (стреляет в pushHistory после гейта микро-сессий).
 *   Все 9 концов сессий в 7 режимах уже сходятся туда — облако видит ровно то, что видит график.
 * • Офлайн-первое: приложение работает без сети, поэтому сессия сперва встаёт в локальную очередь
 *   (tr_sess_queue, до 200), отправка — сразу, при появлении сети и при старте.
 * • Идемпотентность: client_id на сессию + уникальность (device_id, client_id) на сервере —
 *   повторная отправка той же строки не задваивает её.
 * • Кто: вошедший — по нику+PIN (проверка на сервере, как tr_sync); иначе только device_id —
 *   случайный uuid устройства без персональных данных. Прошлые анонимные сессии к аккаунту
 *   НЕ привязываются автоматически: на общем (семейном) устройстве это приписало бы чужие сессии.
 * • tr_device / tr_sess_queue — в DEVICE_ONLY (account.ts): облачный синк их не разносит.
 * • В режиме разработки (vite dev) не пишем в боевую базу, если не включить tr_sess_debug=1;
 *   такие строки помечены платформой «dev-…».
 *
 * ⚠️ В режиме AI-обучения (learn.ts) «wpm» — это mastery/5, как и в локальной истории.
 */
import { onSession, type SessionEvent } from './stats-store';
import { SUPA_URL, SUPA_KEY, loadSession } from './account';
import pkg from '../package.json';

const Q_KEY = 'tr_sess_queue';
const DEVICE_KEY = 'tr_device';
const DEBUG_KEY = 'tr_sess_debug';
const MAX_QUEUE = 200;
/** Отказы, с которыми строка не пройдёт никогда — снимаем её, а не крутим очередь вечно. */
const PERMANENT = new Set(['ids', 'range', 'date']);

export interface SessionContext { mode: string; lang: string; layout: string }
export interface QueuedSession {
  client: string; device: string; played_at: string;
  mode: string; lang: string; layout: string;
  wpm: number; acc: number; duration_ms: number; chars: number; errors: number; score: number | null;
  err_keys: Record<string, number>; app_ver: string; platform: string;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const isDev = (): boolean => Boolean((import.meta as any).env?.DEV);

function uuid(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
  const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

export function deviceId(): string {
  let id = localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = uuid();
    try { localStorage.setItem(DEVICE_KEY, id); } catch { /* quota */ }
  }
  return id;
}

/** «app-android», «web-mac», «dev-web-win»… — оболочка + ОС, без версии браузера. */
export function platformTag(): string {
  const shell = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window ? 'app' : 'web';
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
  const touchMac = /Macintosh/i.test(ua) && typeof navigator !== 'undefined' && navigator.maxTouchPoints > 1; // iPadOS
  const os = /Android/i.test(ua) ? 'android'
    : /iPhone|iPad|iPod/i.test(ua) || touchMac ? 'ios'
    : /Mac/i.test(ua) ? 'mac' : /Win/i.test(ua) ? 'win' : /Linux/i.test(ua) ? 'linux' : 'other';
  return `${isDev() ? 'dev-' : ''}${shell}-${os}`;
}

function readQueue(): QueuedSession[] {
  try {
    const q = JSON.parse(localStorage.getItem(Q_KEY) ?? '[]');
    return Array.isArray(q) ? q : [];
  } catch { return []; }
}
function writeQueue(q: QueuedSession[]): void {
  try { localStorage.setItem(Q_KEY, JSON.stringify(q.slice(-MAX_QUEUE))); } catch { /* quota */ }
}

/** 30 клавиш с наибольшим числом ошибок — сервер режет err_keys больше 2 КБ. */
export function topErrKeys(m: Record<string, number>, limit = 30): Record<string, number> {
  return Object.fromEntries(Object.entries(m).sort((a, b) => b[1] - a[1]).slice(0, limit));
}

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

export function buildRow(e: SessionEvent, ctx: SessionContext): QueuedSession {
  return {
    client: uuid(),
    device: deviceId(),
    played_at: new Date(e.t).toISOString(),
    mode: ctx.mode.slice(0, 20),
    lang: ctx.lang.slice(0, 5),
    layout: ctx.layout.slice(0, 12),
    wpm: clamp(Math.round(e.wpm), 0, 400),
    acc: clamp(e.acc, 0, 100),
    duration_ms: clamp(Math.round(e.ms ?? 0), 0, 3600000),
    chars: clamp(Math.round(e.len ?? 0), 0, 100000),
    errors: clamp(Math.round(e.err ?? 0), 0, 100000),
    score: e.score ?? null,
    err_keys: topErrKeys(e.errKeys),
    app_ver: String(pkg.version).slice(0, 20),
    platform: platformTag(),
  };
}

export function enqueue(row: QueuedSession): void {
  const q = readQueue();
  q.push(row);
  writeQueue(q);
}

export function queueSize(): number { return readQueue().length; }

let flushing = false;

/**
 * Досылает очередь с головы. Сеть легла или сервер ответил сбоем — останавливаемся, строки
 * остаются до следующего раза. Возвращает число строк, принятых сервером.
 */
export async function flushQueue(fetchImpl: typeof fetch = fetch): Promise<number> {
  if (flushing) return 0;
  flushing = true;
  let sent = 0;
  try {
    const account = loadSession();
    for (;;) {
      const row = readQueue()[0];
      if (!row) break;
      let res: Response;
      try {
        res = await fetchImpl(`${SUPA_URL}/rest/v1/rpc/tr_session_record`, {
          method: 'POST',
          headers: { apikey: SUPA_KEY, Authorization: `Bearer ${SUPA_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            p_device: row.device, p_client: row.client, p_played_at: row.played_at,
            p_mode: row.mode, p_lang: row.lang, p_layout: row.layout,
            p_wpm: row.wpm, p_acc: row.acc, p_duration_ms: row.duration_ms, p_chars: row.chars,
            p_errors: row.errors, p_score: row.score, p_err_keys: row.err_keys,
            p_app_ver: row.app_ver, p_platform: row.platform,
            p_nick: account?.nick ?? null, p_pin: account?.pin ?? null,
          }),
        });
      } catch { break; } // нет сети — очередь подождёт
      if (!res.ok) break; // сбой шлюза/сервера — позже
      let body: { ok?: boolean; err?: string } = {};
      try { body = await res.json(); } catch { break; }
      if (!body.ok && !(body.err && PERMANENT.has(body.err))) break;
      const cur = readQueue();
      if (cur[0]?.client === row.client) { cur.shift(); writeQueue(cur); } // голову мог уже снять параллельный вызов
      if (body.ok) sent++;
    }
  } finally {
    flushing = false;
  }
  return sent;
}

/** Подписка при старте приложения. ctx() читается в момент конца сессии — режим/язык актуальны. */
export function initSessionLog(ctx: () => SessionContext): void {
  if (isDev() && localStorage.getItem(DEBUG_KEY) !== '1') return;
  onSession((e) => {
    enqueue(buildRow(e, ctx()));
    void flushQueue();
  });
  window.addEventListener('online', () => { void flushQueue(); });
  void flushQueue(); // досылка того, что накопилось офлайн
}
