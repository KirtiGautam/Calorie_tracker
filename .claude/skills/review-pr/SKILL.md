---
name: review-pr
description: Reviews a Gramwise (CalTracker) pull request, branch, or local diff against the project's AGENTS.md rules and the Swift, SwiftUI, SwiftData, concurrency, testing, accessibility and security guidelines distilled from twostraws/swift-agent-skills. Use when asked to review a PR, review changes before merge, check a branch, or answer "is this ready to merge?".
argument-hint: "[PR number | PR URL | branch | blank for current changes] [--no-build]"
---

# Review a pull request

Review a change to this repository the way a careful senior iOS reviewer would. Find real problems in the diff, prove each one by reading the code, rank them, and give a clear merge verdict. This is a read-only review. Don't fix anything unless the user asks you to afterwards.

## Ground rules

1. **Read-only.** Don't edit files, stage, commit, push, check out branches in the user's working copy, or post to GitHub. Posting needs an explicit request (see Step 7).
2. **Report only genuine problems.** Don't nitpick or invent issues. It's better to miss a nit than to bury a real bug in noise. Never pad a clean review.
3. **Review the diff, not the whole codebase.** Read whole files for context, but only report problems the PR introduces or makes worse. A severe existing problem the PR touches can go under "Outside this PR", in one line.
4. **Project rules win.** `AGENTS.md` (also `CLAUDE.md`) overrides generic guidance. The repo-root `SKILL.md` has the long-form Swift and SwiftUI guidance. Use it to settle detail questions.
5. **Compiling is not proof.** SwiftData predicates, continuations, actor reentrancy and some concurrency patterns build cleanly and then fail at runtime. Read the logic.
6. **Verify every finding** by reopening the cited lines in the PR's version of the file. If you can't confirm a claim from the code, drop it or turn it into a question.
7. **Group by root cause.** One missing migration stage that breaks three call sites is one finding listing three locations.
8. **Know the baseline:** iOS/iPadOS 27.0 only, Xcode 27.1, Swift 6, strict concurrency `complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency on, no third-party packages. A missing `@MainActor` is therefore not a finding. Code that should run off the main actor (`Domain/`, mappers, DTOs) must say `nonisolated`.

## Step 1: Resolve the scope

Parse `$ARGUMENTS`:

| Argument | Get metadata and diff with |
|---|---|
| PR number or URL | `gh pr view <n> --json number,title,body,author,baseRefName,headRefName,headRefOid,commits,files,additions,deletions,url` and `gh pr diff <n>` |
| Branch name | `git log --oneline master..<branch>` and `git diff master...<branch>` |
| Blank, on a feature branch | `git diff master...HEAD` plus any uncommitted work from `git diff HEAD` |
| Blank, on `master` | `git diff HEAD` (staged and unstaged). If it's empty, say there's nothing to review and stop. |

`--no-build` skips Step 3b. Also skip it when the diff touches no Swift, project, plist, xcconfig or string catalog files.

For a PR, note `baseRefName`. If it isn't `master`, diff against that base.

## Step 2: Build an intent packet

Before judging the code, write down for yourself:

1. **What should change.** Take this from the PR title, body and commit messages.
2. **What must not change.** Think about adjacent behavior, saved user data, other screens, and the other food source.
3. **Constraints.** These include schema compatibility with existing installs, the iPhone Duo and iPad window sizes, and the offline and one-source-failing paths.

If the intent isn't stated, infer it from the diff and say in the report that you inferred it.

Then pick the reference checklists to load. Always load `project-rules.md`, then add the others based on what the diff touches:

| The diff touches | Load |
|---|---|
| anything | `references/project-rules.md` |
| any `.swift` file | `references/swift.md` |
| `Features/**`, any `View`, `@Observable` view models, `Localizable.xcstrings`, assets | `references/swiftui.md` |
| `async`, `await`, `Task`, `actor`, `Sendable`, `nonisolated`, `@concurrent`, continuations, streams, or anything in `Data/` | `references/concurrency.md` |
| `Data/Persistence/**`, `@Model`, `#Predicate`, `ModelContext`, `@Query`, `FetchDescriptor` | `references/swiftdata.md` |
| `CalTrackerTests/**`, `CalTrackerUITests/**`, or new logic that ought to have tests | `references/testing.md` |
| `Config/**`, `Info.plist`, `project.pbxproj`, networking, `UserDefaults`, logging, user input, decoding remote JSON | `references/security.md` |

The reference files live next to this file, in `.claude/skills/review-pr/references/`.

## Step 3: Gather ground truth

### 3a. Hotspot scan (always)

Pipe a zero-context diff into the scanner. It prints `path:line [rule] code` for patterns that are often wrong:

```sh
git diff -U0 --no-color <range> | bash .claude/skills/review-pr/scripts/hotspots.sh
# For a PR: gh pr diff <n> --patch | ... works too, but -U0 output gives exact line numbers.
```

A hit is a **lead, not a finding**. Open each one and decide. Many will be fine in context. For example, a literal `Text("…")` can be fine inside `#Preview`.

### 3b. Build and unit tests (unless skipped)

For a PR or another branch, build in a detached worktree in the scratchpad directory, so the user's checkout and DerivedData are untouched:

```sh
git fetch origin pull/<n>/head            # or: git fetch origin <branch>
git worktree add --detach <scratchpad>/review-<n> FETCH_HEAD
cd <scratchpad>/review-<n>
xcodebuild build -project CalTracker.xcodeproj -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath <scratchpad>/review-<n>-dd 2>&1 | grep -E ' (warning|error): ' | sort -u
NSUnbufferedIO=YES xcodebuild test -project CalTracker.xcodeproj -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath <scratchpad>/review-<n>-dd \
  -only-testing:CalTrackerTests -collect-test-diagnostics never
```

For the current branch, run the same commands in the repo, without the worktree.

- **Always pass `-collect-test-diagnostics never`.** Without it, a run with a failing test can hang and never exit.
- If `iPhone Duo` isn't installed, pick another device from `xcrun simctl list devices available`. If the Xcode MCP tools are connected, prefer them.
- `Config/Secrets.xcconfig` is gitignored and included with `#include?`, so the worktree builds with `DEMO_KEY`. That's expected.
- Keep only warnings in files the PR changed, plus any new warnings it causes elsewhere. A build or test failure is a finding on its own (see Step 5).
- Don't run the UI tests unless asked. They're slow and hit the live USDA and Open Food Facts APIs.
- When you're done, run `git worktree remove --force <scratchpad>/review-<n>`.

## Step 4: Review

Read every changed file **in full** at the PR's version, plus the direct callers and callees of anything whose signature or behavior changed. Then make these passes:

1. **Intent and regressions.** Does the diff do what it claims and nothing else? Check edge cases: zero, one and many items; an empty or whitespace query; offline; one source failing while the other succeeds; very long food names; huge or zero serving sizes; a day boundary or time zone change. Check that every caller, test double (`SpyFoodLogging`, `StubFoodSearchProvider`, `MockHTTPClient`) and `AppDependencies` factory was updated with the protocol or initializer it depends on.
2. **Domain checklists.** Work through each reference file loaded in Step 2. Apply only the rules the diff actually touches.
3. **Tests.** New logic in `Domain/`, `Data/` or a view model needs Swift Testing coverage that follows `references/testing.md`. A bug fix needs a test that fails without the fix. Missing tests for a risky change is a real finding.
4. **Security and privacy.** Check secrets, logging, untrusted remote data, and anything stored on device.

## Step 5: Verify and rate

For each candidate finding, reopen the lines and confirm that the code really does what you claim and that the problem comes from this PR. For anything Critical or High, trace the failure concretely: which input or state leads to which wrong result. Drop what you can't confirm. If the finding depends on intent you can't determine, ask it as a question instead.

| Severity | Meaning in this project |
|---|---|
| **Critical** | Crash, lost or corrupted food logs or targets, a committed secret, build broken, unit tests failing. |
| **High** | A bug users will hit. An error from a user action swallowed or only printed. A SwiftData schema change without a migration stage. A data race or strict-concurrency warning. Live network in unit tests. A broken `AGENTS.md` "don't": new dependency, deployment target change, hand-edited `project.pbxproj` file references, rename of targets or bundle ID. |
| **Medium** | An accessibility gap, a user-facing string not in the catalog, missing tests for new logic, deprecated or soft-deprecated API, work in a hot path (`body`, row views), or a convention break with real maintenance cost. |
| **Low** | Naming, a small modernization, doc comment wording. Report at most five, and none if the review is already long. |

**Verdict.** Any Critical or High finding means **Request changes**. Only Medium or Low findings means **Approve with comments**. No findings means **Approve**.

## Step 6: Report

Use this shape. Keep it tight: findings first, no preamble, no restating the diff.

````markdown
## Review: <PR title or branch> — <Approve | Approve with comments | Request changes>

**Scope:** <PR #n / branch / local changes>, <files> files, +<adds> −<dels>. **Intent:** <one sentence, and "(inferred)" if it was>.
**Build:** <clean | n new warnings | failed | skipped (reason)>. **Unit tests:** <passed (count) | n failed | skipped>.

### Findings

#### 1. [High] <short claim> — `CalTracker/Features/Today/TodayView.swift:42`
**Rule:** <the rule, in one line> (<reference file and section>)
**Why it matters:** <the concrete failure: input or state → wrong result>
**Fix:**
```swift
// Before
…
// After
…
```

#### 2. …

### Questions
- <anything that depends on intent you couldn't determine>

### Path forward
- **Fix before merge:** #1, #3
- **Fix soon:** #2
- **Optional:** #4

### Not checked
- <for example: UI tests not run, VoiceOver and iPhone Duo fold checks need a manual pass, translations not reviewed>
````

Rules for the report:

- Order findings by severity, then by confidence. Add "(confidence: medium)" only when confidence isn't high.
- Keep each before/after short and specific to the cited lines. If the fix is a design change, describe it instead of writing code.
- If a section is empty, leave it out. If there are no findings, say so in one line under the verdict.
- Write file paths as repo-relative `path:line` so they're clickable.
- Use "Outside this PR" (one line per item) only for severe existing problems in code the PR touches.

## Step 7: Post to GitHub (only when asked)

If the user asks to post the review:

1. Show the exact text you'll post and confirm it first. Posting is public and notifies people.
2. For a summary review, write the body to a scratchpad file and run `gh pr review <n> --comment --body-file <file>`. Use `--request-changes` or `--approve` only if the user says to. Never approve on your own initiative.
3. For inline comments, use `gh api repos/{owner}/{repo}/pulls/<n>/comments -f body=… -f commit_id=<headRefOid> -f path=<path> -F line=<n> -f side=RIGHT`, one per finding.
4. Don't put a bare `@name` in posted text unless you mean to notify that person.

## Large PRs

If a PR changes more than about 1,000 lines or spans more than four areas, review it area by area and say so in the report. Don't spawn subagents on your own. You can offer a parallel review, split into intent and regressions, SwiftUI with accessibility and localization, concurrency with SwiftData, and tests with security. Start it only if the user agrees, and verify and merge their findings yourself before reporting.

## Credits

The checklists are an original synthesis, written for this project, of MIT-licensed skills listed in [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills):

- SwiftUI Pro, SwiftData Pro, Swift Concurrency Pro and Swift Testing Pro by Paul Hudson
- Review Swarm, Review and Simplify Changes, SwiftUI View Refactor, SwiftUI Performance Audit and Swift Concurrency Expert by Thomas Ricouard
- iOS Code Audit by Chad Etzel
- Swift Testing Expert and Swift Concurrency by Antoine van der Lee
- SwiftData Expert by Kudrin Dmitry
- Swift API Design Guidelines by Erik Sebastián de Erice
- Swift FormatStyle by Anton Novoselov
- iOS Accessibility by Daniel Devesa
- Swift Security Expert by Ivan Magda
- Swift Architecture by Lasha Efremidze
- Writing for Interfaces by Andrew Gleave
