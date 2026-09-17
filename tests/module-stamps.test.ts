/* typerighting-module-stamps-test · VER 1 · 17.09.2026 */
// Лежит вне src/: читает файлы через node:fs, а tsc проекта (include: src, без @types/node) его бы не собрал.
// PROJECT_REF_RULES §10: «версия и дата в каждом модуле». Метку легко стереть при правке
// первой строки — тест держит ФОРМАТ на ключевых модулях (номер бампает правящий: VER+1 и дата).
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import pkg from '../package.json';

const STAMP = /typerighting-[\w-]+ · VER \d+ · \d\d\.\d\d\.\d{4}/;
const MODULES = [
  'src/typing.ts', 'src/keyboard.ts', 'src/i18n.ts', 'src/stats-store.ts', 'src/account.ts',
  'src/companion.ts', 'src/content.ts', 'src/ngram.ts', 'src/kids.ts', 'src/course.ts', 'src/learn.ts',
  'src/compete.ts', 'src/memorize.ts', 'src/recall.ts', 'src/updater.ts', 'src/main.ts',
  'src/session-log.ts', 'src/pet.ts', 'src/layout-detect.ts',
  'src-tauri/src/lib.rs', '.github/workflows/build.yml', '.github/workflows/android.yml', '.github/workflows/ios.yml',
];

describe('метки версий модулей (§10)', () => {
  it.each(MODULES)('%s — первая строка несёт метку', (f) => {
    const first = readFileSync(f, 'utf8').split('\n', 1)[0];
    expect(first).toMatch(STAMP);
  });

  it('версия приложения совпадает в package.json, tauri.conf.json и Cargo.toml', () => {
    const tauri = JSON.parse(readFileSync('src-tauri/tauri.conf.json', 'utf8')).version;
    const cargo = /^version\s*=\s*"([^"]+)"/m.exec(readFileSync('src-tauri/Cargo.toml', 'utf8'))?.[1];
    expect(tauri).toBe(pkg.version);
    expect(cargo).toBe(pkg.version);
  });
});
