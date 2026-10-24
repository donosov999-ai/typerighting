import { describe, it, expect } from 'vitest';
import { practiceLines, practiceProgressKey, numericExercises } from './practice-options';
import { createState, pressChar } from './typing';

describe('practice content options', () => {
  it('preserves multilingual letters, accents and digits while stripping punctuation and symbols', () => {
    const source = ['«Привет!» — 2026.', "L'été, déjà! 123 €", 'Straße: groß; café?'];
    expect(practiceLines(source, true)).toEqual(['Привет 2026', 'Lété déjà 123', 'Straße groß café']);
    expect(source[0]).toBe('«Привет!» — 2026.');
    expect(practiceLines(source, false)).toEqual(source);
  });
  it('drops punctuation-only lines so Enter does not require an empty exercise', () => {
    expect(practiceLines(['!!!', '  ', '123,', '—'], true)).toEqual(['123']);
    expect(practiceLines(['!!!'], true)).toEqual([]);
  });
  it('keeps simplified records separate while preserving original progress keys', () => {
    expect(practiceProgressKey('abandon', false)).toBe('tr_progress_abandon');
    expect(practiceProgressKey('abandon', true)).not.toBe(practiceProgressKey('abandon', false));
    expect(practiceProgressKey('digits', true)).toBe(practiceProgressKey('digits', false));
    expect(practiceProgressKey('digits', false)).not.toBe(practiceProgressKey('abandon', false));
  });
  it('every numeric drill covers all digits and can complete through the existing engine', () => {
    const drills = numericExercises();
    expect(drills.length).toBeGreaterThan(1);
    expect(new Set(drills.map(ex => ex.id)).size).toBe(drills.length);
    for (const ex of drills) {
      const st = createState(ex.lines);
      expect(st.pattern).toMatch(/^[0-9 ]+$/);
      for (let i = 0; i < 10; i++) expect(st.pattern).toContain(String(i));
      for (const ch of st.pattern) expect(pressChar(st, ch, true).wrong).toBe(false);
      expect(st.finishedAt).not.toBeNull();
    }
  });
});
