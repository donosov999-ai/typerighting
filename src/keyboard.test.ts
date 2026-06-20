import { describe, it, expect } from 'vitest';
import { bridgeChar, findKey, keyIdFor } from './keyboard';

describe('мост раскладок bridgeChar (физическая клавиша поверх раскладки ОС)', () => {
  it('рус-раскладка для англ образца: ф → a', () => {
    expect(bridgeChar('ф', 'a')).toBe('a');
  });
  it('англ-раскладка для рус образца: a → ф', () => {
    expect(bridgeChar('a', 'ф')).toBe('ф');
  });
  it('заглавная сохраняет регистр: Ф → A', () => {
    expect(bridgeChar('Ф', 'a')).toBe('A');
  });
  it('совпадение языка символ не трогает', () => {
    expect(bridgeChar('a', 'a')).toBe('a');
    expect(bridgeChar('ф', 'ф')).toBe('ф');
  });
  it('не-буква возвращается как есть', () => {
    expect(bridgeChar('1', 'a')).toBe('1');
  });
});

describe('поиск клавиш findKey / keyIdFor', () => {
  it('латинская буква находит клавишу', () => {
    expect(findKey('a', false)).not.toBeNull();
  });
  it('русская буква находит клавишу', () => {
    expect(findKey('ф', true)).not.toBeNull();
  });
  it('keyIdFor возвращает id клавиши', () => {
    expect(keyIdFor('a', false)).toBeTruthy();
  });
  it('a и ф — одна физическая клавиша (QWERTY A = ЙЦУКЕН Ф)', () => {
    expect(keyIdFor('a', false)).toBe(keyIdFor('ф', true));
  });
});
