# Vendored ecosystem packages (pin)

Exact copy of two shared packages from the public repo `donosov999-ai/psygames-native`,
taken with `git archive` — do not edit them here; update by re-vendoring a new pin.

| package | version | source commit | tree |
|---|---|---|---|
| `ecosystem_account` | 0.1.6 | `9b12c8b563f395f1f9faa125b50aa13aef81d4a1` | `e7ba686ff19a1e4eb60321174e6205cac39bb49c` |
| `ecosystem_coach` | 0.1.0 | `efcdb98bafcac9e8d3b2e9bd10859a6bd6be2569` | `4b38ad23217baf89be6cad6f3f4955044a4b1058` |

History: `ecosystem_coach` first vendored at `9b12c8b` (tree `efee647`);
updated 11.11.2026 to `efcdb98` (coach/2 strings: sharedScopes, eventsCount,
lastAt, metric*, warmup; `eventTitle`; `coachMetricsLine`). `ecosystem_account`
unchanged between the two commits.

```sh
git -C <psygames-native> archive <source commit> packages/<package> | tar -x -C <this repo root>
git -C <psygames-native> rev-parse <source commit>:packages/<package>   # must equal the tree
```

The only difference from the source tree: in `ecosystem_account/CONTRACT.md`
(section «Readiness sources») three absolute local paths are replaced with
`<local dev>/…`. Code (`lib/`, `test/`, `pubspec.*`) is byte-identical.

Contract: `ecosystem_coach/CONTRACT.md` → «How to connect an app». TypeFree uses
app_id `typerighting`, link scheme `pro.typefree.app`.
