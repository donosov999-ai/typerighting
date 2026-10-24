/* typerighting-content · VER 7 · 17.09.2026 */
// Модель упражнения (нормализована из 4 банков оригинального TypeRIGHT).
export type Bank = 'abandon' | 'engRus' | 'letterByLetter' | 'poemHymn' | 'classic' | 'ruWords' | 'ruPhrases' | 'digits';

export interface Exercise {
  id: string;
  bank: Bank;
  title: string;
  hint?: string;     // перевод/контекст (для engRus)
  lines: string[];   // строки для печати, построчно
}

// Подписи банков — в i18n.ts (ключи bank.<id> / bank.<id>.desc)
export const BANKS: Bank[] = ['classic', 'poemHymn', 'ruWords', 'ruPhrases', 'digits'];

let cache: Exercise[] | null = null;

export async function loadExercises(): Promise<Exercise[]> {
  if (cache) return cache;
  // относительный путь: работает и в Tauri, и в вебе из подпапки
  const res = await fetch('content/exercises.json');
  cache = ((await res.json()) as Exercise[]).filter(e => BANKS.includes(e.bank));
  return cache;
}

export function exercisesOfBank(all: Exercise[], bank: Bank): Exercise[] {
  // Hidden legacy banks must also stay inaccessible outside the selector.
  if (!BANKS.includes(bank)) return [];
  return all.filter((e) => e.bank === bank);
}
