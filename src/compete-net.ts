// P2 соревнование — сетевой слой: реплеи (ghost), челленджи по ссылке, недельные лиги.
// Пишем/читаем через SECURITY DEFINER RPC (anon). Страница челленджа — edge-функция challenge.
const SUPA_URL = 'https://iuvvheeocobhiothfgei.supabase.co';
const KEY = 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1';
const H = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

export const CHALLENGE_BASE = SUPA_URL + '/functions/v1/challenge';

export interface Tick { c: string; t: number; } // символ + мс от старта (для ghost)
export interface ChallengeData {
  from_nick: string; discipline: string; lang: string;
  target_wpm: number; target_acc: number | null; replay_id: string | null;
}
export interface LeagueRow { nick: string; wpm: number; accuracy: number; rank: number; }

async function rpc<T>(fn: string, body: Record<string, unknown>): Promise<T | null> {
  try {
    const r = await fetch(`${SUPA_URL}/rest/v1/rpc/${fn}`, { method: 'POST', headers: H, body: JSON.stringify(body) });
    return r.ok ? ((await r.json()) as T) : null;
  } catch { return null; }
}

export const saveReplay = (nick: string, disc: string, lang: string, wpm: number, acc: number, timeline: Tick[]) =>
  rpc<string>('tr_replay_save', { p_nick: nick, p_disc: disc, p_lang: lang, p_wpm: Math.round(wpm), p_acc: acc, p_timeline: timeline });

export const getReplay = (id: string) =>
  rpc<{ nick: string; wpm: number; accuracy: number; timeline: Tick[] }>('tr_replay_get', { p_id: id });

export const createChallenge = (from: string, disc: string, lang: string, target: number, acc: number, replayId: string | null) =>
  rpc<string>('tr_challenge_create', { p_from: from, p_disc: disc, p_lang: lang, p_target: Math.round(target), p_acc: acc, p_replay: replayId });

export const getChallenge = (id: string) => rpc<ChallengeData>('tr_challenge_get', { p_id: id });

export const leagueSubmit = (nick: string, disc: string, lang: string, wpm: number, acc: number) =>
  rpc<string>('tr_league_submit', { p_nick: nick, p_disc: disc, p_lang: lang, p_wpm: Math.round(wpm), p_acc: acc });

export const leagueBoard = (disc: string, lang: string, limit = 20) =>
  rpc<LeagueRow[]>('tr_league_board', { p_disc: disc, p_lang: lang, p_limit: limit });
