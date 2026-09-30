#!/usr/bin/env python3
"""
Создаёт/обновляет ТОЛЬКО профиль App Store для TypeRIGHT через App Store Connect API.
VER 2 · 30.09.2026

🔴 ПОЧЕМУ ЭТОТ СКРИПТ НЕ ТРОГАЕТ СЕРТИФИКАТЫ — И ЭТО ГЛАВНОЕ ОТЛИЧИЕ ОТ PSYGAMES.

psygames/scripts/ios-provision.py на каждом релизе СОЗДАЁТ новый сертификат
распространения и ОТЗЫВАЕТ старые (KEEP=1). Сертификаты распространения — общие на
весь аккаунт (team-wide), не на приложение. Пока приложение в аккаунте одно, это
работает. Но TypeRIGHT делит тот же аккаунт Apple с psygames, и team-wide отзыв
означал бы, что CI одного приложения отзывает сертификат, которым в этот момент
подписывается другое (ровно инцидент psygames 04.09.2026 — код 90721
«Certificate Revoked», — но уже между приложениями и на каждом релизе).

Поэтому здесь другая модель — она же родная для Apple:
  · ОДИН общий сертификат распространения на аккаунт (его импортирует
    `ios-signing-setup.sh` из секрета `APPLE_CERTIFICATE`, .p12);
  · у КАЖДОГО приложения СВОЙ профиль (профили привязаны к bundle id, они
    именно per-app) — этот скрипт заводит профиль только для TypeRIGHT.
Скрипт НИКОГДА не создаёт и не отзывает сертификаты: удаляет и пересоздаёт лишь
профиль со своим именем. Клобер соседнего приложения невозможен by construction.

🔴 В ПРОФИЛЬ — ТОЛЬКО СЕРТИФИКАТ ИЗ НАШЕГО .p12 (VER 2 · 30.09.2026).
Раньше профиль ссылался на ВСЕ сертификаты распространения аккаунта. 30.09.2026 профиль
«TypeFree App Store» стал INVALID: в нём стоял сертификат CI PsyGames 39V6T5G65M, а их CI
меняет свой сертификат на каждом выпуске и отзывает прошлый. Любой чужой сертификат в профиле —
бомба с чужим таймером. Поэтому сертификат выбирается по отпечатку SHA-1 того сертификата,
что лежит в .p12 (им реально подписываемся), сверкой с certificateContent в App Store Connect.
Нет совпадения → остановка, а не «берём все» (канон STORE_PUBLISH_RULES §1а: общий YWD42L62ZH).

Переменные окружения: APPLE_API_KEY_ID, APPLE_API_ISSUER; ключ .p8 —
в ~/private_keys/AuthKey_${APPLE_API_KEY_ID}.p8 (кладёт workflow из секрета) или путь в --key-file;
путь к .p12 — --p12, пароль к нему — APPLE_CERTIFICATE_PASSWORD.
--dry-run: только читает (какой сертификат совпал, какие профили с нашим именем есть) и ничего не меняет.
"""
import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

try:
    import jwt  # pyjwt
    from cryptography.hazmat.primitives.serialization import Encoding, pkcs12
except ImportError:
    sys.exit('нужен pyjwt: pip3 install --break-system-packages pyjwt cryptography')

BASE = 'https://api.appstoreconnect.apple.com/v1'
KEY_FILE = ''  # --key-file; пусто → ~/private_keys/AuthKey_<id>.p8


def token() -> str:
    key_id = os.environ.get('APPLE_API_KEY_ID')
    issuer = os.environ.get('APPLE_API_ISSUER')
    if not key_id or not issuer:
        sys.exit('нужны APPLE_API_KEY_ID и APPLE_API_ISSUER')
    path = os.path.expanduser(KEY_FILE or f'~/private_keys/AuthKey_{key_id}.p8')
    if not os.path.exists(path):
        sys.exit(f'ключ не найден: {path}')
    key = open(path, encoding='utf-8').read()
    now = int(time.time())
    return jwt.encode(
        {'iss': issuer, 'iat': now, 'exp': now + 1200, 'aud': 'appstoreconnect-v1'},
        key, algorithm='ES256', headers={'kid': key_id, 'typ': 'JWT'},
    )


def request_api(tok: str, method: str, path: str, body=None) -> dict:
    """Вызов API. Пустое тело (204 на DELETE) → пустой словарь, а не JSONDecodeError."""
    r = urllib.request.Request(f'{BASE}{path}',
                               data=json.dumps(body).encode() if body else None, method=method)
    r.add_header('Authorization', f'Bearer {tok}')
    r.add_header('Content-Type', 'application/json')
    try:
        raw = urllib.request.urlopen(r, timeout=90).read()
    except urllib.error.HTTPError as e:
        sys.exit(f'{method} {path} → {e.code}: {e.read().decode()[:400]}')
    if not raw.strip():
        return {}
    return json.loads(raw)


