# TypeFree Flutter foundation · LOCAL · 25.10.2026

This is an isolated foundation, not a replacement for TypeFree 2.60.4.
No store platform project/signing, account/backend or real-user storage is wired.
Source baseline:2fa2b77. No installed app data is read or modified.

Design contract:
 /Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024/DESIGN_TEMPLATE_REF.md
Template registry: assets/templates/registry.json copied with provenance; no private Synapse art bundled.
Two templates each light/dark. Preview/cancel/apply are separate from domain state.
AppearanceTheme must wrap stable route/session widgets; do not key MaterialApp by templateId.
SynapseHeaderButton hosts a widget from an approved shared renderer; it is NOT that renderer.
No automatic speech/reward/LLM is implemented by the header.

Verify: flutter pub get --offline; flutter analyze; flutter test.
Remaining F1: real Tauri WebView→Flutter update/import platform proof; this package cannot claim data migration.

