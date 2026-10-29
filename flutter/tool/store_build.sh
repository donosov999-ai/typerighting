#!/bin/zsh
# Store build of the Flutter app with the store ID pro.typefree.app (same-ID
# update over the Tauri 2.60.x app). Internal tracks only: Play «internal»,
# TestFlight group «Свои». The isolated candidate (default build) is untouched.
#
#   tool/store_build.sh android 2.60.100 2060100
#   tool/store_build.sh ios     2.60.100 2060100
#
# Android: debug signature stripped → play_upload_aab.py signs with the upload key.
# iOS: archive without signing, signed on export with «TypeFree App Store»;
# the store bundle ID and name are patched in for this build only and the
# two files are restored on exit.
set -euo pipefail
cd "${0:A:h}/.."
platform=$1 name=$2 number=$3
defines=(--dart-define=TYPEFREE_VERSION=$name --dart-define=TYPEFREE_SAME_ID=true)
tools="$HOME/Downloads/Code claude/typerighting"

if [[ $platform == android ]]; then
  export GRADLE_USER_HOME="$HOME/.gradle-typefree-$number"
  nice flutter build appbundle --release --build-name=$name --build-number=$number \
    $defines --android-project-arg=typefreeAppId=pro.typefree.app
  aab=build/app/outputs/bundle/release/app-release.aab
  # Flutter signs release with the debug key even without a config; Play
  # refuses two signatures, so drop it before the upload key is applied.
  zip -q -d $aab 'META-INF/MANIFEST.MF' 'META-INF/*.SF' 'META-INF/*.RSA'
  rm -f build/app/outputs/bundle/release/app-release-signed.aab
  # Wrong ID = the candidate went out; Play would refuse it anyway.
  unzip -p $aab base/manifest/AndroidManifest.xml | strings | grep -q 'pro\.typefree\.app' \
    || { echo 'bundle is not pro.typefree.app'; exit 1; }
  python3 "$tools/play_upload_aab.py" $aab --track internal --name "$name (Flutter)"
elif [[ $platform == ios ]]; then
  pbx=ios/Runner.xcodeproj/project.pbxproj plist=ios/Runner/Info.plist
  git diff --quiet -- $pbx $plist || { echo "uncommitted $pbx/$plist"; exit 1; }
  trap 'git checkout -- $pbx $plist' EXIT
  sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = pro.typefree.candidate.typefreeFlutterFoundation;/PRODUCT_BUNDLE_IDENTIFIER = pro.typefree.app;/' $pbx
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName TypeFree' $plist
  nice flutter build ipa --release --build-name=$name --build-number=$number $defines --no-codesign
  xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa -allowProvisioningUpdates
  ipa=(build/ios/ipa/*.ipa)
  key=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.sdt_secrets/apple_appstore.json')))['key_id'])")
  issuer=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.sdt_secrets/apple_appstore.json')))['issuer_id'])")
  xcrun altool --validate-app -f $ipa -t ios --apiKey $key --apiIssuer $issuer
  xcrun altool --upload-app -f $ipa -t ios --apiKey $key --apiIssuer $issuer
else
  echo "usage: $0 android|ios <name> <number>"; exit 2
fi
