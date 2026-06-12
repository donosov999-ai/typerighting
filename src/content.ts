// Модель упражнения (нормализована из 4 банков оригинального TypeRIGHTing).
export type Bank = 'abandon' | 'engRus' | 'letterByLetter' | 'poemHymn';

export interface Exercise {
  id: string;
  bank: Bank;
  title: string;
  hint?: string;     // перевод/контекст (для engRus)
  lines: string[];   // строки для печати, построчно
}

export const BANK_LABELS: Record<Bank, string> = {
  abandon: 'Слова в предложениях',
  engRus: 'Англ↔Рус (с переводом)',
  letterByLetter: 'По буквам (наращивание)',
  poemHymn: 'Стихи и гимны',
};

export const BANK_DESC: Record<Bank, string> = {
  abandon: 'Печатай предложение с новым словом — словарный запас + скорость.',
  engRus: 'Слово с переводом + предложение. Перевод-подсказка над образцом.',
  letterByLetter: 'Слово печатается по нарастающей: a, ab, aba… — постановка пальцев.',
  poemHymn: 'Стихи и гимны по строфам (4–8 строк) — ритм и выносливость печати.',
};

let cache: Exercise[] | null = null;

export async function loadExercises(): Promise<Exercise[]> {
  if (cache) return cache;
  const res = await fetch('/content/exercises.json');
  cache = (await res.json()) as Exercise[];
  return cache;
}

export function exercisesOfBank(all: Exercise[], bank: Bank): Exercise[] {
  return all.filter((e) => e.bank === bank);
}
