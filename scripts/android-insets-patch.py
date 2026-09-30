#!/usr/bin/env python3
"""
typefree-android-insets · VER 1 · 30.09.2026

Правит сгенерированный MainActivity.kt так, чтобы страница не уходила под системную строку
и панель навигации Android на старом WebView. Запускается в CI после `npx tauri android init`
(.github/workflows/android.yml); gen/android не коммитится, поэтому правка — скриптом.

🔴 ЗАЧЕМ.
Шаблон MainActivity Tauri 2.11.2 вызывает enableEdgeToEdge(): приложение рисуется под часами
и значками сверху и под панелью навигации снизу. wry 0.55.1 системные отступы сам не обрабатывает
(в его Kotlin-коде нет ни Insets, ни safe-area — замер 30.09.2026).
• WebView с M136 передаёт отступы в CSS env(safe-area-inset-*) — это учитывает src/style.css
  (блок typerighting-safe-area). Здесь ничего не делаем, иначе полоса под системной строкой
  окрасится фоном окна, а не цветом панели приложения.
• WebView старше M136 отступы в CSS НЕ передаёт (в образах эмулятора Android 36 стоит 133).
  Для него отступ ставит сам Android: padding корневого вида. Отступы, переданные дальше в WebView,
  обнуляются — так советует документация Chromium (android_webview/docs/insets.md),
  двойного отступа не будет.

Если шаблон Tauri изменится и якорей не окажется — скрипт падает с кодом 1: собрать APK без правки
хуже, чем остановить сборку.
"""
import pathlib
import sys

GEN = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'src-tauri/gen/android')
MARK = 'typefree-insets'
IMPORT_ANCHOR = 'import androidx.activity.enableEdgeToEdge\n'
CALL_ANCHOR = '    super.onCreate(savedInstanceState)\n'

IMPORTS = (
    'import android.view.View\n'
    'import androidx.core.graphics.Insets\n'
    'import androidx.core.view.ViewCompat\n'
    'import androidx.core.view.WindowInsetsCompat\n'
    'import androidx.webkit.WebViewCompat\n'
)

BODY = """    // typefree-insets: WebView < M136 не передаёт системные отступы в CSS env() — отступаем нативно
    val webviewMajor = WebViewCompat.getCurrentWebViewPackage(this)?.versionName
      ?.substringBefore('.')?.toIntOrNull() ?: 0
    if (webviewMajor < 136) {
      ViewCompat.setOnApplyWindowInsetsListener(findViewById<View>(android.R.id.content)) { v, insets ->
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
        v.setPadding(bars.left, bars.top, bars.right, bars.bottom)
        WindowInsetsCompat.Builder(insets)
          .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.NONE)
          .setInsets(WindowInsetsCompat.Type.displayCutout(), Insets.NONE)
          .build()
      }
    }
"""


def main() -> int:
    found = sorted(GEN.rglob('MainActivity.kt'))
    if len(found) != 1:
        print('🔴 MainActivity.kt: найдено %d файлов в %s' % (len(found), GEN))
        return 1
    path = found[0]
    src = path.read_text(encoding='utf-8')
    if MARK in src:
        print('· %s уже поправлен — пропуск' % path)
        return 0
    if src.count(IMPORT_ANCHOR) != 1 or src.count(CALL_ANCHOR) != 1:
        print('🔴 шаблон MainActivity изменился — правка отступов не применена. Файл:\n' + src)
        return 1
    src = src.replace(IMPORT_ANCHOR, IMPORT_ANCHOR + IMPORTS, 1)
    src = src.replace(CALL_ANCHOR, CALL_ANCHOR + BODY, 1)
    path.write_text(src, encoding='utf-8')
    print('✓ %s: отступы системных панелей для WebView < 136' % path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
