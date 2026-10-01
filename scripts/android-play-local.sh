#!/bin/bash
# typefree-android-play-local · VER 1 · 01.10.2026 · typerighting-claude-mac
# Магазинный .aab на маке и заливка в Google Play (внутреннее тестирование) — без CI и секретов в GitHub.
# Повторяет .github/workflows/play.yml (ветка без секретов): android init → правка MainActivity → значок →
# `tauri android build --aab` без VITE_TEST_BUILD (багфикса в магазинной сборке нет). Подпись ключом загрузки
# и заливка — ~/Downloads/Code claude/typerighting/play_upload_aab.py (ключи ~/.sdt_secrets, значения не печатаются).
# Зачем, если есть CI: 01.10.2026 сборка play.yml простояла в очереди 30+ минут — раннеры аккаунта заняты чужими
# прогонами (psygames-native: 36 в очереди). Нужное для сборки на маке уже стоит: SDK, NDK 27, цели Rust, Java.
# Запуск из корня репозитория:  bash scripts/android-play-local.sh             — собрать и залить
#                               bash scripts/android-play-local.sh --no-upload — только собрать и проверить .aab
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export NDK_HOME="${NDK_HOME:-$ANDROID_HOME/ndk/27.0.12077973}"  # NDK 27 выравнивает 16 КБ — требование Google Play
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-8}"               # мак общий с другими чатами — не забирать все ядра
unset VITE_TEST_BUILD
VER=$(node -p "require('./src-tauri/tauri.conf.json').version")
echo "▶ TypeFree Android $VER"

[ -d src-tauri/gen/android ] || npx tauri android init
python3 scripts/android-insets-patch.py
# Значок: android init кладёт стандартный значок Tauri — свой набор поверх (как шаг «App icon» в play.yml)
RES=src-tauri/gen/android/app/src/main/res
cp -R src-tauri/icons/android/. "$RES/"
npx tauri android build --aab

AAB=src-tauri/gen/android/app/build/outputs/bundle/universalRelease/app-universal-release.aab
[ -f "$AAB" ] || { echo "✗ нет $AAB"; find src-tauri/gen/android -name '*.aab'; exit 1; }
[ "$AAB" -nt src-tauri/tauri.conf.json ] || { echo "✗ $AAB старше конфига — это прошлая сборка"; exit 1; }
# В .aab должен лежать наш значок, а не стандартный Tauri
TMP=$(mktemp -d)
unzip -q -o "$AAB" 'base/res/mipmap-xxxhdpi*/ic_launcher_foreground.png' -d "$TMP"
# aapt2 пережимает PNG без потерь — сравниваем пиксели, а не байты
python3 -c 'import sys; from PIL import Image; a, b = (Image.open(f).convert("RGBA") for f in sys.argv[1:]); sys.exit(a.tobytes() != b.tobytes())' \
  "$TMP"/base/res/mipmap-xxxhdpi*/ic_launcher_foreground.png src-tauri/icons/android/mipmap-xxxhdpi/ic_launcher_foreground.png \
  || { echo "✗ в .aab не наш значок"; exit 1; }
OUT="$PWD/src-tauri/gen/android/TypeFree-play-$VER-unsigned.aab"  # gen/ в .gitignore
cp "$AAB" "$OUT"
echo "✓ $OUT ($(du -m "$OUT" | cut -f1) МБ), значок свой"
[ "${1:-}" = "--no-upload" ] && exit 0

/opt/homebrew/bin/python3 ~/Downloads/Code\ claude/typerighting/play_upload_aab.py "$OUT" --track internal --name "$VER"
