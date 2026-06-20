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
});
