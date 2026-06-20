import { describe, it, expect } from 'vitest';
import { mergeProgress } from './account';

describe('слияние прогресса account.ts (рекорды растут только вверх)', () => {
  it('числовые рекорды берутся по максимуму', () => {
    expect(mergeProgress({ tr_span_best: '8' }, { tr_span_best: '12' }).tr_span_best).toBe('12');
    expect(mergeProgress({ tr_span_best: '15' }, { tr_span_best: '9' }).tr_span_best).toBe('15');
  });

  it('новые локальные ключи добавляются к серверным', () => {
    const m = mergeProgress({ tr_name: 'Alex' }, { tr_compete: '{"wpm":40}' });
    expect(m.tr_name).toBe('Alex');
    expect(m.tr_compete).toBe('{"wpm":40}');
  });

  it('звёзды по уровням сливаются по максимуму (deep-merge)', () => {
    const server = { tr_kids: JSON.stringify({ stars: { 1: 3, 2: 1 } }) };
    const local = { tr_kids: JSON.stringify({ stars: { 2: 3, 3: 2 } }) };
    const merged = JSON.parse(mergeProgress(server, local).tr_kids);
    expect(merged.stars).toEqual({ 1: 3, 2: 3, 3: 2 });
  });

  it('история (массив) — берётся более длинная', () => {
    const m = mergeProgress({ tr_h: '[1,2]' }, { tr_h: '[1,2,3,4]' });
    expect(JSON.parse(m.tr_h)).toHaveLength(4);
  });
});
