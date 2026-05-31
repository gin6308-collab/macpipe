# MacPipe Search Quality Filtering Design

Date: 2026-05-30
Status: proposed

## Goal

Improve MacPipe's YouTube result list so the default search experience hides Shorts and suppresses obvious low-quality content while staying fast and predictable.

This feature should turn MacPipe's list from "raw YouTube/yt-dlp order" into a lightly curated media-picker list without pretending to be smarter than it is.

## Non-goals for v1

- Do not depend on YouTube's native AI summary or Ask UI.
- Do not use an LLM for default ranking.
- Do not deep-probe every result by default.
- Do not silently remove borderline results without a debug/explanation path.
- Do not make search noticeably slow for normal use.

## User-facing behavior

Default search uses quality mode `normal`:

```bash
macpipe search "qwen 3.7"
macpipe "qwen 3.7"
macpipe tty
```

Default behavior:

- Hide Shorts.
- Reject only obvious junk.
- Downrank questionable/clickbait content rather than deleting it.
- Over-fetch enough candidates to still show up to the requested display limit.
- Preserve a raw mode escape hatch.

New flags:

```bash
--quality off|normal|strict
--allow-shorts
--quality-debug
```

Optional later flag, not part of v1 implementation unless cheap:

```bash
--deep-quality
```

## Quality modes

### off

Current behavior. MacPipe shows decoded `yt-dlp` search results in returned order.

Use cases:

- debugging
- comparing MacPipe vs raw YouTube order
- searches where filtering gets in the way

### normal

Default mode.

Rules:

- reject invalid entries: missing video ID or unusable title
- reject Shorts unless `--allow-shorts` is set
- reject very obvious spam/junk
- score/rank accepted candidates using cheap metadata
- keep YouTube rank as a major tie-breaker

### strict

More aggressive mode.

Additional behavior:

- require stronger query/title relevance
- penalize clickbait harder
- penalize missing uploader/channel harder
- penalize suspicious duration harder

Strict mode may hide useful videos, so it is not the default.

## Over-fetching

Quality filtering means some candidates are removed. Therefore MacPipe must fetch more candidates than it displays.

Policy:

```text
if quality == off:
  fetchLimit = displayLimit
else:
  fetchLimit = max(displayLimit * 4, 20)
```

Then the quality layer returns at most `displayLimit` accepted results.

If fewer than `displayLimit` results survive, show the smaller list. In debug mode, show why candidates were rejected.

## Shorts detection

A candidate is considered a Short when any of these are true:

- `duration > 0 && duration < 61`
- normalized title contains `#shorts`
- normalized title contains `youtube shorts`
- normalized title contains `ytshorts`

Do **not** reject merely because the title contains the word `short` by itself; that creates false positives like "short film" or "short tutorial". Penalize it at most in strict mode if other Shorts signals exist.

Default:

```text
allowShorts = false
```

Override:

```bash
--allow-shorts
```

## Content-quality scoring

Create a pure scoring layer in MacPipeCore.

Suggested types:

```swift
public enum SearchQualityMode: String, Sendable, Codable {
    case off
    case normal
    case strict
}

public struct SearchQualityPolicy: Sendable, Codable {
    public var mode: SearchQualityMode
    public var allowShorts: Bool
    public var displayLimit: Int
}

public struct QualityDecision: Sendable, Equatable {
    public let result: SearchResult
    public let accepted: Bool
    public let score: Int
    public let reasons: [String]
    public let rejectionReason: String?
    public let originalIndex: Int
}
```

Scoring should be deterministic and tested with fixture data.

### Reject conditions

Reject in `normal` and `strict`:

- missing/blank video ID
- missing/blank title or title equal to `Unknown`
- Shorts when `allowShorts == false`
- extremely spammy title, e.g. mostly symbols/emoji or no meaningful words

Reject in `strict` only:

- very weak query match after normalization
- missing uploader/channel plus weak query match

### Score inputs

Boost:

- title contains all query terms
- title contains most query terms
- uploader/channel contains query term
- normal useful duration
- has thumbnail
- view count is present and meaningfully above nearby candidates
- high original YouTube rank, decaying by index

