#!/bin/bash
# typefree-ios-testflight-local · VER 1 · 01.10.2026 · typerighting-claude-mac
# Сборка iOS на маке и заливка в TestFlight (группа «Свои») — без секретов в GitHub и без шагов человека.
# Канон: ~/Downloads/Code claude/STORE_PUBLISH_RULES.md §1а, §3а. Ключи берутся из ~/.sdt_secrets по путям,
# значения не печатаются. Версия и номер сборки = version из src-tauri/tauri.conf.json (у каждой заливки — новая).
# Запуск из корня репозитория:  bash scripts/ios-testflight-local.sh            — собрать и залить
#                               bash scripts/ios-testflight-local.sh --no-upload — только собрать и проверить .ipa
set -euo pipefail
cd "$(dirname "$0")/.."
PY=/opt/homebrew/bin/python3          # pyjwt стоит только здесь (канон §1а)
OUT="${OUT:-$PWD/src-tauri/gen/apple/build/export}"
J() { "$PY" -c 'import json,os,sys; print(os.path.expanduser(str(json.load(open(os.path.expanduser(sys.argv[1])))[sys.argv[2]])), end="")' "$1" "$2"; }
JR() { "$PY" -c 'import json,os,sys; print(json.load(open(os.path.expanduser(sys.argv[1])))[sys.argv[2]], end="")' "$1" "$2"; }  # без expanduser — для паролей
ASC=~/.sdt_secrets/apple_appstore.json
SIGN=~/.sdt_secrets/apple_signing.json
TEAM=$(J $ASC team_id); KEY_ID=$(J $ASC key_id); ISSUER=$(J $ASC issuer_id); KEY_FILE=$(J $ASC key_file); P12=$(J $SIGN p12); P12_PASS=$(JR $SIGN p12_password)
VER=$(node -p "require('./src-tauri/tauri.conf.json').version")
echo "▶ TypeFree iOS $VER"

[ -d src-tauri/gen/apple ] || npx tauri ios init
"$PY" ~/dev/psygames-game-lab/smart-alarm-flutter/tools/sign_keychain.py
APPLE_API_KEY_ID="$KEY_ID" APPLE_API_ISSUER="$ISSUER" APPLE_CERTIFICATE_PASSWORD="$P12_PASS" "$PY" scripts/ios-provision-profile.py --p12 "$P12" --key-file "$KEY_FILE"
"$PY" scripts/ios-project-patch.py --team "$TEAM" --profile "TypeFree App Store"
# Обёртка swift — обход Xcode 27 (tauri#16130), см. scripts/xcode27-swift/swift
APPLE_DEVELOPMENT_TEAM="$TEAM" PATH="$PWD/scripts/xcode27-swift:$PATH" npx tauri ios build --archive-only

ARCHIVE=src-tauri/gen/apple/build/typerighting_iOS.xcarchive
APP=$(ls -d "$ARCHIVE"/Products/Applications/*.app | head -1)
GOT=$(plutil -extract CFBundleShortVersionString raw "$APP/Info.plist")
[ "$GOT" = "$VER" ] || { echo "✗ в архиве версия $GOT, ждали $VER"; exit 1; }
[ -e "$APP/libapp.a" ] && { echo "✗ libapp.a внутри .app — Apple отклонит (90171), см. ios-project-patch.py п. 2"; exit 1; }
# Значок в .app — тот же, что в src-tauri/icons/ios (а не стандартный Tauri): сверка по 1024 в каталоге Xcode
cmp -s src-tauri/icons/ios/AppIcon-512@2x.png src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png \
  || { echo "✗ в каталоге Xcode не наш значок — ios-project-patch.py шаг 5"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key><dict><key>pro.typefree.app</key><string>TypeFree App Store</string></dict>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" -exportOptionsPlist "$OUT/ExportOptions.plist" | tail -3
IPA=$(ls "$OUT"/*.ipa | head -1)
echo "✓ $IPA"
[ "${1:-}" = "--no-upload" ] && exit 0

xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER" --p8-file-path "$KEY_FILE"
APPLE_API_KEY_ID="$KEY_ID" APPLE_API_ISSUER="$ISSUER" APPLE_API_KEY_FILE="$KEY_FILE" BUNDLE_ID=pro.typefree.app \
  WHAT_TO_TEST="${WHAT_TO_TEST:-TypeFree $VER}" \
  "$PY" ~/dev/psygames-span-hub/flutter/tool/testflight_assign.py "$VER" "$VER" "Свои"
