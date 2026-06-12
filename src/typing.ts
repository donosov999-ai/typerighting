// Движок печати: сравнение ввода с образцом посимвольно, ошибки, статистика.
// Воспроизводит механику оригинала: посимвольная подсветка + (опционально) блок при ошибке.

export interface TypingStats {
  typed: number;       // верно введённых символов
  errors: number;      // суммарно ошибочных нажатий
  elapsedMs: number;
  wpm: number;         // (слова=символы/5) в минуту, по верным символам
  accuracy: number;    // 0..100
}

export interface TypingState {
  /** плоский образец (все строки соединены '\n') */
  pattern: string;
  pos: number;         // текущая позиция курсора (индекс ожидаемого символа)
  errors: number;
  startedAt: number | null;
  finishedAt: number | null;
  /** per-char статус: 'pending' | 'correct' | 'wrong' (зафиксированная ошибка в free-режиме) */
  marks: Uint8Array;   // 0 pending, 1 correct, 2 wrong-now
}

export const MARK = { PENDING: 0, CORRECT: 1, WRONG: 2 } as const;

export function createState(lines: string[]): TypingState {
  const pattern = lines.join('\n');
  return {
    pattern,
    pos: 0,
    errors: 0,
    startedAt: null,
    finishedAt: null,
    marks: new Uint8Array(pattern.length),
  };
}

export interface KeyResult {
  accepted: boolean;   // символ принят (курсор продвинулся)
  wrong: boolean;      // нажатие было ошибочным
  finished: boolean;
}

/**
 * Обработать введённый символ.
 * @param blockOnError true = не пускать дальше, пока не нажат верный символ (как оригинал)
 */
export function pressChar(st: TypingState, ch: string, blockOnError: boolean): KeyResult {
  if (st.finishedAt !== null) return { accepted: false, wrong: false, finished: true };
  if (st.startedAt === null) st.startedAt = Date.now();

  const expected = st.pattern[st.pos];
  // Enter/возврат каретки в образце — ожидаем '\n'
  const norm = ch === '\r' ? '\n' : ch;
  const ok = norm === expected;

  if (ok) {
    st.marks[st.pos] = MARK.CORRECT;
    st.pos++;
    const finished = st.pos >= st.pattern.length;
    if (finished) st.finishedAt = Date.now();
    return { accepted: true, wrong: false, finished };
  }

  // ошибка
  st.errors++;
  if (blockOnError) {
    // не продвигаемся — курсор стоит, символ помечается «ждёт верного»
    return { accepted: false, wrong: true, finished: false };
  }
  // free-режим: фиксируем ошибку и идём дальше
  st.marks[st.pos] = MARK.WRONG;
  st.pos++;
  const finished = st.pos >= st.pattern.length;
  if (finished) st.finishedAt = Date.now();
  return { accepted: true, wrong: true, finished };
}

export function backspace(st: TypingState): void {
  if (st.finishedAt !== null) return;
  if (st.pos > 0) {
    st.pos--;
    st.marks[st.pos] = MARK.PENDING;
  }
}

export function stats(st: TypingState): TypingStats {
  const now = st.finishedAt ?? Date.now();
  const elapsedMs = st.startedAt ? now - st.startedAt : 0;
  let correct = 0;
  for (let i = 0; i < st.pos; i++) if (st.marks[i] === MARK.CORRECT) correct++;
  const minutes = elapsedMs / 60000;
  const wpm = minutes > 0 ? Math.round(correct / 5 / minutes) : 0;
  const totalKeys = correct + st.errors;
  const accuracy = totalKeys > 0 ? Math.round((correct / totalKeys) * 100) : 100;
  return { typed: correct, errors: st.errors, elapsedMs, wpm, accuracy };
}
