import { describe, it, expect } from 'vitest';
import { DICT, LANGS, setLang, t } from './i18n';

// Полнота словаря. До 17.09.2026 26 ключей были только на ru/en — на пяти языках интерфейс
// молча показывал английский, и ни сборка, ни тесты этого не видели (фолбэк t() скрывает дыру).
describe('словарь интерфейса: 7 языков', () => {
  it('у каждого ключа непустой перевод на все языки', () => {
    const missing: string[] = [];
    for (const [key, entry] of Object.entries(DICT)) {
      for (const l of LANGS) {
        const v = (entry as Record<string, string | undefined>)[l];
        if (typeof v !== 'string' || v.trim() === '') missing.push(`${key} [${l}]`);
      }
    }
    expect(missing).toEqual([]);
  });

  it('плейсхолдеры {n}/{wpm}/… одинаковы во всех переводах', () => {
    const ph = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join(',');
    const broken: string[] = [];
    for (const [key, entry] of Object.entries(DICT)) {
      const ref = ph(entry.en);
      for (const l of LANGS) {
        const v = (entry as Record<string, string | undefined>)[l];
        if (typeof v === 'string' && ph(v) !== ref) broken.push(`${key} [${l}]: «${ph(v)}» ≠ «${ref}»`);
      }
    }
    expect(broken).toEqual([]);
  });

  it('смена языка отдаёт перевод, а не английский фолбэк', () => {
    setLang('de');
    expect(t('ach.title')).toBe('Erfolge');
    expect(t('ex.net')).toBe('Netto-WPM');
    setLang('pt');
    expect(t('heat.weak')).toBe('teclas fracas');
    setLang('ru');
    expect(t('ex.net')).toBe('Net WPM');
  });
});
