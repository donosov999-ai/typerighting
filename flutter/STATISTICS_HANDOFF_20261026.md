# TypeFree · statistics transfer · 26 October 2026 · LOCAL

Checkout: /Users/denisonosov/dev/typerighting-wt-flutter-20261025
Branch: codex/typefree-flutter-20261025. Parent tasks: 568d223e-d42c-4e30-83a0-fbad3a95e721 and 2046fb02-53b1-47db-918f-e0a2a417e6a3, both remain in_progress.

## Implemented

Ordinary practice and structured course now feed one physical-key recorder, as in the shipped TypeScript. Expected keys are resolved by the source keyboard snapshot; spaces, newline and unmapped characters do not enter recordKey evidence. Wrong attempts still count against the expected physical key. Backspace only changes the typing engine, as before.

Ported ok/err counters, correct-only timing EMA (alpha .1, inclusive 40–12000 ms), best time, sample counts, timestamps, 21-day half-life after >half-day absence, session boundary after >5 minutes, error-key map. History length/err/ms/score and minimum-ten-key filter now use the source recorder instead of all input attempts. The source epoch-zero/start-time and >one-hour duration rules are retained. Old counters are global across profiles/languages; do not present them as identified person-specific evidence. No imported legacy history is assigned a fabricated profile.

Key statistics debounce at 800 ms, including unfinished exercises; completion writes pending keys together with progress/history in one existing LocalRepository transaction. Repository/store serialization prevents overlapping flushes counting a batch twice. Failed batches remain queued while this runtime is alive. Completion retains its captured counters for retry. Frozen legacyArchive is not mutated; mutable legacy.tr_keystats is updated. Existing sessions without errKeys remain readable; new errKeys are validated on reload.

This stage changes data recording, not layout. Existing Today visual comparison remains a draft; this work does not assert new visual approval. No Synapse private package, dependency version, original TypeScript source, editor, backend, user container or production was changed.

## Verification

Reproduce in flutter/:

```sh
node tool/export_key_statistics.mjs
flutter test --reporter expanded
flutter analyze
flutter build web --no-web-resources-cdn
flutter build macos --debug
```

The exporter executes unchanged src/stats-store.ts with synthetic storage and emits 17 traces / 1474 events, with source SHA256. Tests compare each event's counters and history, then heat-map ratios. Additional checks cover disk failure/retry, immutable archive, completion transaction retry, input during an in-flight write, concurrent flushes, actual practice/course persistence and exclusion of spaces. The expanded actual course assertion caught inverted ok/error recording during development; corrected before acceptance. Existing navigation/theme/course/storage tests remain enabled.

Evidence: docs/test-output-statistics-20261026.txt and docs/verification-statistics-20261026.json. Build/analyze results recorded there after execution. Native build uses the separate candidate bundle ID; not a store artifact.

## Remaining

Weak-key/adaptive ranking and n-gram drill UI, visible heat-map controls, complete progress/forecast/achievements, remaining AI/competition/recall/memory/exam/kids modes and localization remain. Heat-map ratios are computed/tested, not yet displayed as a new UI feature. Remaining design comparisons, real packaged same-ID Tauri→Flutter update, mobile platforms/devices, accepted Synapse dependency/CI and release gates remain open.

The 800 ms batching is best effort: abrupt termination before persistence can lose unflushed keystrokes, as with the source. A persistent write failure cannot guarantee survival after process termination. No claim of crash/power-loss or real-device migration acceptance. No push, store upload, public deployment or real-user migration was performed for this stage.
