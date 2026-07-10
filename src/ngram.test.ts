import { describe, it, expect } from 'vitest';
import { buildModel, generate } from './ngram';

// order по умолчанию = 3 (триграммы): префикс начала слова = «пробел + буква»,
// при order=2 префикс в 1 символ не даёт стартов и generate вернёт пусто.
describe('генератор псевдослов ngram.ts', () => {
  it('генерит непустой текст только из обучающего алфавита (en)', () => {
    const m = buildModel('the cat sat on the mat the rat ran fast', 'en');
    const out = generate(m, { chars: 30 });
    expect(out.length).toBeGreaterThan(0);
    expect(/^[a-z ]+$/.test(out)).toBe(true);
  });

  it('русская модель генерит кириллицу', () => {
    const m = buildModel('кот ходит около окна и видит кита у дома', 'ru');
    const out = generate(m, { chars: 25 });
    expect(out.length).toBeGreaterThan(0);
    expect(/^[а-я ]+$/.test(out)).toBe(true);
  });

  it('пустая модель (нет стартов) даёт пустую строку', () => {
    const m = buildModel('', 'ru');
    expect(generate(m, { chars: 20 })).toBe('');
  });

  it('weight смещает выбор, но не ломает генерацию', () => {
    const m = buildModel('малина калина долина равнина осина', 'ru');
    const out = generate(m, { chars: 20, weight: { а: 5 } });
    expect(out.length).toBeGreaterThan(0);
  });

  it('латинская модель сохраняет диакритику в алфавите (é ü ç для нац. раскладок)', () => {
    const m = buildModel('café créer égalité déjà séance présent', 'en', 3);
    expect(m.alphabet).toContain('é');
    const out = generate(m, { chars: 20 });
    expect(out.length).toBeGreaterThan(0);
  });

  it('force: каждое слово содержит целевую слабую букву (как prefix-list keybr)', () => {
    const m = buildModel('малина калина долина равнина осина машина', 'ru');
    const out = generate(m, { chars: 40, force: ['а'] });
    expect(out.length).toBeGreaterThan(0);
    for (const w of out.split(' ')) expect(w).toContain('а');
  });

  it('force с редкой буквой не зацикливает (бюджет попыток)', () => {
    const m = buildModel('the cat sat on the mat', 'en');
    // 'z' в корпусе нет — генерация не виснет, просто вернёт мало/пусто
    expect(() => generate(m, { chars: 30, force: ['z'] })).not.toThrow();
  });
});
