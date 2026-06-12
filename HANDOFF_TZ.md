# ТЗ: продолжение работы над TypeRIGHTing 2.0

> Передача в новый чат. Самодостаточно — читать холодно, без доступа к прошлой сессии.
> *Проект Denis Onosov (ODV999). ⚠️ Конфиденциально.*
> Дата создания ТЗ: 12.06.2026.

---

## 1. Что это

**TypeRIGHTing** — тренажёр слепой печати (английский + русский). Был старой Windows-программой на `.NET 2.0 WinForms` (Денис её «давно собирал»). Задача — **переписать в кроссплатформенное desktop-приложение** на современном стеке (веб-фронт + Tauri), без старого .NET. Решение Дениса зафиксировано: именно отдельное desktop-приложение (не часть других проектов).

Уже сделана миграция веб-ядра (v2.0.0). Этот документ — что дальше.

## 2. Где что лежит (абсолютные пути, macOS)

| Путь | Что |
|---|---|
| `/Users/denisonosov/dev/typerighting/` | **рабочий проект** (Vite + TypeScript). git инициализирован, коммит локальный, на GitHub НЕ залит |
| `/Users/denisonosov/dev/typerighting/public/content/exercises.json` | нормализованный контент — **5549 упражнений** (источник истины для приложения) |
| `/Users/denisonosov/dev/typerighting/public/content/{abandon,engRus,letterByLetter,poemHymn}.json` | сырые банки (как в оригинале) |
| `/Users/denisonosov/Downloads/TypeRIGHTing_source/` | декомпилированный C#-исходник оригинала (для справки по механике) |
| `/Users/denisonosov/Downloads/TypeRIGHTing.exe` | оригинал (.NET сборка) |
| `/Users/denisonosov/Downloads/TypeRIGHTing_setup_allwin.exe` | оригинальный NSIS-инсталлер |

⚠️ **Проект НЕ в ~/Downloads намеренно** — встроенный preview-сервер не имеет доступа к папке Downloads (защита macOS TCC). Держать в `~/dev/`.

## 3. Что уже готово (v2.0.0)

- **Контент извлечён 1:1** из декомпилированного .NET → JSON. 4 банка:
  | Банк | Кол-во | Структура `exercises.json` |
  |---|---:|---|
  | `abandon` | 1472 | слово + предложение с ним |
  | `engRus` | 497 | англ слово + перевод (hint) + англ предложение печатать |
  | `letterByLetter` | 2845 | наращивание слова: `word a ab aba abandon` |
  | `poemHymn` | 4 | литература (Ворон Э.По и др.) — ⚠️ грубо нарезано |
- **Движок печати** `src/typing.ts` — посимвольное сравнение, подсветка верно/неверно, блок при ошибке (как оригинал), статистика (зн/мин÷5, точность, ошибки, время).
- **UI** `src/main.ts` + `src/style.css` — выбор банка, навигация пред/след, режимы: спрятать образец / звук ошибки (Web Audio) / блок при ошибке.
- Проверено в preview: все 4 банка, печать, блок, прохождение до экрана «Готово».

### Модель упражнения (`src/content.ts`)
```ts
interface Exercise {
  id: string;
  bank: 'abandon' | 'engRus' | 'letterByLetter' | 'poemHymn';
  title: string;     // заголовок (слово)
  hint?: string;     // перевод/контекст (engRus)
  lines: string[];   // строки для печати, построчно
}
```

## 4. Как запустить и проверить

```bash
cd /Users/denisonosov/dev/typerighting
npm install          # если node_modules нет
npm run dev          # Vite, http://localhost:8006
npm run build        # сборка статики в dist/ (нужна для Tauri)
npx tsc --noEmit     # проверка типов (должно быть 0 ошибок)
```

## 5. ЗАДАЧИ (по приоритету)

