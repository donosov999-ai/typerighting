# iOS-проверка кандидата Flutter (29.10.2026, typerighting-claude-mac)

Симулятор «TypeFree candidate», iPhone 17 Pro, iOS 27.0 (рантайм уже стоял на маке — скачивание не понадобилось), Xcode 27.1, сборка из ветки `codex/typefree-flutter-20261025`. Без окон: `simctl boot`, снимки `simctl io screenshot`.

1. `flutter test integration_test/ios_smoke_test.dart -d <udid>` — настоящий `main()` и нативное хранилище: первый запуск → «Добро пожаловать» → профиль «Классический» → новый репозиторий читает выбор с диска iOS → телефон без клавиатуры открывает компаньон (правило исходника) → «Всё равно открыть тренажёр» → «Тренировка» → «Русские слова» → три клавиши по одной, точность 100 %. **PASS** (`integration-result.txt`).
2. `01-clean-install-welcome.png` — чистая установка (flutter test без `--no-uninstall` удаляет приложение): экран A1.
3. Прогон с `--no-uninstall`, затем поверх установлена обычная сборка и запущена заново: `02-after-update-today.png` — сразу «Сегодня», без приветствия. Данные: `Library/Application Support/typefree.flutter.candidate.v1.json` + `.backup`. Хранилище переживает перезапуск и обновление приложения.

Не проверено здесь: звук на iOS, экспорт файла через системное меню, ввод с аппаратной клавиатуры.
