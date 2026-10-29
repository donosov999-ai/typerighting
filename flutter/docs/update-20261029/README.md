# Обновление Tauri 2.60.0 → Flutter с тем же ID без потери данных (Android, эмулятор)

29.10.2026 · typerighting-claude-mac · отдельный AVD `typefree_update` (android-36, arm64), эмулятор `typefree_phone` и его данные не трогались.

## Как собрано
- Старое приложение: настоящий бинарь `pro.typefree.app` 2.60.0 (versionCode 2060000), снятый с эмулятора `typefree_phone`. Его CI-ключ был одноразовым (`keytool -genkeypair` в android.yml), поэтому бинарь переподписан локальным тестовым ключом — код старого приложения тот же. Файлы и ключ: `~/dev/psygames-checkpoints/typefree-20261028/update-test/` (README там же). Это НЕ ключ магазина.
- Flutter: `flutter build apk --release --build-number 2060100 --android-project-arg=typefreeAppId=pro.typefree.app --android-project-arg=typefreeTestKeystore=… --android-project-arg=typefreeTestKeyPassword=…` (переопределения в `android/app/build.gradle.kts`, без них — изолированный кандидат как раньше).
- Миграция: `lib/features/migration_gate.dart` + `lib/data/webview_migration.dart` — при первом запуске на Android невидимый WebView открывает старый origin `http://tauri.localhost` (Tauri 2, `useHttpsScheme` не задан), читает localStorage и импортирует через те же allowlist/валидаторы/транзакцию, что и файловый импорт I5.

## Сценарий и результат
| шаг | что | кадр |
|---|---|---|
| 1 | старое 2.60.0: выбран профиль «Soft» | 01-old-2.60.0-soft-profile.png |
| 2 | старое: набрано упражнение «Words in sentences» (банк Шестова `abandon`), done 1 · 270 WPM · 98 %, 4 достижения | 02-old-2.60.0-exercise-done.png |
| 3 | `adb install -r` Flutter 2060100 поверх (firstInstallTime тот же — это обновление, не новая установка) | — |
| 4 | первый запуск: без приветствия, тема «Мягкий» | 03-after-update-today.png |
| 5 | «Прогресс»: «Тренировка из прежней версии 29.10.2026 13:11 · 270 WPM · 98 %», 1 сессия, лучшая 270, достижения 4/11 | 04-after-update-progress.png |
| 6 | найдено: язык стал RU на EN-устройстве (старое не хранило tr_lang) → исправлено: язык устройства (0174fda) | — |
| 7 | второе обновление Flutter 2060101 поверх: данные на месте, интерфейс EN, на «Сегодня» — «Previous-version history is in Progress» | 05-second-update-today-en.png |
| 8 | «Progress by collection»: abandon — Completed 1 · 270 WPM · 98 % (скрытый банк Шестова сохранён) | 06-second-update-progress-collections.png |

Скорость 270 WPM — от adb, не человека.

## Не доказано здесь
- iOS: старое хранилище WKWebView у origin `tauri://localhost` — отдельный путь (у Codex есть доказательство чтения WKWebsiteDataStore на macOS, docs/webkit-fixture-proof-20261025.json); same-ID на iOS-симуляторе не проводилось.
- Физические устройства, прерывание миграции посреди записи на устройстве (в тестах — да: webview_migration_test, storage_transfer_test), обновление через магазин (подпись Play App Signing: AAB надо подписать тем же upload-ключом, что 2.60.x — `~/.sdt_secrets/typefree-android/upload.jks`; не делалось).
- Windows/macOS-приложения Tauri → Flutter.
