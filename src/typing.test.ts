import { describe, it, expect } from 'vitest';
import { createState, pressChar, backspace, stats, MARK } from './typing';

describe('движок печати typing.ts', () => {
  it('createState соединяет строки через \\n и инициализирует', () => {
    const st = createState(['ab', 'cd']);
    expect(st.pattern).toBe('ab\ncd');
    expect(st.pos).toBe(0);
    expect(st.marks.length).toBe(5);
    expect(st.finishedAt).toBeNull();
    expect(st.startedAt).toBeNull();
  });

  it('верный символ продвигает курсор и помечает CORRECT', () => {
    const st = createState(['ab']);
    const r = pressChar(st, 'a', true);
    expect(r.accepted).toBe(true);
    expect(r.wrong).toBe(false);
    expect(st.pos).toBe(1);
    expect(st.marks[0]).toBe(MARK.CORRECT);
  });

  it('ошибка в блок-режиме НЕ двигает курсор, считает errors', () => {
    const st = createState(['ab']);
    const r = pressChar(st, 'x', true);
    expect(r.accepted).toBe(false);
    expect(r.wrong).toBe(true);
    expect(st.pos).toBe(0);
    expect(st.errors).toBe(1);
  });

  it('ошибка в free-режиме фиксирует WRONG и идёт дальше', () => {
    const st = createState(['ab']);
    const r = pressChar(st, 'x', false);
    expect(r.accepted).toBe(true);
    expect(r.wrong).toBe(true);
    expect(st.pos).toBe(1);
    expect(st.marks[0]).toBe(MARK.WRONG);
  });

  it('\\r нормализуется в \\n (Enter в образце)', () => {
    const st = createState(['a', 'b']); // pattern: a\nb
    pressChar(st, 'a', true);
    const r = pressChar(st, '\r', true);
    expect(r.accepted).toBe(true);
    expect(st.pos).toBe(2);
  });

  it('finished когда весь образец набран', () => {
    const st = createState(['ab']);
    pressChar(st, 'a', true);
    const r = pressChar(st, 'b', true);
    expect(r.finished).toBe(true);
    expect(st.finishedAt).not.toBeNull();
  });

  it('ввод после finished игнорируется', () => {
    const st = createState(['a']);
    pressChar(st, 'a', true);
    const r = pressChar(st, 'a', true);
    expect(r.accepted).toBe(false);
    expect(r.finished).toBe(true);
  });

  it('backspace откатывает курсор и сбрасывает mark', () => {
    const st = createState(['ab']);
    pressChar(st, 'a', true);
    backspace(st);
    expect(st.pos).toBe(0);
    expect(st.marks[0]).toBe(MARK.PENDING);
  });

  it('stats: accuracy = correct / (correct + errors)', () => {
    const st = createState(['abc']);
    pressChar(st, 'a', true); // correct
    pressChar(st, 'x', true); // error (блок — pos стоит)
    pressChar(st, 'b', true); // correct
    pressChar(st, 'c', true); // correct, finish
    const s = stats(st);
    expect(s.typed).toBe(3);
    expect(s.errors).toBe(1);
    expect(s.accuracy).toBe(75); // 3 / (3+1)
  });

  it('stats без ошибок — точность 100', () => {
    const st = createState(['ok']);
    pressChar(st, 'o', true);
    pressChar(st, 'k', true);
    expect(stats(st).accuracy).toBe(100);
  });
});
