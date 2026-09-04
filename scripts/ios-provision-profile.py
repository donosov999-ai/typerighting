#!/usr/bin/env python3
"""
Создаёт/обновляет ТОЛЬКО профиль App Store для TypeRIGHT через App Store Connect API.

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

Профиль ссылается на ВСЕ сертификаты распространения аккаунта: какой из них реально
попадёт в связку ключей (тот, чей приватный ключ пришёл в .p12), тем и подпишется.
Это избавляет от сверки серийников и остаётся верным, даже если в аккаунте временно
живёт больше одного сертификата.

Переменные окружения: APPLE_API_KEY_ID, APPLE_API_ISSUER; ключ .p8 —
в ~/private_keys/AuthKey_${APPLE_API_KEY_ID}.p8 (кладёт workflow из секрета).
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

try:
    import jwt  # pyjwt
except ImportError:
    sys.exit('нужен pyjwt: pip3 install --break-system-packages pyjwt cryptography')

BASE = 'https://api.appstoreconnect.apple.com/v1'


def токен() -> str:
    key_id = os.environ.get('APPLE_API_KEY_ID')
    issuer = os.environ.get('APPLE_API_ISSUER')
    if not key_id or not issuer:
        sys.exit('нужны APPLE_API_KEY_ID и APPLE_API_ISSUER')
    путь = os.path.expanduser(f'~/private_keys/AuthKey_{key_id}.p8')
    if not os.path.exists(путь):
        sys.exit(f'ключ не найден: {путь}')
    ключ = open(путь, encoding='utf-8').read()
    now = int(time.time())
    return jwt.encode(
        {'iss': issuer, 'iat': now, 'exp': now + 1200, 'aud': 'appstoreconnect-v1'},
        ключ, algorithm='ES256', headers={'kid': key_id, 'typ': 'JWT'},
    )


def запрос(tok: str, method: str, path: str, body=None) -> dict:
    """Вызов API. Пустое тело (204 на DELETE) → пустой словарь, а не JSONDecodeError."""
    r = urllib.request.Request(f'{BASE}{path}',
                               data=json.dumps(body).encode() if body else None, method=method)
    r.add_header('Authorization', f'Bearer {tok}')
    r.add_header('Content-Type', 'application/json')
    try:
        сырое = urllib.request.urlopen(r, timeout=90).read()
    except urllib.error.HTTPError as e:
        sys.exit(f'{method} {path} → {e.code}: {e.read().decode()[:400]}')
    if not сырое.strip():
        return {}
    return json.loads(сырое)


def главное() -> None:
    p = argparse.ArgumentParser()
    p.add_argument('--bundle', default='com.odv999.typerighting')
    p.add_argument('--profile-name', default='TypeRIGHT App Store')
    a = p.parse_args()

    tok = токен()

    # 1. Все сертификаты распространения аккаунта — НЕ создаём и НЕ отзываем, только читаем.
    сертификаты = запрос(tok, 'GET', '/certificates?limit=200')['data']
    dist = [c for c in сертификаты if c['attributes']['certificateType'] == 'DISTRIBUTION']
    if not dist:
        sys.exit('в аккаунте нет сертификата распространения — сначала заведи общий '
                 '.p12 и положи в секрет APPLE_CERTIFICATE (см. IOS_SETUP.md)')
    print(f'сертификатов распространения в аккаунте: {len(dist)} (ни один не тронут)')

    # 2. Старый профиль с нашим именем удаляем (после смены сертификата он мёртв).
    #    Чужие профили (в т.ч. psygames) не трогаем — фильтр строго по имени.
    for prof in запрос(tok, 'GET', '/profiles?limit=200')['data']:
        if prof['attributes']['name'] == a.profile_name:
            запрос(tok, 'DELETE', f"/profiles/{prof['id']}")
            print(f'старый профиль «{a.profile_name}» удалён')

    ид = next((b for b in запрос(tok, 'GET', '/bundleIds?limit=200')['data']
               if b['attributes']['identifier'] == a.bundle), None)
    if not ид:
        sys.exit(f'bundleId {a.bundle} не найден в аккаунте — заведи его в '
                 'developer.apple.com/account/resources/identifiers (см. IOS_SETUP.md)')

    профиль = запрос(tok, 'POST', '/profiles', {'data': {
        'type': 'profiles',
        'attributes': {'name': a.profile_name, 'profileType': 'IOS_APP_STORE'},
        'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': ид['id']}},
            'certificates': {'data': [{'type': 'certificates', 'id': c['id']} for c in dist]}}}})
    па = профиль['data']['attributes']

    каталог = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(каталог, exist_ok=True)
    файл = os.path.join(каталог, f"{па['uuid']}.mobileprovision")
    open(файл, 'wb').write(base64.b64decode(па['profileContent']))
    print(f"профиль: {па['name']} · {па['profileType']} · {па['profileState']}")
    print(f'установлен: {файл}')


if __name__ == '__main__':
    главное()
