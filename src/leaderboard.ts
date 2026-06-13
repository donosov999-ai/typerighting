// Онлайн-лидерборд соревнований (Supabase personal-nzt). Публичная запись/чтение
// под RLS (таблица public.typing_leaderboard). Publishable-ключ безопасен в
// клиенте — доступ ограничен политиками RLS (только SELECT + INSERT этой таблицы).
const SUPA_URL = 'https://iuvvheeocobhiothfgei.supabase.co';
const SUPA_KEY = 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1';
const TABLE = 'typing_leaderboard';

export interface LbRow { name: string; discipline: string; lang: string; wpm: number; accuracy: number; ms: number; }

const headers = {
  apikey: SUPA_KEY,
  Authorization: `Bearer ${SUPA_KEY}`,
  'Content-Type': 'application/json',
};

/** Опубликовать результат. Тихо глотает ошибки сети (лидерборд не критичен). */
export async function submitScore(row: LbRow): Promise<boolean> {
  try {
    const res = await fetch(`${SUPA_URL}/rest/v1/${TABLE}`, {
      method: 'POST',
      headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify(row),
    });
    return res.ok;
  } catch { return false; }
}

/** Топ-10 по дисциплине+языку (по WPM убыв.). Пустой массив при ошибке/офлайне. */
export async function fetchTop(discipline: string, lang: string, limit = 10): Promise<LbRow[]> {
  try {
    const q = `discipline=eq.${discipline}&lang=eq.${lang}&order=wpm.desc&limit=${limit}`;
    const res = await fetch(`${SUPA_URL}/rest/v1/${TABLE}?${q}`, { headers });
    if (!res.ok) return [];
    return (await res.json()) as LbRow[];
  } catch { return []; }
}
