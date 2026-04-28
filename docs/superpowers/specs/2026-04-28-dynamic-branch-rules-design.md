# Dynamic Branch Rules

**Date:** 2026-04-28

## Problem

Repositories currently track a single fixed branch name (`Repository.branch: String`).
Many teams use date-suffixed branch names like `test-20260326`, `staging-20260324`,
`release-20260128`. Users have to manually update the configured branch every time a
new dated branch is cut. We want the monitor to automatically pick the latest matching
branch on every poll cycle.

## Goals

1. Allow each repository to either pin a fixed branch (existing behavior) or specify a
   rule that dynamically selects the latest matching branch.
2. Resolve the rule on every poll, so the displayed pipeline always reflects the most
   recent dated branch.
3. Keep configuration simple: prefix is user-provided, the date format is picked from
   a small preset list, with a "custom regex" escape hatch.
4. Preserve users' existing repository configurations without manual migration.

## Non-Goals

- Server-side branch sorting by commit time.
- Wildcard support beyond regex.
- Multi-branch monitoring per repository (still 1 row = 1 resolved branch).

## Data Model

### `BranchSelector` (new)

```swift
enum BranchSelector: Codable, Equatable {
    case fixed(String)
    case rule(prefix: String, format: BranchDateFormat)
    case regex(String)
}

enum BranchDateFormat: String, Codable, CaseIterable {
    case yyyymmdd          // ^{prefix}-\d{8}$
    case yyyymmddDashed    // ^{prefix}-\d{4}-\d{2}-\d{2}$
    case yyyymmddDotted    // ^{prefix}-\d{4}\.\d{2}\.\d{2}$
    case yyyymmddWithTail  // ^{prefix}-\d{8}-.+$
}
```

`BranchDateFormat` exposes a `regex(prefix:)` helper that builds the final pattern with
the user's prefix escaped.

### `Repository` (changed)

Replace `branch: String` with `branchSelector: BranchSelector`. Implement custom
`Codable` so old JSON `{"branch":"staging"}` decodes to `.fixed("staging")` and round-trips
to the new format on save. Old configs continue to work unchanged.

## Resolution

A new `BranchResolver` service:

```swift
struct BranchResolver {
    let service: GitLabServiceProtocol
    func resolve(
        selector: BranchSelector,
        gitlabUrl: String,
        projectPath: String,
        token: String
    ) async throws -> String?
}
```

Logic:

- `.fixed(name)` → return `name` immediately, no API call.
- `.rule(prefix, format)` → call `fetchBranches(byPath: projectPath, search: "^\(prefix)-")`
  with `per_page=20`. Filter results by the regex from `format.regex(prefix:)`. Sort
  matching names lexicographically descending. Return the first or `nil`.
- `.regex(pattern)` → call `fetchBranches(byPath: projectPath, search: nil)`,
  `per_page=20` (alphabetical order from GitLab). Filter by pattern. Sort desc. Return
  first or `nil`.

Returning `nil` is treated as "no branch matched" downstream.

## Service Layer

`GitLabServiceProtocol` gains:

```swift
func fetchBranches(
    gitlabUrl: String,
    token: String,
    projectPath: String,
    search: String?
) async throws -> [GitLabBranch]
```

Implementation: percent-encodes the path (slash → `%2F`) and calls
`/projects/<encoded>/branches?search=<search>&per_page=20` (omit `search` if nil).

The existing `fetchBranches(projectId:)` for the settings UI stays.

`GitLabError` adds `case noBranchMatch` with localized "未匹配到分支".

## Polling

`PipelinePoller.pollOnce`:

```
for repo:
    let resolved = try await resolver.resolve(selector: repo.branchSelector, …)
    guard let branch = resolved else {
        store.applyError(.noBranchMatch, repoId)
        continue
    }
    let result = try await service.fetchLatestPipeline(branch: branch, …)
    store.applyResult(result, resolvedBranch: branch, repoId)
```

Fixed-mode repos still make one API call (the pipeline call). Rule-mode repos make two.

## Store / View

`RepositoryState` gains `resolvedBranch: String?`. `applyResult(_:resolvedBranch:for:)`
updates it. `RepositoryRowView` displays `state.resolvedBranch ?? <fallback>` instead of
`state.repository.branch`. Fallback for fixed mode is the fixed name; for rule mode
when not yet resolved, show the prefix in muted color (e.g. `test-…`).

## UI: Settings — Branch Mode Picker

Inside `ProjectSearchView` (or a new `BranchSelectorView`), per selected repo:

```
分支
  ◉ 固定分支    [ 下拉:  main / staging / ...  ]
  ○ 动态匹配最新
       前缀:   [ test                    ]
       格式:   [ YYYYMMDD               ▾ ]
       预览:   匹配 ^test-\d{8}$
  ○ 自定义正则
       正则:   [ ^test-\d{8}-hotfix$     ]
```

When the user is in rule or regex mode, after a 300 ms debounce we call
`fetchBranches(projectPath:search:)` and show the first 3 branch names that match. Empty
list → red "无匹配分支".

The format dropdown options are labeled with examples:
- `YYYYMMDD` → e.g. `test-20260326`
- `YYYY-MM-DD` → e.g. `test-2026-03-26`
- `YYYY.MM.DD` → e.g. `test-2026.03.26`
- `YYYYMMDD-<尾缀>` → e.g. `test-20260326-hotfix`

## Testing

TDD before implementation:

1. **`BranchDateFormatTests`** — each case generates the expected regex string; prefix
   with regex meta-characters is escaped.
2. **`BranchSelectorCodableTests`** — round-trip `.fixed`, `.rule`, `.regex`.
3. **`RepositoryCodableTests`** — old JSON `{"branch":"staging"}` decodes to
   `.fixed("staging")`; new JSON round-trips.
4. **`BranchResolverTests`** (mocked service):
   - `.fixed` returns the literal name and never calls `fetchBranches`.
   - `.rule(prefix:"test", format:.yyyymmdd)` over `[test-20260128, test-20260326,
     test-feature]` returns `test-20260326`.
   - No matching branch returns `nil`.
   - Custom regex matching multiple returns the lexicographically largest.
5. **`PipelinePollerTests`** — rule with no match → `applyError(.noBranchMatch)`,
   `fetchLatestPipeline` not called; rule with match → resolved branch propagates to
   `fetchLatestPipeline` and to `RepositoryState.resolvedBranch`.

## File Changes

| File | Change |
|---|---|
| `Models/Repository.swift` | swap `branch` → `branchSelector`; custom Codable migration |
| `Models/BranchSelector.swift` | **new** — enum + `BranchDateFormat` |
| `Services/BranchResolver.swift` | **new** |
| `Services/GitLabService.swift` | add `fetchBranches(byPath:search:)` |
| `Services/GitLabServiceProtocol.swift` | add same to protocol; add `.noBranchMatch` |
| `Polling/PipelinePoller.swift` | resolve before fetching pipeline |
| `Store/RepositoryStore.swift` | `resolvedBranch` field + apply* signatures |
| `Views/ProjectSearchView.swift` | branch mode picker |
| `Views/RepositoryRowView.swift` | display resolvedBranch |
| `GitLabMonitorTests/...` | new test files per the plan above |

## Backward Compatibility

Existing on-disk `AppSettings` JSON has `repositories[].branch` strings. The migration
runs through `Repository`'s custom decoder: missing `branchSelector` and present
`branch` → `BranchSelector.fixed(branch)`. After the next save, the JSON shifts to
the new shape. Tests cover both paths.
