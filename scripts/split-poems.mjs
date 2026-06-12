// Задача 2 ТЗ: нарезка poemHymn на строфы (строфа = упражнение).
// Источник строф — разделители "* * *" в lines. Блоки длиннее MAX_LINES
// дополнительно режутся по CHUNK строк. Идемпотентно: уже нарезанные
// (id вида phN-sM) пересобираются из сырых блоков не повторно — скрипт
// просто пропускает файл, если ни у одного poemHymn-упражнения нет "* * *".
// Запуск: node scripts/split-poems.mjs
import { readFileSync, writeFileSync } from 'node:fs';

const FILE = new URL('../public/content/exercises.json', import.meta.url);
const MAX_LINES = 8;
const CHUNK = 6;
const SEP = /^\*\s*\*\s*\*$/;

const all = JSON.parse(readFileSync(FILE, 'utf8'));
const poems = all.filter((e) => e.bank === 'poemHymn');
if (!poems.some((p) => p.lines.some((l) => SEP.test(l.trim())))) {
  console.log('poemHymn уже нарезан (нет разделителей "* * *") — ничего не делаю');
  process.exit(0);
}

const rest = all.filter((e) => e.bank !== 'poemHymn');
const out = [];

for (const p of poems) {
  // Разбить по "* * *"
  const blocks = [];
  let cur = [];
  for (const line of p.lines) {
    if (SEP.test(line.trim())) {
      if (cur.length) blocks.push(cur);
      cur = [];
    } else if (line.trim()) {
      cur.push(line);
    }
  }
  if (cur.length) blocks.push(cur);

  // Одинокая первая строка до первого разделителя = автор (Ворон: "Edgar Allan Poe")
  let author;
  if (blocks.length && blocks[0].length === 1 && blocks[0][0].split(' ').length <= 4) {
    author = blocks.shift()[0];
  }

  // Длинные блоки дорезать по CHUNK
  const stanzas = blocks.flatMap((b) => {
    if (b.length <= MAX_LINES) return [b];
    const parts = [];
    for (let i = 0; i < b.length; i += CHUNK) parts.push(b.slice(i, i + CHUNK));
    return parts;
  });

  stanzas.forEach((lines, i) => {
    out.push({
      id: `${p.id}-s${i + 1}`,
      bank: 'poemHymn',
      title: `${p.title} — ${i + 1}/${stanzas.length}`,
      ...(author ? { hint: author } : {}),
      lines,
    });
  });
  console.log(`${p.id} ${p.title}: ${p.lines.length} строк → ${stanzas.length} строф${author ? ` (автор: ${author})` : ''}`);
}

writeFileSync(FILE, JSON.stringify([...rest, ...out]));
console.log(`Итого: ${all.length} → ${rest.length + out.length} упражнений`);