Penalize:

- clickbait phrase in title
- excessive punctuation, especially repeated `!` or `?`
- excessive all-caps ratio
- very long video unless query suggests long-form
- zero/unknown duration unless other signals are strong
- missing uploader/channel

### Long-form query hints

Do not penalize long videos when query contains terms suggesting long-form intent:

- `lecture`
- `podcast`
- `interview`
- `radio`
- `ambient`
- `mix`
- `full course`
- `course`
- `tutorial`
- `livestream`
- `stream`

## Debug explanations

`--quality-debug` should explain both accepted and hidden candidates.

Example:

```text
[1] Qwen 3.7 Demo · 12:41 · Some Channel
    quality 84: title match, normal duration, has thumbnail

Hidden:
- Qwen 3.7 in 30 seconds #shorts
    rejected: short duration, shorts marker
- YOU WON'T BELIEVE THIS AI MODEL!!!
    downranked: clickbait title, weak query match
```

For JSON mode, include quality metadata in a backwards-compatible way if practical. If that is too much for v1, keep debug output human-readable only and avoid changing default JSON shape.

## Architecture

Add a new file:

```text
Sources/MacPipeCore/SearchQuality.swift
```

Responsibilities:

- normalize title/query/uploader text
- detect Shorts
- detect obvious junk/clickbait
- score candidates
- return accepted candidates plus decisions

Keep `YtDlpClient` focused on fetching/decoding. It should not own quality logic.

Flat `yt-dlp` search results can include `view_count` for some YouTube results. Add `viewCount: Int?` to `SearchResult` and decode it from flat search metadata. Use it only as a mild boost, not a hard quality gate, because views are popularity-biased and may be missing.

Recommended flow:

```text
CLI/TUI asks for displayLimit + quality policy
YtDlpClient fetches fetchLimit raw results
SearchQualityScorer evaluates candidates
CLI/TUI displays accepted results
quality-debug displays decisions
```

## TUI behavior

The TUI should use the same quality path as the CLI.

For v1, no full filter UI is required. Show a compact status indicator later if easy:

```text
QUALITY Normal · Shorts Hidden
```

Do not add a filter overlay yet.

## Testing strategy

Unit tests in `Tests/MacPipeCoreTests/SearchQualityTests.swift`:

- hides duration-based Shorts by default
- hides title-marker Shorts by default
- `allowShorts` permits Shorts
- rejects blank/unknown titles
- downranks clickbait without always rejecting it
- strict mode rejects weak query matches
- long-form hints avoid long-duration penalty
- view count mildly boosts accepted candidates when present
- missing view count does not reject a candidate
- deduplicates repeated IDs and exact normalized-title duplicates
- preserves YouTube rank as tie-breaker when scores match

CLI smoke tests in `scripts/test_cli.sh`:

- `search <query> --quality off --limit 3` preserves current result-count behavior
- `search <query> --quality normal --limit 5` still returns up to 5 rows when enough candidates exist
- `search <query> --quality-debug` prints quality reasons
- `search <query> --allow-shorts` accepts the flag without treating it as query text

Use fixture/unit tests for exact quality behavior. Avoid relying on live YouTube search results for assertions about Shorts/clickbait because live search is unstable.

## Rollout plan

1. Add pure quality scorer and unit tests.
2. Add CLI parsing for `--quality`, `--allow-shorts`, and `--quality-debug`.
3. Change search/default query paths to over-fetch when quality is enabled.
4. Wire the TUI search effect through the same quality path.
5. Add smoke tests for flag parsing and debug output.
6. Verify with:
   - `swift test -j 1`
   - `scripts/test_cli.sh`
   - `swift build --product macpipe -j 1`

## Future additions

The initial implementation should use conservative defaults. Tune thresholds after manual testing with real queries.

Likely future additions:

- optional `--deep-quality` metadata probe for top candidates
- transcript availability scoring
- transcript summary/relevance scoring
- per-channel allow/block preferences
- TUI filter overlay
