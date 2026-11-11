# Vendored ecosystem packages (pin)

Exact copy of two shared packages from the public repo `donosov999-ai/psygames-native`,
taken with `git archive` — do not edit them here; update by re-vendoring a new pin.

| package | version | source path | tree |
|---|---|---|---|
| `ecosystem_account` | 0.1.6 | `packages/ecosystem_account` | `e7ba686ff19a1e4eb60321174e6205cac39bb49c` |
| `ecosystem_coach` | 0.1.0 | `packages/ecosystem_coach` | `efee6478c0d9ba795f38c1f8fe76fe64cb2bb282` |

Source commit: `9b12c8b563f395f1f9faa125b50aa13aef81d4a1`.

```sh
git -C <psygames-native> archive 9b12c8b563f395f1f9faa125b50aa13aef81d4a1 \
  packages/ecosystem_account packages/ecosystem_coach | tar -x -C <this repo root>
```

The only difference from the source tree: in `ecosystem_account/CONTRACT.md`
(section «Readiness sources») three absolute local paths are replaced with
`<local dev>/…`. Code (`lib/`, `test/`, `pubspec.*`) is byte-identical.

Contract: `ecosystem_coach/CONTRACT.md` → «How to connect an app». TypeFree uses
app_id `typerighting`, link scheme `pro.typefree.app`.
