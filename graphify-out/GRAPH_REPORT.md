# Graph Report - typerighting  (2026-06-27)

## Corpus Check
- 49 files · ~786,457 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 649 nodes · 1308 edges · 45 communities (44 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `557bc21f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]

## God Nodes (most connected - your core abstractions)
1. `t()` - 43 edges
2. `lang` - 34 edges
3. `render()` - 31 edges
4. `createState()` - 22 edges
5. `keyboardSVG()` - 21 edges
6. `keyIdFor()` - 16 edges
7. `bridgeChar()` - 15 edges
8. `pressChar()` - 15 edges
9. `kidsGenLine()` - 14 edges
10. `recordKey()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `kidsGenLine()` --calls--> `pick()`  [INFERRED]
  src/learn.ts → src/kids.ts
- `renderTopbar()` --calls--> `loadSession()`  [EXTRACTED]
  src/main.ts → src/account.ts
- `recordFinish()` --calls--> `pushSync()`  [EXTRACTED]
  src/main.ts → src/account.ts
- `notifyBadges()` --calls--> `checkNewBadges()`  [EXTRACTED]
  src/main.ts → src/achievements.ts
- `renderModal()` --calls--> `unlockedSet()`  [EXTRACTED]
  src/main.ts → src/achievements.ts

## Import Cycles
- None detected.

## Communities (45 total, 1 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (49): CORPUS, getLayout(), handLetters(), letterKeys(), Acc, adultAdapt(), blank(), cleanLine() (+41 more)

### Community 1 - "Community 1"
Cohesion: 0.09
Nodes (45): competeHandleKey(), courseHandleKey(), bridgeChar(), findKey(), keyIdFor(), learnHandleKey(), statTrack(), accNow() (+37 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (40): buildLessons(), capsLines(), courseEnter(), CourseProgress, courseRender(), digitDrill(), drill(), esc() (+32 more)

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (33): lang, clearDoneTimer(), EN3, EN4, EN5, esc(), finishLevel(), goNextLevel() (+25 more)

### Community 4 - "Community 4"
Cohesion: 0.08
Nodes (28): all, applyLayout(), bindControls(), customLines, dark, flow, kbShowRu(), keybBlock() (+20 more)

### Community 5 - "Community 5"
Cohesion: 0.11
Nodes (31): ALPHA, best, bestKey(), boardRows, competeEnter(), content(), curLang(), DISCIPLINES (+23 more)

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (29): accNow(), bestSpan, clearTimer(), esc(), finishRound(), levelNo(), pickWords(), recallEnter() (+21 more)

### Community 7 - "Community 7"
Cohesion: 0.10
Nodes (27): arrowPath(), ARROWS, COL_GROUP, cx(), cy(), EN_MAP, EN_TO_RU, engraving() (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.18
Nodes (22): applyLocal(), autoSync(), callRpc(), clearSession(), collectLocal(), deepMergeMax(), DEVICE_ONLY, headers (+14 more)

### Community 9 - "Community 9"
Cohesion: 0.11
Nodes (19): CLASSIC, CLASSIC_TITLE, classicExercises(), Bank, BANKS, Exercise, exercisesOfBank(), loadExercises() (+11 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (22): app, security, windows, build, beforeBuildCommand, beforeDevCommand, devUrl, frontendDist (+14 more)

### Community 11 - "Community 11"
Cohesion: 0.12
Nodes (16): 1. Что это, 2. Где что лежит (абсолютные пути, macOS), 3. Что уже готово (v2.0.0), 4. Как запустить и проверить, 5. ЗАДАЧИ (по приоритету), 6. Грабли / окружение, 7. Стиль работы (важно для ODV999), ⚪ Доработки UX (+8 more)

### Community 12 - "Community 12"
Cohesion: 0.12
Nodes (16): description, devDependencies, @tauri-apps/cli, typescript, vite, vitest, name, private (+8 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (15): compilerOptions, isolatedModules, lib, module, moduleResolution, noEmit, noFallthroughCasesInSwitch, noUnusedLocals (+7 more)

### Community 14 - "Community 14"
Cohesion: 0.23
Nodes (13): AchStats, Badge, BADGES, checkNewBadges(), gather(), langsTried(), RULES, savedIds() (+5 more)

### Community 15 - "Community 15"
Cohesion: 0.25
Nodes (14): exitExam(), exState(), goTo(), nextSpecial(), reapplyGlobal(), render(), reset(), startCustom() (+6 more)

### Community 16 - "Community 16"
Cohesion: 0.15
Nodes (13): definitions, Number, PermissionEntry, Target, Value, anyOf, description, anyOf (+5 more)

### Community 17 - "Community 17"
Cohesion: 0.15
Nodes (13): definitions, Number, PermissionEntry, Target, Value, anyOf, description, anyOf (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.22
Nodes (13): t(), curExercise(), downloadCertificate(), esc(), examStats(), finishExam(), fmtTime(), notifyBadges() (+5 more)

### Community 19 - "Community 19"
Cohesion: 0.20
Nodes (10): properties, type, default, description, type, identifier, local, remote (+2 more)

### Community 20 - "Community 20"
Cohesion: 0.20
Nodes (10): $ref, description, items, type, uniqueItems, description, items, type (+2 more)

### Community 21 - "Community 21"
Cohesion: 0.20
Nodes (10): type, webviews, windows, items, description, items, type, description (+2 more)

### Community 22 - "Community 22"
Cohesion: 0.20
Nodes (10): properties, type, default, description, type, identifier, local, remote (+2 more)

### Community 23 - "Community 23"
Cohesion: 0.20
Nodes (10): $ref, description, items, type, uniqueItems, description, items, type (+2 more)

### Community 24 - "Community 24"
Cohesion: 0.20
Nodes (10): type, webviews, windows, items, description, items, type, description (+2 more)

### Community 25 - "Community 25"
Cohesion: 0.22
Nodes (8): Desktop (Tauri 2), TODO (следующие этапы), TypeRIGHTing 2.0, Банки упражнений, Запуск (веб), История, Кроссбилд (GitHub Actions), Что сделано (v2.0.0)

### Community 26 - "Community 26"
Cohesion: 0.22
Nodes (8): current, DICT, Entry, LANG_LABEL, LANGS, setLang(), bindLang(), renderOnboarding()

### Community 27 - "Community 27"
Cohesion: 0.25
Nodes (8): description, properties, required, type, CapabilityRemote, urls, description, type

### Community 28 - "Community 28"
Cohesion: 0.25
Nodes (8): description, properties, required, type, CapabilityRemote, urls, description, type

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (5): all, FILE, out, poems, rest

### Community 30 - "Community 30"
Cohesion: 0.33
Nodes (6): activeMode(), modeIcon(), profDir(), renderTopbar(), uiIcon(), updateMetronome()

### Community 31 - "Community 31"
Cohesion: 0.40
Nodes (4): anyOf, description, $schema, title

### Community 32 - "Community 32"
Cohesion: 0.40
Nodes (4): anyOf, description, $schema, title

### Community 33 - "Community 33"
Cohesion: 0.50
Nodes (4): description, required, type, Capability

### Community 34 - "Community 34"
Cohesion: 0.50
Nodes (4): default, description, type, description

### Community 35 - "Community 35"
Cohesion: 0.50
Nodes (4): description, required, type, Capability

### Community 36 - "Community 36"
Cohesion: 0.50
Nodes (4): default, description, type, description

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (3): Identifier, description, oneOf

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (3): Identifier, description, oneOf

## Knowledge Gaps
- **250 isolated node(s):** `name`, `private`, `version`, `type`, `description` (+245 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `t()` connect `Community 18` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 8`, `Community 15`, `Community 26`, `Community 30`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `lang` connect `Community 3` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 15`, `Community 26`, `Community 30`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `createState()` connect `Community 15` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `name`, `private`, `version` to the rest of the system?**
  _250 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07744107744107744 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.08953900709219859 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.080338266384778 - nodes in this community are weakly interconnected._