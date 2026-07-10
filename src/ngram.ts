// N-граммная (марковская) модель символов → фонетически связная генерация
// псевдослов, как «семантическая модель языка» VerseQ. Модель строится из
// корпуса в рантайме; при генерации можно поднимать вероятность «слабых» букв
// БЕЗ нарушения связности (выбор всегда из реальных продолжений корпуса).

export interface NgramModel {
  order: number;
  table: Map<string, Record<string, number>>; // префикс (order-1 симв) → {след.символ: частота}
  starts: string[];                            // префиксы начала слова
  alphabet: string[];                          // буквы языка (для адаптива)
}

const SPACE = ' ';

function normalize(text: string, letters: RegExp): string {
  return text.toLowerCase().split('').map((c) => (letters.test(c) ? c : SPACE)).join('').replace(/\s+/g, SPACE).trim();
}

/** Построить модель порядка `order` (по умолчанию 3 = триграммы). */
export function buildModel(text: string, lang: 'en' | 'ru', order = 3): NgramModel {
  const letters = lang === 'ru' ? /[а-яё]/ : /[a-zà-ÿœæ]/; // латиница + диакритика (é ü ç ß ñ …)
  const norm = SPACE.repeat(order - 1) + normalize(text, letters) + SPACE;
  const table = new Map<string, Record<string, number>>();
  const startsSet = new Set<string>();
  const alpha = new Set<string>();
  for (let i = 0; i + order <= norm.length; i++) {
    const prefix = norm.slice(i, i + order - 1);
    const next = norm[i + order - 1];
    if (next !== SPACE) alpha.add(next);
    let rec = table.get(prefix);
    if (!rec) { rec = {}; table.set(prefix, rec); }
    rec[next] = (rec[next] ?? 0) + 1;
    // префикс — начало слова, если перед ним пробел (т.е. prefix начинается с пробела + буква)
    if (prefix[0] === SPACE && prefix.trim().length > 0) startsSet.add(prefix);
  }
  return { order, table, starts: [...startsSet], alphabet: [...alpha].sort() };
}

function weightedPick(rec: Record<string, number>, weight: Record<string, number> | undefined): string {
  let total = 0;
  const entries = Object.entries(rec);
  for (const [ch, n] of entries) total += n * (weight?.[ch] ?? 1);
  let r = Math.random() * total;
  for (const [ch, n] of entries) { r -= n * (weight?.[ch] ?? 1); if (r <= 0) return ch; }
  return entries[entries.length - 1][0];
}

/**
 * Сгенерировать строку ~targetChars символов из «слов» 3–8 букв.
 * weight[буква] > 1 повышает её встречаемость (адаптив под слабые клавиши).
 * force — набор «слабых» букв: каждое слово ОБЯЗАНО содержать хотя бы одну из них
 *   (гарантия присутствия, как prefix-list у keybr; вес лишь повышает вероятность,
 *   а force повышает плотность дрилла). Слова без нужной буквы отбрасываются в
 *   пределах бюджета попыток — редкая буква не зациклит генерацию.
 */
export function generate(
  m: NgramModel,
  opts: { chars?: number; weight?: Record<string, number>; maxWord?: number; force?: string[] } = {},
): string {
  const target = opts.chars ?? 48;
  const maxWord = opts.maxWord ?? 8;
  const force = opts.force && opts.force.length ? new Set(opts.force) : null;
  if (m.starts.length === 0) return '';
  const out: string[] = [];
  let safety = 0;
  while (out.join(' ').length < target && safety++ < 400) {
    // начать слово со случайного стартового префикса
    let prefix = m.starts[Math.floor(Math.random() * m.starts.length)];
    let word = prefix.trim();
    let guard = 0;
    while (guard++ < maxWord * 2) {
      const rec = m.table.get(prefix);
      if (!rec) break;
      const next = weightedPick(rec, opts.weight);
      if (next === SPACE) break;
      word += next;
      prefix = (prefix + next).slice(-(m.order - 1));
      if (word.length >= maxWord) break;
    }
    if (word.length < 2) continue;
    // форс слабой буквы: слово без целевой буквы пропускаем (бюджет попыток = safety)
    if (force && ![...word].some((c) => force.has(c))) continue;
    out.push(word);
  }
  return out.join(' ');
}
