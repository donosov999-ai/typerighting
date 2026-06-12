// Профили приложения (решение Дениса 12.06.2026): три версии в одном коде —
// мужской / женский / детский. Профиль = тема (CSS-переменные через
// [data-profile]) + для детского — отдельный игровой режим (src/kids.ts).
export type Profile = 'm' | 'f' | 'kids';

// Подписи профилей — в i18n.ts (ключи profile.<id> / profile.<id>.desc)
export const PROFILE_EMOJI: Record<Profile, string> = { m: '⌨️', f: '🌸', kids: '🐱' };

const KEY = 'tr_profile';

export function loadProfile(): Profile | null {
  const v = localStorage.getItem(KEY);
  return v === 'm' || v === 'f' || v === 'kids' ? v : null;
}

export function saveProfile(p: Profile) {
  try { localStorage.setItem(KEY, p); } catch { /* quota */ }
  applyProfile(p);
}

export function applyProfile(p: Profile | null) {
  if (p) document.documentElement.dataset.profile = p;
  else delete document.documentElement.dataset.profile;
}

