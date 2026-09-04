#!/usr/bin/env bash
# 🔴 ПОДГОТОВКА ПОДПИСИ iOS ДЛЯ TypeRIGHT — ИМПОРТ ОБЩЕГО СЕРТИФИКАТА, БЕЗ ОТЗЫВА.
#
# Отличие от psygames/scripts/ios-signing-setup.sh: тот СОЗДАЁТ сертификат через API
# и отзывает старые (KEEP=1). Team-wide отзыв на общем аккаунте отозвал бы сертификат
# psygames. Поэтому TypeRIGHT ИМПОРТИРУЕТ общий сертификат распространения из секрета
# (.p12) и создаёт только свой профиль — сертификаты не трогаются вовсе.
#
# ⚠️ ДВЕ ГРАБЛИ, унаследованные из живого прогона psygames 02.09.2026:
#  1. Сертификат без промежуточного Apple WWDR не виден как identity:
#     `security find-identity` показывает «0 valid identities found». WWDR обязателен.
#  2. Имена переменных — только латиницей: в CI (bash) кириллическое имя ломает
#     выполнение строки.
#
# Переменные: APPLE_CERTIFICATE (base64 .p12), APPLE_CERTIFICATE_PASSWORD,
#             APPLE_API_KEY_ID, APPLE_API_ISSUER, KEYCHAIN_PASSWORD.
# Ключ .p8 (для профиля) — в ~/private_keys/AuthKey_${APPLE_API_KEY_ID}.p8.
set -euo pipefail

: "${APPLE_CERTIFICATE:?нужен APPLE_CERTIFICATE (base64 .p12)}"
: "${APPLE_CERTIFICATE_PASSWORD:?нужен APPLE_CERTIFICATE_PASSWORD}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-typerighting-ci}"
WORKDIR="${RUNNER_TEMP:-/tmp}"

python3 -m pip install --quiet --break-system-packages pyjwt cryptography 2>/dev/null || true

# 1. Общий сертификат распространения из секрета (.p12 с приватным ключом)
echo "$APPLE_CERTIFICATE" | base64 --decode > "$WORKDIR/dist.p12"

# 2. Связка ключей: сертификат + промежуточный Apple WWDR
security create-keychain -p "$KEYCHAIN_PASSWORD" ios-build.keychain
security unlock-keychain -p "$KEYCHAIN_PASSWORD" ios-build.keychain
security set-keychain-settings -lut 3600 ios-build.keychain
security list-keychains -d user -s ios-build.keychain "$HOME/Library/Keychains/login.keychain-db"
security import "$WORKDIR/dist.p12" -k ios-build.keychain -P "$APPLE_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security

curl -sSL -o "$WORKDIR/wwdr.cer" https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
security import "$WORKDIR/wwdr.cer" -k ios-build.keychain -T /usr/bin/codesign

security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$KEYCHAIN_PASSWORD" ios-build.keychain >/dev/null

echo "— identities в связке:"
security find-identity -v -p codesigning | sed 's/^/  /'

# 3. Профиль App Store только для TypeRIGHT (сертификаты не трогаются)
python3 "$(dirname "$0")/ios-provision-profile.py"

rm -f "$WORKDIR/dist.p12"