def p12_sha1(path: str) -> str:
    """SHA-1 сертификата внутри .p12 (заглавные hex) — по нему ищем сертификат в аккаунте."""
    password = os.environ.get('APPLE_CERTIFICATE_PASSWORD', '')
    _key, cert, _extra = pkcs12.load_key_and_certificates(
        open(os.path.expanduser(path), 'rb').read(), password.encode() if password else None)
    if cert is None:
        sys.exit(f'в {path} нет сертификата')
    return hashlib.sha1(cert.public_bytes(Encoding.DER)).hexdigest().upper()


def main() -> None:
    global KEY_FILE
    p = argparse.ArgumentParser()
    p.add_argument('--bundle', default='pro.typefree.app')
    p.add_argument('--profile-name', default='TypeFree App Store')
    p.add_argument('--p12', required=True, help='.p12, которым подписываемся (ios-signing-setup.sh передаёт свой)')
    p.add_argument('--key-file', default='', help='путь к .p8 (для запуска на маке)')
    p.add_argument('--dry-run', action='store_true', help='только прочитать и показать, ничего не менять')
    a = p.parse_args()
    KEY_FILE = a.key_file

    tok = token()

    # 1. Сертификаты распространения аккаунта — НЕ создаём и НЕ отзываем, только читаем
    #    и берём ОДИН: тот, что лежит в нашем .p12.
    certs = request_api(tok, 'GET', '/certificates?limit=200')['data']
    dist = [c for c in certs if c['attributes']['certificateType'] == 'DISTRIBUTION']
    want = p12_sha1(a.p12)
    ours = [c for c in dist
            if hashlib.sha1(base64.b64decode(c['attributes']['certificateContent'])).hexdigest().upper() == want]
    print(f'сертификатов распространения в аккаунте: {len(dist)} '
          f"({', '.join(c['id'] for c in dist)}); ни один не тронут")
    if len(ours) != 1:
        sys.exit(f'🔴 сертификата из .p12 (SHA-1 {want[:8]}…) в аккаунте {len(ours)} — '
                 'отозван или .p12 не тот. Профиль не трогаю (STORE_PUBLISH_RULES §1а)')
    cert = ours[0]
    print(f"в профиль пойдёт только {cert['id']} — до {cert['attributes']['expirationDate'][:10]}")

    # 2. Старый профиль с нашим именем удаляем (после смены сертификата он мёртв).
    #    Чужие профили (в т.ч. psygames) не трогаем — фильтр строго по имени.
    mine = [prof for prof in request_api(tok, 'GET', '/profiles?limit=200')['data']
            if prof['attributes']['name'] == a.profile_name]
    for prof in mine:
        ids = [c['id'] for c in request_api(tok, 'GET', f"/profiles/{prof['id']}/certificates")['data']]
        print(f"есть профиль «{a.profile_name}»: {prof['attributes']['profileState']}, сертификаты {ids}")
    if a.dry_run:
        print('--dry-run: ничего не менял')
        return
    for prof in mine:
        request_api(tok, 'DELETE', f"/profiles/{prof['id']}")
        print(f'старый профиль «{a.profile_name}» удалён')

    bid = next((b for b in request_api(tok, 'GET', '/bundleIds?limit=200')['data']
               if b['attributes']['identifier'] == a.bundle), None)
    if not bid:
        sys.exit(f'bundleId {a.bundle} не найден в аккаунте — заведи его в '
                 'developer.apple.com/account/resources/identifiers (см. IOS_SETUP.md)')

    profile = request_api(tok, 'POST', '/profiles', {'data': {
        'type': 'profiles',
        'attributes': {'name': a.profile_name, 'profileType': 'IOS_APP_STORE'},
        'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': bid['id']}},
            'certificates': {'data': [{'type': 'certificates', 'id': cert['id']}]}}}})
    attrs = profile['data']['attributes']

    folder = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(folder, exist_ok=True)
    fpath = os.path.join(folder, f"{attrs['uuid']}.mobileprovision")
    open(fpath, 'wb').write(base64.b64decode(attrs['profileContent']))
    print(f"профиль: {attrs['name']} · {attrs['profileType']} · {attrs['profileState']} · сертификат {cert['id']}")
    print(f'установлен: {fpath}')


if __name__ == '__main__':
    main()
