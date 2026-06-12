# TypeRIGHTing 2.0

Тренажёр слепой печати. Переписан со старого `.NET 2.0 WinForms` приложения на **веб (Vite + TypeScript)** для последующей упаковки в кроссплатформенный десктоп через **Tauri** (Mac / Windows / Linux).

*Автор: Denis Onosov (ODV999) + ⚠️ Информация конфиденциальная*

## Что сделано (v2.0.0)

- **Контент извлечён 1:1** из оригинала (декомпиляция .NET → JSON): **4846 упражнений** в 4 банках (1472 + 497 + 2845 + 32; до нарезки стихов на строфы было 4818 — цифра «5549» из ранних заметок была неточной).
- **Движок печати** (`src/typing.ts`) — посимвольное сравнение, подсветка верно/неверно, блок при ошибке (как оригинал), статистика (зн/мин, точность, ошибки, время).
- **UI** (`src/main.ts`) — выбор банка, навигация по упражнениям, режимы «спрятать образец» / «звук ошибки» / «блок при ошибке» / «клавиатура».
- **Схема клавиатуры из оригинала** (`public/images/keyboard.jpg`, 920×380) — раскладка ЙЦУКЕН↔QWERTY со стрелками соответствия рус/англ букв, показывается под областью набора (вкл по умолчанию). Остальные ассеты оригинала и их описание — `public/images/ASSETS.md`.
- Звук ошибки — Web Audio (без внешних файлов).

## Банки упражнений

| Банк | Кол-во | Что |
|---|---:|---|
| `abandon` | 1472 | слово + предложение с ним (словарь + скорость) |
| `engRus` | 497 | англ↔рус: перевод-подсказка над образцом |
| `letterByLetter` | 2845 | наращивание слова по буквам (a, ab, aba…) |
| `poemHymn` | 32 | стихи/гимны ПО СТРОФАМ (Ворон Э. По 18 строф, гимны; нарезка: `scripts/split-poems.mjs`) |

Источник нормализации: `public/content/exercises.json` (из сырых `abandon/engRus/letterByLetter/poemHymn.json`).

## Запуск (веб)

```bash
npm install
npm run dev      # http://localhost:8006 (порт фиксирован в vite.config.ts — его ждёт Tauri devUrl)
npm run build    # dist/ — статика для Tauri / веб-хостинга
```

## Desktop (Tauri 2)

```bash
npm run tauri dev                              # дев-окно (поднимает vite на :8006 сам)
npm run tauri build -- --target aarch64-apple-darwin   # локальный .app + .dmg (macOS arm64)
```

Скаффолдинг: `src-tauri/` (конфиг `tauri.conf.json`: `frontendDist ../dist`, `beforeBuildCommand npm run build`). Иконка генерируется из `src-tauri/icon-source.png` (исходник — `src-tauri/make-icon.py`) командой `cargo tauri icon src-tauri/icon-source.png`.

### Кроссбилд (GitHub Actions)

`.github/workflows/build.yml` — триггер: push в `main`, тег `v*`, ручной запуск. Матрица:

| Job | Артефакты |
|---|---|
| macos-arm | `.app` (tar.gz) + `.dmg` (arm64) |
| windows-x64 | `.exe` (NSIS setup) + `.msi` |
| linux-x64 | `.AppImage` + `.deb` + `.rpm` |

Тег `vX.Y.Z` дополнительно собирает **GitHub Release** со всеми бинарями. Подписи/нотаризации нет (приложение бесплатное): на macOS первый запуск — правый клик → «Открыть» (Gatekeeper).

Репо: `github.com/donosov999-ai/typerighting`.

## TODO (следующие этапы)

- [x] **Tauri-обёртка** + GitHub Actions кроссбилд (Mac/Win/Linux), как в psygames-native — *готово 12.06.2026*.
- [x] **Разбить `poemHymn`** на строфы — *готово 12.06.2026* (4 поэмы → 32 строфы, `scripts/split-poems.mjs`, идемпотентен).
- [x] Сохранение прогресса/рекордов (localStorage `tr_progress_<bank>`) — *готово 12.06.2026*: лучшая скорость/точность по банку, счётчик пройденных, продолжение с места.
- [ ] Интерактивная подсветка следующей клавиши поверх схемы (статичная схема клавиатуры из оригинала уже в UI).
- [ ] Убран серийник оригинала (защита не переносится).

## История

Оригинал — `.NET 2.0 WinForms`, namespace `TR.Forms`. Декомпилированные исходники: `~/Downloads/TypeRIGHTing_source/`. Лицензионная проверка (`CheckSerialNumber`, 20-симв. ключ) в новую версию не переносится.
