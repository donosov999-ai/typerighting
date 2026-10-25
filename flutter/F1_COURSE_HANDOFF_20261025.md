# TypeFree · F1 archive adapter and structured course · LOCAL · 25 October 2026

Project: TypeFree / typefree.pro. Executor typerighting-codex-mac.
Checkout /Users/denisonosov/dev/typerighting-wt-flutter-20261025, branch codex/typefree-flutter-20261025. Previous milestone a6858c5, prior handoff f1be90f. Old Tauri baseline 2fa2b77f032e77b759b29b44d223c7f91578597b.

## Implemented

- Split pure file store from platform path lookup, enabling actual native file-store tests and standalone Dart transfer harness without Flutter plugin initialization.
- Preserved imported values in a frozen legacyArchive, separate from the live legacy mirror. Later history trimming/new result writes never truncate the archive. Existing candidate preferences win; supported missing preferences, old bank resume index and appearance defaults are adapted. Disabled Shestov banks fall back to visible choices but their progress remains archived.
- Progress UI shows imported timeline, course/kids stars, achievements count and per-bank records. Old history has no exercise/language/profile/mode: those are not invented and imported rows never become Synapse facts. Source accuracy fractions/percentages normalize for display while raw values remain unchanged. Legitimate duplicate old rows remain separate; new mirrored rows do not duplicate the archive.
- Load validation rejects corrupt archived rows, forbidden account keys, malformed receipts, invalid preferences/resume values and incomplete/nonfinite candidate session rows. Candidate custom-text progress from the earlier milestone remains readable. Failed loads do not overwrite disk.
- Reproducible native macOS WKWebView fixture: python3 tool/run_webkit_fixture.py. Fresh named WKWebsiteDataStore, synthetic keys, separate writer and reader processes, local Dart allowlisted transfer, real file-store reload and idempotent replay. 21 stored fixture keys ->18 permitted keys; PIN/device/queue sentinels excluded. Source JSON unchanged. Named-store fixture does not discover installed app containers.
- Actual course tab: source programme 19 lessons ×7 languages; real per-line blocked typing, original Backspace behavior, generated drills, full physical keyboard, global error/character stars, sequential unlock, atomic stars/history save and retry. Last-line WPM/accuracy matches the old course's metric, explicitly labelled; total lesson errors drive stars. Source RNG call order in digit drills retained. Source/133 deterministic golden cases extracted by tool/export_course.mjs.
- Course session stays mounted across template changes; guarded Synapse callback cannot send an old profile/language completion to a newly selected profile/language. Shared Synapse core is unchanged.

## Verification

77 tests PASS; flutter analyze clean. Web release and isolated macOS debug build PASS. All eight previous TS source hashes plus course.ts source hash unchanged. Evidence docs/verification-f1-course-20261025.json, docs/test-output-f1-course-20261025.txt, docs/webkit-fixture-proof-20261025.json, test/fixtures/course-generation.json.
Browser at http://127.0.0.1:8062/: course entered, all five lines physically sent through the live TextField, completion saved, reload, first lesson three stars and second lesson unlocked. docs/course-reload-proof-20261025.png. These automated inputs are test results, not evidence of Denis's typing performance or cognitive improvement.
Widget verification includes actual course save failure/rollback/retry/duplicate prevention, full keyboard fitting 1280x720 after completion; ordinary practice and narrow-screen checks remain green. Native file-store interruption/error tests preserve the primary file and allow retry.

## Deployed

Only local loopback preview rebuilt. No push, website production, TestFlight, Play or real-user migration. Installed old app unchanged. macOS bundle remains pro.typefree.candidate.typefreeFlutterFoundation, debug only; no physical-device acceptance claimed.
Disk ran out during work; removed only this branch's generated flutter/build/macos directory, retained source/evidence and rebuilt it successfully. Other projects/user data were not cleaned.

## Remaining / next implementation

F1 task ab250f45-e333-4b6d-9617-7b6ef7917564 remains in_progress: actual packaged Tauri-to-Flutter same-ID update in disposable containers is NOT proven. iOS/Android/Windows extraction and real physical update/crash recovery also remain. This fixture is genuine WKWebView persistence, not installed-app migration acceptance. No automatic discovery or migration of real user containers is enabled.

Mode task 2046fb02-53b1-47db-918f-e0a2a417e6a3 remains in_progress. Next: shared per-key statistics/EMA/timing/heatmap updates for new practice/course input, weak-key/adaptive mode, then competition, recall, memory, exam and kids flows. Existing imported keystats are preserved, but new per-key measurements are not yet wired. Current history len/errors use candidate attempt counters; exact legacy recordKey-based history semantics need parity in that statistics step. Do not call the course fully feature-equivalent or release-ready yet.

All-screen visual template acceptance, full seven-language UI localization, help/audio/exports/achievements and remaining59-group parity remain. Account/coach backends stay separate with their prior gates. Private author playlist selector is not shipped. Shared Synapse dependency is still the local owner candidate, not accepted release; e820238d-8f28-44ce-8751-6c03a9c8905a tracks accepted dependency/device/release gates. Parent568d223e-d42c-4e30-83a0-fbad3a95e721 stays in_progress. New costs/production/real-user migrations require separate approval.
