import { describe, it, expect, beforeAll, vi } from 'vitest';
import { letterKeys } from './keyboard';
import { recordKey, weakKeys, letterWeights } from './stats-store';

// Браузерные глобалы для узла: localStorage (persist) + window.setTimeout (батч записи).
beforeAll(() => {
  const store: Record<string, string> = {};
  vi.stubGlobal('localStorage', {
    getItem: (k: string) => store[k] ?? null,
    setItem: (k: string, v: string) => { store[k] = v; },
  });
  vi.stubGlobal('window', { setTimeout: () => 0 });
});

// Ключевой рывок: раньше «слабость» = ТОЛЬКО ошибки, теперь ещё и скорость.
// Медленная-но-ВЕРНАЯ буква (0 ошибок) обязана попасть в слабые — при errRate-only
// это было невозможно. Тайминг инъектируем через параметр now (детерминизм).
describe('единый скор слабости (ошибки + скорость)', () => {
  it('медленная-но-верная буква считается слабой', () => {
    const keys = letterKeys('en');
    const slow = keys[0], a = keys[1], b = keys[2], c = keys[3];
    let t = 100_000;
    // база: три быстрые верные буквы (интервал 100 мс)
    for (let i = 0; i < 10; i++) {
      t += 100; recordKey(a.id, true, t);
      t += 100; recordKey(b.id, true, t);
      t += 100; recordKey(c.id, true, t);
    }
    // slow: всегда верно, но интервал 600 мс (в 6× медленнее медианы)
    for (let i = 0; i < 10; i++) {
      t += 600; recordKey(slow.id, true, t);
      t += 100; recordKey(a.id, true, t);
    }
    const weak = weakKeys('en', 6);
    expect(weak).toContain(slow.ch);           // медленная попала в слабые…
    expect(letterWeights('en')[slow.ch]).toBeGreaterThan(1); // …и получила вес >1 для дрилла
  });

  it('буква с ошибками тоже слабая (точность не потеряна)', () => {
    const keys = letterKeys('en');
    const errKey = keys[5];
    let t = 500_000;
    for (let i = 0; i < 5; i++) { t += 150; recordKey(errKey.id, true, t); }
    for (let i = 0; i < 5; i++) { t += 150; recordKey(errKey.id, false, t); }
    expect(weakKeys('en', 8)).toContain(errKey.ch);
  });
});
