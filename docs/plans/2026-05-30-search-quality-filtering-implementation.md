# Search Quality Filtering Implementation Plan

> **For Hermes:** Implement directly with strict TDD; keep changes small and verify each layer.

**Goal:** Add conservative default search quality filtering to hide Shorts and suppress low-quality YouTube results while preserving raw mode and debug explanations.

**Architecture:** Keep `YtDlpClient` responsible for fetching/decoding and add a pure `SearchQualityScorer` in `MacPipeCore`. CLI/default/TUI search flows request an over-fetched candidate list, pass it through the scorer, then display accepted results. Quality behavior is deterministic and tested with fixtures.

**Tech Stack:** Swift Package Manager, XCTest, `yt-dlp`, Bash smoke tests.

---

### Task 1: Core quality scorer via TDD

**Objective:** Add pure quality policy/scoring types and tests.

**Files:**
- Create: `Sources/MacPipeCore/SearchQuality.swift`
- Create: `Tests/MacPipeCoreTests/SearchQualityTests.swift`

**Steps:**
1. Write tests for Shorts rejection, `allowShorts`, unknown title rejection, clickbait downrank, strict weak-match rejection, long-form hint handling, view-count boost, missing view-count neutrality, dedupe, and rank tie-breaker.
2. Run: `swift test --filter SearchQualityTests -j 1` and confirm failure because types do not exist.
3. Implement minimal `SearchQualityMode`, `SearchQualityPolicy`, `QualityDecision`, and `SearchQualityScorer`.
4. Run focused tests until green.

### Task 2: Extend SearchResult metadata

**Objective:** Add optional `viewCount` without breaking existing callers.

**Files:**
- Modify: `Sources/MacPipeCore/Models.swift`
- Modify: `Sources/MacPipeCore/YtDlpClient.swift`
- Update tests if constructor calls require defaults.

**Steps:**
1. Add failing test or compile failure via SearchQuality tests that use `viewCount`.
2. Add `public let viewCount: Int?` with default `nil` in initializer.
3. Decode `view_count` in `YtDlpSearchItem` and pass it through.
4. Run `swift test --filter SearchQualityTests -j 1`.

### Task 3: Wire CLI quality options

**Objective:** Parse `--quality`, `--allow-shorts`, and `--quality-debug`, over-fetch, filter, and display debug reasons.

**Files:**
- Modify: `Sources/MacPipeCLI/main.swift`

**Steps:**
1. Inspect current argument parsing for search/default flows.
2. Add parsing while ensuring flags do not become query terms.
3. In quality `off`, preserve existing fetch/display behavior.
4. In `normal`/`strict`, use `fetchLimit = max(displayLimit * 4, 20)` and return up to display limit.
5. Add debug output for accepted and hidden decisions in human-readable mode only.
6. Keep JSON default shape stable for v1.
7. Run relevant CLI commands manually with dry/safe searches.

### Task 4: Wire TUI quality path

**Objective:** Make TUI use the same normal quality filtering path as CLI.

**Files:**
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Steps:**
1. Add `qualityMode` / `allowShorts` options if needed.
2. Over-fetch during search effect.
3. Filter accepted results before `receiveResults`.
4. Keep mock/scripted tests deterministic.

### Task 5: Smoke tests and verification

**Objective:** Verify behavior through unit and CLI smoke tests.

**Files:**
- Modify: `scripts/test_cli.sh`

**Steps:**
1. Add smoke checks for `--quality off`, `--quality normal`, `--allow-shorts`, and `--quality-debug` flag parsing/debug output.
2. Avoid live YouTube assertions for exact quality decisions.
3. Run:
   - `swift test -j 1`
   - `scripts/test_cli.sh`
   - `swift build --product macpipe -j 1`
4. Inspect `git diff` and commit.
