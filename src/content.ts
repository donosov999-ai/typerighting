// Модель упражнения (нормализована из 4 банков оригинального TypeRIGHTing).
export type Bank = 'abandon' | 'engRus' | 'letterByLetter' | 'poemHymn' | 'classic';

export interface Exercise {
  id: string;
  bank: Bank;
  title: string;
  hint?: string;     // перевод/контекст (для engRus)
  lines: string[];   // строки для печати, построчно
}

// Подписи банков — в i18n.ts (ключи bank.<id> / bank.<id>.desc)
export const BANKS: Bank[] = ['abandon', 'engRus', 'letterByLetter', 'poemHymn', 'classic'];

let cache: Exercise[] | null = null;

export async function loadExercises(): Promise<Exercise[]> {
  if (cache) return cache;
  // относительный путь: работает и в Tauri, и в вебе из подпапки
  const res = await fetch('content/exercises.json');
  cache = (await res.json()) as Exercise[];
  return cache;
}

export function exercisesOfBank(all: Exercise[], bank: Bank): Exercise[] {
  return all.filter((e) => e.bank === bank);
}
