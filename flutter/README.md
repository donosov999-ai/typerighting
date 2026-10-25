# TypeFree Flutter · isolated local candidate · 25 October 2026

This is a working ordinary-practice and structured-course slice, not a replacement for TypeFree 2.60.4.
Baseline: 2fa2b77f032e77b759b29b44d223c7f91578597b. Old src and installed user data remain untouched.

## Run locally

Use Flutter 3.47.5 / Dart 3.13.4. The private shared Synapse runtime must be available locally:

```sh
python3 tool/prepare_synapse_runtime.py
flutter pub get --offline
flutter test
flutter analyze
flutter run -d macos
```

The helper freezes the owner candidate outside this public checkout and verifies its recorded hashes on reuse. The ignored pubspec_overrides.yaml points to that local snapshot. No private Synapse artwork/source is committed here. This dependency setup is for this machine only; CI/release requires the owner's accepted, accessible package revision. Do not silently substitute a different pet or vendor the private package into the public repository.

Web: `flutter build web --no-web-resources-cdn`, serve build/web on loopback. Web assets include the shared private runtime; do not publish this build without the release review/authorization.
macOS candidate ID: pro.typefree.candidate.typefreeFlutterFoundation, distinct from the installed app. Generated icons/entitlements/platform packaging are not store-ready.

## Working scope

Ordinary practice uses canonical source content for seven languages (159 exercise variants), physical keyboard geometry/maps, digits, no-punctuation mode, flow, custom text and blocking/bridge options. Three Shestov banks are excluded from both catalogue and selection. The Dart engine matches 47 exported TS event traces (2,827 events). This is not the entire original course library.

Two templates each support light/dark/system appearance. The actual practice widget retains its session/timing/text when appearance changes. At 1280x720 the full five-row keyboard, controls and completion actions fit; narrow screens scroll without shrinking the whole UI. Long text scrolls inside its own viewport.

Header: canonical shared head image opens the actual shared animated Synapse panel; header portrait is static. Shared advisor receives a fact only after a real eligible result is saved. No LLM service, invented care score or network backend is configured. Reduced motion disables the panel ticker. Shared package remains a local owner candidate, not an accepted production dependency.

Candidate history/preferences use separate local storage (typefree.flutter.candidate.v1); appearance uses a separate preference key. Native writes use pending/backup/rename, web uses a single document write. Transaction tests cover failures, retry and duplicate result IDs. No original account credentials or original app containers are accessed.

## Migration boundary and remaining work

Local-transfer envelope implements explicit allowlist/checksum/atomic receipt/conflict checks. It is tested on fixtures only. A native, separately named macOS WKWebsiteDataStore was seeded with synthetic data in one process and read in a second process, then transferred into the real Dart file store and reloaded. Run `python3 tool/run_webkit_fixture.py`; evidence docs/webkit-fixture-proof-20261025.json. This is not a packaged Tauri-to-Flutter update proof. NO real Tauri WebView-to-Flutter extraction, installed-app update, native crash recovery or migration of real users has been validated. The progress page now displays a frozen imported archive separately from new sessions, with archived records/stars/achievements. It does not invent profile/language/exercise identity absent in the old history. Raw archives remain unchanged when new history is capped. Missing supported preferences are adapted without overwriting an existing choice. Never replace the installed app from this candidate.

Structured course: 19 canonical lessons for each of seven languages, source-matching generated content (133 golden cases), per-line blocking input, stars/unlock and transactional save/retry. Source course reports last-line WPM/accuracy; stars use total errors. New per-key EMA/heatmap measurements are not yet wired, so full course parity is still pending.

Not ported yet: AI/competition/memory/recall/exam/kids flows, full statistics/achievements, help/audio/export settings and all route localization. Account/coach candidates remain separate; no fake auth, pupils or reports. Author playlist editor remains private and is not shipped. See F1_COURSE_HANDOFF_20261025.md and STAGE_HANDOFF_20261025.md and the design migration plan.

Design reference: /Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024/DESIGN_TEMPLATE_REF.md
Migration plan: /Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024/FLUTTER_MIGRATION_PLAN.md
