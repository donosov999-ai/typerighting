import { describe, it, expect, beforeAll, vi } from 'vitest';
import { letterKeys } from './keyboard';
import { recordKey, weakKeys, letterWeights, recoveryKeys, pushHistory, history, forecast, setTargetWpm, weakDrill } from './stats-store';

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

describe('bestTime + восстановление + гейт сессии (keybr bestConfidence / Result.Filter)', () => {
  it('клавиша, просевшая от своего рекорда, попадает в recoveryKeys', () => {
    const key = letterKeys('en')[7];
    let t = 700_000;
    // разгон: быстро → рекорд bt ≈ 100 мс
    for (let i = 0; i < 12; i++) { t += 100; recordKey(key.id, true, t); }
    // деградация: те же ВЕРНЫЕ нажатия, но медленно → t уходит выше bt
    for (let i = 0; i < 8; i++) { t += 600; recordKey(key.id, true, t); }
    expect(recoveryKeys('en', 5)).toContain(key.ch);
  });

  it('микро-сессия (<10 нажатий) не пишется в историю', () => {
    const id = letterKeys('en')[1].id;
    let t = 900_000;
    // валидная сессия → проходит и сбрасывает счётчик
    for (let i = 0; i < 12; i++) { t += 100; recordKey(id, true, t); }
    pushHistory(50, 0.99, t + 500);
    const before = history().length;
    // микро-сессия: 3 нажатия → должна быть отброшена
    for (let i = 0; i < 3; i++) { t += 100; recordKey(id, true, t); }
    pushHistory(80, 1.0, t + 500);
    expect(history().length).toBe(before);
  });
});

describe('F/D/H/M — прогноз, time-decay, богатая история, тайминг по режиму', () => {
  it('M: timed=false — медленные нажатия НЕ делают клавишу слабой (паузы не в скор)', () => {
    const key = letterKeys('en')[8];
    let t = 1_000_000;
    for (let i = 0; i < 10; i++) { t += 600; recordKey(key.id, true, t, false); } // медленно, но timed=false
    expect(weakKeys('en', 12)).not.toContain(key.ch);
  });

  it('D: календарный decay гасит старые счётчики (клавиша выпадает по объёму)', () => {
    const key = letterKeys('en')[9];
    let t = 2_000_000;
    for (let i = 0; i < 2; i++) { t += 200; recordKey(key.id, true, t); }
    for (let i = 0; i < 2; i++) { t += 200; recordKey(key.id, false, t); } // n=4, errRate=0.5 → слабая
    expect(weakKeys('en', 14)).toContain(key.ch);
    t += 42 * 86400000; // 2 полураспада → счётчики ×0.25
    recordKey(key.id, false, t);
    expect(weakKeys('en', 14)).not.toContain(key.ch); // n упал <3 → выпала
  });

  it('H: валидная сессия пишет len/ms/err/score в историю', () => {
    const id = letterKeys('en')[1].id;
    let t = 3_000_000;
    for (let i = 0; i < 15; i++) { t += 120; recordKey(id, i % 5 !== 0, t); }
    pushHistory(45, 90, t + 1000); // acc в шкале 0..100 (как в проде)
    const last = history()[history().length - 1];
    expect(last.len).toBeGreaterThanOrEqual(10);
    expect(last.err).toBeGreaterThan(0);
    expect(last.score).toBeGreaterThan(0);
    expect(typeof last.ms).toBe('number');
  });

  it('утечки нет: сессия с wpm<=0 сбрасывает счётчики (багфикс ревью)', () => {
    const id = letterKeys('en')[2].id;
    let t = 5_000_000;
    for (let i = 0; i < 20; i++) { t += 100; recordKey(id, true, t); } // «мусорная» сессия
    pushHistory(0, 0, t + 500); // wpm<=0 — не пишем, но счётчики ОБЯЗАНЫ сброситься
    const before = history().length;
    for (let i = 0; i < 3; i++) { t += 100; recordKey(id, true, t); } // микро-сессия 3 нажатия
    pushHistory(70, 95, t + 500);
    expect(history().length).toBe(before); // хвост не утёк → микро-сессия отброшена гейтом
  });

  it('F: растущий wpm → прогноз даёт число сессий до цели', () => {
    const rising = Array.from({ length: 12 }, (_, i) => ({ t: i, wpm: 20 + i * 2, acc: 0.95 }));
    localStorage.setItem('tr_history', JSON.stringify(rising));
    setTargetWpm(60);
    const fc = forecast();
    expect(fc).not.toBeNull();
    expect(fc!.sessions).toBeGreaterThan(0);
    expect(fc!.target).toBe(60);
  });

  it('repetition-дрилл: в weakDrill есть строка со словом, повторённым ×3', () => {
    // тяжело нагружаем ошибками ЧАСТУЮ букву → она топ-слабая → генератор точно даст слово
    const common = letterKeys('en').find((k) => ['e', 'a', 'o', 't'].includes(k.ch))!;
    let t = 6_000_000;
    for (let i = 0; i < 14; i++) { t += 200; recordKey(common.id, false, t); }
    const lines = weakDrill('en', 3);
    expect(lines.some((l) => /^(\S+) \1 \1$/.test(l))).toBe(true);
  });
});
