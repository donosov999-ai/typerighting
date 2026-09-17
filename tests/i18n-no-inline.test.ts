/* typerighting-test-i18n-inline · VER 1 · 17.09.2026 */
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

// Строки интерфейса только через словарь. До 17.09.2026 в main.ts/compete.ts жило 44 пары
// `ru ? 'Русский' : 'English'` — на es/de/fr/it/pt они показывали английский, и тест полноты
// словаря (src/i18n.test.ts) их не видел: в словаре их не было вовсе.
// Признак: тернарник, где одна ветка — литерал с кириллицей, другая — с латиницей.
const ALLOW = [
  "reviewMark = L === 'ru' ? 'фж' : 'a'", // course.ts: буквы урока повторения, не текст интерфейса
];
const PAIR = /\?\s*(['"`])((?:(?!\1).)*[А-Яа-яЁё](?:(?!\1).)*)\1\s*:\s*(['"`])((?:(?!\3).)*)\3/g;

describe('интерфейс без ru/en-строк в коде', () => {
  it('нет пар «кириллица : латиница» вне словаря', () => {
    const src = join(__dirname, '..', 'src');
    const found: string[] = [];
    for (const f of readdirSync(src)) {
      if (!f.endsWith('.ts') || f.endsWith('.test.ts') || f === 'i18n.ts') continue;
      readFileSync(join(src, f), 'utf8').split('\n').forEach((line, i) => {
        if (ALLOW.some((a) => line.includes(a))) return;
        for (const m of line.matchAll(PAIR)) {
          if (/[A-Za-z]/.test(m[4]) && !/[А-Яа-яЁё]/.test(m[4])) found.push(`${f}:${i + 1} «${m[2]}» / «${m[4]}»`);
        }
      });
    }
    expect(found).toEqual([]);
  });
});
