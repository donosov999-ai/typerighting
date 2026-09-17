import { describe, it, expect } from 'vitest';
import { layoutEvidence, LayoutDetector } from './layout-detect';

describe('улика о раскладке из пары code/key', () => {
  it('AZERTY, QWERTZ и QWERTY различаются по местам букв', () => {
    expect(layoutEvidence('KeyQ', 'a')).toBe('azerty');
    expect(layoutEvidence('KeyW', 'z')).toBe('azerty');
    expect(layoutEvidence('KeyY', 'z')).toBe('qwertz');
    expect(layoutEvidence('KeyZ', 'y')).toBe('qwertz');
    expect(layoutEvidence('KeyY', 'y')).toBe('qwerty');
    expect(layoutEvidence('KeyZ', 'Z')).toBe('qwerty');
  });
  it('клавиши, одинаковые во всех раскладках, и кириллица — без улики', () => {
    expect(layoutEvidence('KeyF', 'f')).toBeNull();
    expect(layoutEvidence('KeyQ', 'й')).toBeNull();
    expect(layoutEvidence('', 'a')).toBeNull();
  });
});

describe('детектор: физическая раскладка', () => {
  it('французская клавиатура распознаётся после трёх улик', () => {
    const d = new LayoutDetector();
    d.feed('KeyQ', 'a', 'a'); d.feed('KeyW', 'z', 'z');
    expect(d.verdict().physical).toBeNull(); // двух мало
    d.feed('KeyA', 'q', 'q');
    expect(d.verdict().physical).toBe('azerty');
  });
  it('немецкая — по Y/Z, а Q/A/W её не путают с QWERTY', () => {
    const d = new LayoutDetector();
    for (let i = 0; i < 4; i++) d.feed('KeyQ', 'q', 'q'); // одинаково у QWERTY и QWERTZ
    expect(d.verdict().physical).toBeNull();
    d.feed('KeyY', 'z', 'z'); d.feed('KeyZ', 'y', 'y'); d.feed('KeyY', 'z', 'z');
    expect(d.verdict().physical).toBe('qwertz');
  });
  it('QWERTY подтверждается только различающими клавишами', () => {
    const d = new LayoutDetector();
    d.feed('KeyY', 'y', 'y'); d.feed('KeyZ', 'z', 'z');
    expect(d.verdict().physical).toBe('qwerty');
  });
});

describe('детектор: не тот алфавит', () => {
  it('текст на русском, печатается латиница — сигнал после 4 из 5', () => {
    const d = new LayoutDetector();
    const pairs: [string, string, string][] = [['KeyD', 'd', 'в'], ['KeyJ', 'j', 'о'], ['KeyK', 'k', 'л'], ['KeyL', 'l', 'д']];
    d.feed(...pairs[0]); d.feed(...pairs[1]); d.feed(...pairs[2]);
    expect(d.verdict().scriptMismatch).toBeNull();
    d.feed(...pairs[3]);
    expect(d.verdict().scriptMismatch).toBe('latin');
  });
  it('случайная опечатка не поднимает тревогу, пробелы не считаются', () => {
    const d = new LayoutDetector();
    d.feed('KeyD', 'в', 'в'); d.feed('KeyJ', 'j', 'о'); d.feed('Space', ' ', ' '); d.feed('KeyK', 'л', 'л'); d.feed('KeyL', 'д', 'д');
    expect(d.verdict().scriptMismatch).toBeNull();
  });
  it('после переключения раскладки сигнал сбрасывается', () => {
    const d = new LayoutDetector();
    for (const [c, k, e] of [['KeyD', 'd', 'в'], ['KeyJ', 'j', 'о'], ['KeyK', 'k', 'л'], ['KeyL', 'l', 'д']] as [string, string, string][]) d.feed(c, k, e);
    expect(d.verdict().scriptMismatch).toBe('latin');
    d.resetScript();
    expect(d.verdict().scriptMismatch).toBeNull();
  });
});
