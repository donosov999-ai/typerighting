#!/usr/bin/env node
/* typerighting-fetch-mascot · VER 2 · 17.09.2026 */
/**
 * Подтягивает движок питомца и пак скина в public/mascot/ перед сборкой (npm prebuild/predev).
 *
 * 🔴 ПОЧЕМУ НЕ ЛЕЖИТ В РЕПО. Репозиторий приложения ПУБЛИЧНЫЙ, а donosov999-ai/mascot-engine —
 * PRIVATE (шапка движка «(c) Denis Onosov · PRIVATE», пак license: proprietary). Коммит вендор-копии
 * выложил бы исходник в публичную историю навсегда (+3,7 МБ бинарников). CDN mascot.asibots.pro
 * и так публично отдаёт ровно эти файлы (замер 17.09.2026: движок 1.1.10 и pack.json совпали
 * байт в байт со сборкой сервиса) — приложение получает то же, что любой сайт с питомцем.
 *
 * ВЕРСИИ ЗАКРЕПЛЕНЫ: смена — правкой констант ниже и ENGINE_VER в src/pet.ts.
 * ПАТЧ tr1: движок пробует HEAD frames.json и на ok считает пак directional. Раздача ассетов Tauri
 * (2.11 manager::get_asset) и dev-Vite на отсутствующий файл отдают index.html со статусом 200 —
 * вместо скина рисовался встроенный вектор. Проверяем тип ответа. Якорь не найден — значит, движок
 * изменился (возможно, починен у себя): пишем без патча и громко предупреждаем.
 *
 * Сеть недоступна — сборка НЕ падает: без файлов питомец просто не появится (pet.ts это переживает).
 */
import { mkdir, writeFile, readFile, access } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ORIGIN = 'https://mascot.asibots.pro';
const ENGINE_VER = '1.1.10';
const PACK = { id: 'typerighting', ver: '1.0.10', states: ['idle', 'type', 'wave'] };
const STAMP = `engine ${ENGINE_VER}+tr1 · pack ${PACK.id} ${PACK.ver}`;

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'public', 'mascot');

const PATCH_FROM = `        fetch(proot + '/frames.json', { method: 'HEAD' }).then(function (r) {
          if (r.ok) { loadPack(opts.pack); return; }`;
const PATCH_TO = `        fetch(proot + '/frames.json', { method: 'HEAD' }).then(function (r) {
          // ПАТЧ TypeRIGHT tr1 (scripts/fetch-mascot.mjs): Tauri и SPA-серверы на отсутствующий файл
          // отдают index.html со статусом 200 — без проверки типа пак принимался за directional.
          var ct = (r.headers && r.headers.get('content-type')) || '';
          if (r.ok && /json/i.test(ct)) { loadPack(opts.pack); return; }`;

async function exists(p) { try { await access(p); return true; } catch { return false; } }

async function get(path) {
  const res = await fetch(`${ORIGIN}/${path}`);
  if (!res.ok) throw new Error(`${path} → HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

async function put(rel, buf) {
  const p = join(out, rel);
  await mkdir(dirname(p), { recursive: true });
  await writeFile(p, buf);
}

async function main() {
  const stampFile = join(out, '.version');
  if (await exists(stampFile) && (await readFile(stampFile, 'utf8')).trim() === STAMP) {
    console.log(`[mascot] уже на месте: ${STAMP}`);
    return;
  }
  try {
    let engine = (await get(`engine/${ENGINE_VER}/biryuzik.js`)).toString('utf8');
    if (engine.includes(PATCH_FROM)) {
      engine = engine.replace(PATCH_FROM, PATCH_TO)
        .replace(/^\/\* biryuzik · VER [^*]*\*\//, `/* biryuzik · VER ${ENGINE_VER}+tr1 · патч TypeRIGHT: HEAD frames.json по content-type */`);
    } else {
      console.warn('[mascot] ⚠️ якорь патча tr1 не найден — движок изменился; пишу без патча, проверь скин в Tauri');
    }
    await put('biryuzik.js', Buffer.from(engine, 'utf8'));
    const base = `packs/${PACK.id}/${PACK.ver}`;
    await put(`${PACK.id}/pack.json`, await get(`${base}/pack.json`));
    for (const s of PACK.states) {
      await put(`${PACK.id}/${s}/anim.json`, await get(`${base}/${s}/anim.json`));
      await put(`${PACK.id}/${s}/walk-strip.png`, await get(`${base}/${s}/walk-strip.png`));
    }
    await writeFile(stampFile, STAMP + '\n');
    console.log(`[mascot] загружено: ${STAMP}`);
  } catch (e) {
    console.warn(`[mascot] ⚠️ не загрузилось (${e.message}) — сборка продолжается без питомца`);
  }
}

await main();
