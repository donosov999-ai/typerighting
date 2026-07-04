// P1 сертификат-виралка: регистрация результата теста → публичная шеринг-ссылка.
// Пишем через SECURITY DEFINER RPC tr_cert_create (anon), страница рендерится edge-функцией cert.
const SUPA_URL = 'https://iuvvheeocobhiothfgei.supabase.co';
const SUPA_KEY = 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1';
const CERT_BASE = SUPA_URL + '/functions/v1/cert';

/** Регистрирует сертификат, возвращает публичный URL страницы (или null при ошибке). */
export async function registerCert(
  nick: string, discipline: string, lang: string, wpm: number, accuracy: number
): Promise<string | null> {
  try {
    const res = await fetch(`${SUPA_URL}/rest/v1/rpc/tr_cert_create`, {
      method: 'POST',
      headers: { apikey: SUPA_KEY, Authorization: `Bearer ${SUPA_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        p_nick: nick || 'Anon', p_disc: discipline, p_lang: lang,
        p_wpm: Math.max(0, Math.round(wpm)), p_acc: Math.round(accuracy * 100) / 100,
      }),
    });
    if (!res.ok) return null;
    const id = await res.json(); // RPC RETURNS uuid → PostgREST отдаёт строку
    return typeof id === 'string' && id.length >= 36 ? `${CERT_BASE}/${id}` : null;
  } catch {
    return null;
  }
}
