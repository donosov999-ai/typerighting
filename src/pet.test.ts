import { describe, it, expect, beforeAll, vi } from 'vitest';
import { pickLine, STREAK_MARKS, notePossibleRecord, collectFacts, type PetFacts } from './pet';
import { t, setLang, LANGS } from './i18n';

beforeAll(() => {
  const store: Record<string, string> = {};
  vi.stubGlobal('localStorage', {
    getItem: (k: string) => store[k] ?? null,
    setItem: (k: string, v: string) => { store[k] = v; },
  });
});

// Детерминированный словарь: проверяем выбор реплики, а не переводы.
const TR: Record<string, string> = {
  'pet.hello': 'HELLO', 'pet.record': 'REC {wpm}', 'pet.recovery': 'BACK {keys}',
  'pet.streak': 'STREAK {n}', 'pet.forecast': 'FC {n}/{target}', 'pet.weak': 'WEAK {keys}',
};
const tr = (k: string) => TR[k] ?? k;
const base = (over: Partial<PetFacts> = {}): PetFacts => ({
  record: null, recovery: [], streak: 0, streakSaid: 0, forecast: null, weak: [], ...over,
});

describe('питомец говорит делом — выбор реплики', () => {
  it('рекорд важнее всего', () => {
    expect(pickLine(base({ record: 61, recovery: ['f', 'j'], streak: 30, weak: ['a', 's', 'd'] }), tr).text).toBe('REC 61');
  });

  it('просевшие клавиши — от двух, заглавными', () => {
    expect(pickLine(base({ recovery: ['f'] }), tr).key).toBe('pet.hello');
    expect(pickLine(base({ recovery: ['f', 'j'] }), tr).text).toBe('BACK F J');
  });

  it('стрик отмечается на пороге и только один раз', () => {
    const at7 = pickLine(base({ streak: 7, streakSaid: 3 }), tr);
    expect(at7.text).toBe('STREAK 7');
    expect(at7.streakMark).toBe(7);
    expect(pickLine(base({ streak: 7, streakSaid: 7 }), tr).key).toBe('pet.hello');
    // между порогами (5 дней, отмечен 3) — не хвалим каждый день
    expect(pickLine(base({ streak: 5, streakSaid: 3 }), tr).key).toBe('pet.hello');
    expect(STREAK_MARKS[0]).toBe(3);
  });

  it('прогноз — только достоверный и в разумных пределах', () => {
    expect(pickLine(base({ forecast: { sessions: 12, target: 40, certainty: 0.8 } }), tr).text).toBe('FC 12/40');
    expect(pickLine(base({ forecast: { sessions: 12, target: 40, certainty: 0.3 } }), tr).key).toBe('pet.hello');
    expect(pickLine(base({ forecast: { sessions: 400, target: 90, certainty: 0.9 } }), tr).key).toBe('pet.hello');
  });

  it('слабые клавиши — от трёх, называем три', () => {
    expect(pickLine(base({ weak: ['a', 's'] }), tr).key).toBe('pet.hello');
    expect(pickLine(base({ weak: ['a', 's', 'd', 'f'] }), tr).text).toBe('WEAK A S D');
  });
});

describe('рекорд из экрана набора — говорится при следующем появлении', () => {
  it('запоминается в конце сессии и забирается ровно один раз', () => {
    notePossibleRecord(50, [{ wpm: 30 }, { wpm: 40 }, { wpm: 50 }]);
    expect(collectFacts().record).toBe(50);
    expect(collectFacts().record).toBeNull(); // второй раз не хвалим
  });

  it('не рекорд и первая сессия в истории — не запоминаются', () => {
    notePossibleRecord(35, [{ wpm: 40 }, { wpm: 35 }]);
    notePossibleRecord(60, [{ wpm: 60 }]);
    expect(collectFacts().record).toBeNull();
  });
});

describe('реплики питомца переведены', () => {
  it('все 7 языков: есть текст и он не английский (кроме en)', () => {
    const keys = ['pet.hello', 'pet.record', 'pet.recovery', 'pet.streak', 'pet.forecast', 'pet.weak', 'set.pet'];
    setLang('en');
    const en = Object.fromEntries(keys.map((k) => [k, t(k)]));
    for (const k of keys) expect(en[k]).not.toBe(k);
    for (const l of LANGS) {
      if (l === 'en') continue;
      setLang(l);
      for (const k of keys) {
        expect(t(k), `${l} ${k}`).not.toBe(k);
        expect(t(k), `${l} ${k} совпал с английским`).not.toBe(en[k]);
      }
    }
    setLang('en');
  });
});
