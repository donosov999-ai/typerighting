// Профили приложения (решение Дениса 12.06.2026): три версии в одном коде —
// мужской / женский / детский. Профиль = тема (CSS-переменные через
// [data-profile]) + для детского — отдельный игровой режим (src/kids.ts).
export type Profile = 'm' | 'f' | 'kids';

export const PROFILE_META: Record<Profile, { label: string; emoji: string; desc: string }> = {
  m:    { label: 'Мужской',  emoji: '⌨️', desc: 'Тёмная тема, скорость и рекорды' },
  f:    { label: 'Женский',  emoji: '🌸', desc: 'Светлая тёплая тема, мягкий темп' },
  kids: { label: 'Детский',  emoji: '🐱', desc: 'Игра: уровни, звёзды и котик' },
};

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

// Профильные формулировки (минимум различий, дети — отдельный режим)
export function doneTitle(p: Profile | null): string {
  return p === 'f' ? '✓ Отлично!' : '✓ Готово';
}
