#!/usr/bin/env python3
"""
Правит сгенерированный iOS-проект TypeRIGHT под требования App Store.

Адаптировано из psygames/scripts/ios-project-patch.py (VER 03.09.2026) — источник
рецепта и всех разобранных ниже граблей. Отличия TypeRIGHT: имя проекта
`typerighting.xcodeproj`, таргет `typerighting_iOS`, профиль по умолчанию
«TypeFree App Store», один идентификатор `pro.typefree.app` (без
tauri.ios.conf.json-переопределения). Логика правок не менялась.

🔴 ЗАЧЕМ ПАТЧ, А НЕ ПРАВКА ФАЙЛА РУКАМИ.

`src-tauri/gen/` лежит в .gitignore: проект генерируется `cargo tauri ios init` из
шаблона при каждой сборке — и на чистой машине CI тоже. Любая правка `project.yml`
руками живёт до следующей генерации, то есть до первого же запуска в CI. Поэтому
правки собраны здесь и применяются ПОСЛЕ генерации, каждый раз.

Что чиним и почему — всё проверено живьём 02–03.09.2026 (psygames) на пути до
валидации Apple; те же самые правила Apple действуют и для TypeRIGHT:

1. ПОДПИСЬ РУЧНАЯ. Автоматическая на машине без аккаунта Xcode отвечает «No Accounts:
   Add a new account in Accounts settings» и ищет DEVELOPMENT-профиль, которому нужны
   зарегистрированные устройства. Сертификат распространения импортирует
   `ios-signing-setup.sh`, профиль App Store создаёт `ios-provision-profile.py`,
   здесь проекту сказано ими пользоваться.

2. libapp.a ЛИНКУЕТСЯ ФЛАГОМ, А НЕ ЗАВИСИМОСТЬЮ. Валидация отклоняет сборку: «Invalid
   bundle structure. The "…app/libapp.a" binary file is not permitted» (90171).
   Работает одно: убрать библиотеку из `dependencies` совсем и линковать флагом
   `-lapp` (пути к Externals уже стоят в LIBRARY_SEARCH_PATHS). Тогда она линкуется
   и никуда не копируется.
   И ещё: папке Externals — `buildPhase: none`. xcodegen раскладывает её файлы по фазам
   в момент генерации; если libapp.a от прошлой сборки уже лежит там (повторная сборка
   без init), он попадает в Resources и копируется в .app — та же 90171 (01.10.2026, 2.60.1).

3. МИНИМУМ iOS 15. Загрузка с 14.0 проходит, но приходит предупреждение 90068: с весны
   2027 Apple перестанет принимать ниже пятнадцатой. Лучше сейчас, чем через год срочно.

4. ЭКСПОРТНОЕ ШИФРОВАНИЕ — ответ в Info.plist. Без ключа сборка доходит до Apple и
   встаёт с MISSING_EXPORT_COMPLIANCE. Приложение ходит по HTTPS и своей криптографии
   не содержит — ответ «нет» фактический, а не удобный.

5. ЗНАЧОК ИЗ src-tauri/icons/ios. `tauri ios init` кладёт в каталог Xcode стандартный
   значок Tauri, а наш набор не берёт: так ушла в TestFlight сборка 2.60.0 (замер
   01.10.2026 по AppIcon60x60@2x.png собранного .app). Имена файлов совпадают —
   копируем поверх; значок 1024 с альфа-каналом App Store не принимает — проверяем.

Запуск (после `cargo tauri ios init`, до сборки):
    python3 scripts/ios-project-patch.py --team XXXXXXXXXX --profile "TypeFree App Store"
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path('src-tauri/gen/apple')
# Имя проекта и таргета Tauri выводит из productName (было typerighting, стало typefree).
# Не зашиваем: ищем по маске, иначе переименование продукта тихо ломает подпись.
_PROJ = sorted(PROJECT.glob('*.xcodeproj')) if PROJECT.exists() else []
XCODEPROJ = _PROJ[0].name if _PROJ else 'typefree.xcodeproj'
IOS_TARGET = XCODEPROJ.replace('.xcodeproj', '') + '_iOS'


def patch(team: str, profile: str, min_ios: str) -> None:
    yml = PROJECT / 'project.yml'
    if not yml.exists():
        sys.exit(f'нет {yml} — сначала `cargo tauri ios init`')
    s = yml.read_text(encoding='utf-8')

    # 1. Минимальная версия iOS
    s = s.replace('    iOS: 14.0', f'    iOS: {min_ios}')

    # 2. Ручная подпись — в настройки таргета
    маркер = '      base:\n        ENABLE_BITCODE: false'
    if 'CODE_SIGN_STYLE' not in s:
        if маркер not in s:
            sys.exit('шаблон проекта изменился: не нашёл блок настроек таргета')
        s = s.replace(маркер, (
            '      base:\n'
            '        CODE_SIGN_STYLE: Manual\n'
            f'        DEVELOPMENT_TEAM: {team}\n'
            '        CODE_SIGN_IDENTITY: "Apple Distribution"\n'
            f'        PROVISIONING_PROFILE_SPECIFIER: "{profile}"\n'
            f"        IPHONEOS_DEPLOYMENT_TARGET: '{min_ios}'\n"
            '        ENABLE_BITCODE: false'), 1)

    # 3. libapp.a — вон из зависимостей, линковка флагом
    зависимость = '      - framework: libapp.a\n        embed: false\n'
    if зависимость in s:
        s = s.replace(зависимость, '', 1)
    внешние = '      - path: Externals\n'
    if внешние in s and 'path: Externals\n        buildPhase: none' not in s:
        s = s.replace(внешние, внешние + '        buildPhase: none\n', 1)
    if 'OTHER_LDFLAGS' not in s:
        s = s.replace('        ENABLE_BITCODE: false',
                      '        OTHER_LDFLAGS: $(inherited) -lapp\n        ENABLE_BITCODE: false', 1)

    # 4. Экспортное шифрование — ответ в Info.plist, а не руками в кабинете.
    if 'ITSAppUsesNonExemptEncryption' not in s:
        якорь = '        LSRequiresIPhoneOS: true'
        if якорь not in s:
            sys.exit('шаблон проекта изменился: не нашёл блок Info.plist')
        s = s.replace(якорь, '        ITSAppUsesNonExemptEncryption: false\n' + якорь, 1)

    yml.write_text(s, encoding='utf-8')
    print('project.yml пропатчен: ручная подпись, iOS', min_ios, ', очистка бандла')

    subprocess.run(['xcodegen', 'generate'], cwd=PROJECT, check=True,
                   stdout=subprocess.DEVNULL)
    pbx = (PROJECT / XCODEPROJ / 'project.pbxproj').read_text(encoding='utf-8')
    if 'libapp.a in Resources' in pbx:
        sys.exit('libapp.a попал в Resources — уедет внутрь .app, Apple отклонит (90171)')
    for что, где in (('CODE_SIGN_STYLE = Manual', 'ручная подпись'),
                     (profile, 'профиль'),
                     ('-lapp', 'линковка библиотеки флагом')):
        if что not in pbx:
            sys.exit(f'после генерации в проекте нет: {где} ({что})')

    # ⚠️ Ответ про шифрование ищем в Info.plist, а не в project.pbxproj: xcodegen
    #    раскладывает свойства блока `info` в ОТДЕЛЬНЫЙ Info.plist, не в проект.
    плист = PROJECT / IOS_TARGET / 'Info.plist'
    if not плист.exists():
        sys.exit(f'после генерации нет {плист} — некуда класть ответ про шифрование')
    if 'ITSAppUsesNonExemptEncryption' not in плист.read_text(encoding='utf-8'):
        sys.exit('в Info.plist нет ответа про экспортное шифрование — сборка встанет у Apple')

    # 5. Значок — свой набор поверх стандартного значка Tauri
    знаки = Path('src-tauri/icons/ios')
    каталог = PROJECT / 'Assets.xcassets' / 'AppIcon.appiconset'
    нужны = {i['filename'] for i in json.loads((каталог / 'Contents.json').read_text(encoding='utf-8'))['images']
             if i.get('filename')}
    нет = sorted(n for n in нужны if not (знаки / n).exists())
    if нет:
        sys.exit(f'в {знаки} нет файлов, которых ждёт каталог Xcode: {нет} — `npx tauri icon`')
    for n in sorted(нужны):
        shutil.copyfile(знаки / n, каталог / n)
    альфа = subprocess.run(['sips', '-g', 'hasAlpha', str(каталог / 'AppIcon-512@2x.png')],
                           capture_output=True, text=True).stdout
    if 'hasAlpha: yes' in альфа:
        sys.exit('значок 1024 (AppIcon-512@2x.png) с альфа-каналом — App Store его не примет')
    print(f'значок: {len(нужны)} файлов из {знаки} в каталог Xcode')
    print('проект пересобран, все правки на месте ✅')


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--team', required=True)
    p.add_argument('--profile', default='TypeFree App Store')
    p.add_argument('--min-ios', default='15.0')
    a = p.parse_args()
    patch(a.team, a.profile, a.min_ios)