### ✅ ЗАДАЧА 1 — ВЫПОЛНЕНО 12.06.2026
Tauri 2 обёртка готова (`src-tauri/`), репо создан и запушен: `github.com/donosov999-ai/typerighting` (**private** — публичность не была явно согласована; открыть: `gh repo edit donosov999-ai/typerighting --visibility public --accept-visibility-change-consequences`). CI: `.github/workflows/build.yml`, триггер — тег `v*` или вручную; артефакты .app/.dmg + .exe/.msi + .AppImage/.deb/.rpm, на тег создаётся GitHub Release. Тег v2.0.0 поставлен. Бонус: в UI возвращена схема клавиатуры из оригинала (`public/images/keyboard.jpg`, переключатель «Клавиатура»).

<details><summary>Исходная постановка</summary>
Превратить веб-приложение в устанавливаемое desktop (Mac/Windows/Linux).
- Эталон уже есть в системе: `/Users/denisonosov/dev/psygames/src-tauri/` (Tauri 2) + его GitHub Actions workflow собирает Mac/Win артефакты. Копировать паттерн оттуда.
- Шаги: `npm create tauri-app` поверх (или вручную `src-tauri/`), указать `frontendDist: "../dist"`, `devUrl: "http://localhost:8006"`, `beforeBuildCommand: "npm run build"`.
- Требует Rust (`rustup`) — проверить/поставить.
- GitHub Actions: матрица macos-latest + windows-latest + ubuntu, артефакты `.dmg`/`.app`, `.msi`/`.exe`, `.AppImage`/`.deb`. Тег-триггер как в psygames.
- Аккаунт GitHub владельца: **`donosov999-ai`** (email `d.onosov999@gmail.com`). Создать репо `typerighting`, запушить.
</details>

### ✅ ЗАДАЧА 2 — ВЫПОЛНЕНО 12.06.2026
`scripts/split-poems.mjs` (идемпотентен): блоки между `* * *` = строфы, длинные дорезаются по 6 строк. 4 поэмы → **32 строфы** по 4–8 строк («Ворон» = 18 строф, автор → hint). exercises.json: 4818 → 4846 (реальный счёт; «5549» из ранних заметок был неточным).

### ✅ ЗАДАЧА 3 — ВЫПОЛНЕНО 12.06.2026
Ключ `tr_progress_<bank>`: лучшие скорость/точность, счётчик пройденных (без дублей), продолжение с последнего места. Строка статуса в шапке банка. Проверено в превью включая перезагрузку страницы.

### 🟢 ЗАДАЧА 4 — Виртуальная клавиатура (опц.)
Подсветка следующей клавиши под образцом — помощь новичкам слепой печати.

### ⚪ Доработки UX
- Опция «случайный порядок» упражнений.
- Backspace в free-режиме (блок выкл) уже есть; проверить край.
- Адаптив под мобильную ширину (если захотят web-версию на телефоне).

## 6. Грабли / окружение

- **dotnet для повторного извлечения контента** (если понадобится): поставлен через `brew install dotnet`. Перед запуском:
  ```bash
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
  export PATH="/opt/homebrew/opt/dotnet/libexec:$PATH:$HOME/.dotnet/tools"
  ```
  Декомпилятор: `ilspycmd` (поставлен `dotnet tool install -g ilspycmd`). NSIS-распаковка: `7z` (поставлен `brew install p7zip`).
- **Серийная защита оригинала** (`CheckSerialNumber`, 20-симв. ключ) — в новую версию НЕ переносить, приложение бесплатное/без лицензии.
- Звук ошибки сейчас синтезируется через Web Audio (`beep()` в `src/main.ts`) — внешние звуковые файлы из оригинала (`Sounds.dll`) не тащили.
- preview-сервер берёт конфиг из `launch.json`; если в новом чате рабочая папка иная — просто `npm run dev` напрямую (порт 8006).

## 7. Стиль работы (важно для ODV999)
- Прямо, по делу, цифры/сроки, таблицы. Слово «протокол» в любой форме ЗАПРЕЩЕНО (замены: программа/план/схема/курс).
- Не упрощать формулировки без согласия. Доделывать задачу до конца (изменил → проверил → зафиксировал).
- При создании гайда/инструкции подпись: *Автор: Denis Onosov (ODV999) + ⚠️ Информация конфиденциальная*.
