# AGENTS.md

Guidance for AI coding agents working in this repository. Read [README.md](README.md) for what the app does and [SKILL.md](SKILL.md) for the full Swift, SwiftUI, SwiftData and testing guidelines. When this file and SKILL.md disagree, this file wins.

## Project at a glance

- **App:** Gramwise, a calorie and macro tracker. The Xcode project, targets and module are still named `CalTracker`, and the bundle ID is `com.kirti.CalTracker`. Don't rename them unless asked.
- **Platforms:** iOS and iPadOS 27.0, iPhone and iPad (including iPhone Duo and resizable windows). Don't change the deployment target.
- **Toolchain:** Xcode 27.1, Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency on.
- **Dependencies:** none. Don't add any third-party package without asking.
- **Project file:** the targets use file system synchronized groups, so new files under `CalTracker/`, `CalTrackerTests/` or `CalTrackerUITests/` are picked up automatically. Don't add file references to `project.pbxproj` by hand.

## Commands

Build:

```sh
xcodebuild build -project CalTracker.xcodeproj -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo'
```

Unit tests (fast, offline, run these after every change):

```sh
NSUnbufferedIO=YES xcodebuild test -project CalTracker.xcodeproj -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -only-testing:CalTrackerTests -collect-test-diagnostics never
```

UI tests (slow, hit the live USDA and Open Food Facts APIs):

```sh
NSUnbufferedIO=YES xcodebuild test -project CalTracker.xcodeproj -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -only-testing:CalTrackerUITests -collect-test-diagnostics never
```

**Always pass `-collect-test-diagnostics never`.** Without it, a run with a failing test can hang and never exit.

If `iPhone Duo` isn't installed, pick another simulator from `xcrun simctl list devices available`. If the Xcode MCP tools are available, prefer them for builds, test runs, previews and documentation lookups.

## Architecture

- `App/`: `CalTrackerApp` is the entry point. `AppDependencies` is the composition root. It owns the services and has `make…ViewModel` factories, and it's passed down through the `\.dependencies` environment key. `AppModelContainer` builds the SwiftData container.
- `Domain/`: plain `nonisolated` value types and pure logic (`Nutrient`, `NutrientProfile`, `DailyTotals`, `TargetCalculator`, and so on). No SwiftUI, SwiftData or networking here.
- `Data/`: anything that talks to the outside world.
  - `Networking/HTTPClient` is a one-method protocol that `URLSession` conforms to. Clients take it as a dependency so tests can inject `MockHTTPClient`.
  - `USDA/` and `OpenFoodFacts/` each have a client, response DTOs and a mapper that turns DTOs into `FoodItem`.
  - `Search/CombinedFoodSearch` queries both sources in a task group and keeps each source's `Result`, so one failing source never hides the other.
  - `Persistence/` is SwiftData with a versioned schema (`SchemaV1`) and `CalTrackerMigrationPlan`. `FoodLogging` is the protocol view models write through. `FoodLogStore` is the real implementation.
  - `Targets/TargetsStore` keeps targets, body profile and goal in `UserDefaults` as JSON under the `targets.*` keys.
- `Features/`: one folder per screen. Each has a SwiftUI view plus an `@Observable` view model, and small subviews get their own files. `TodayView` owns the navigation path and all sheets.

## Conventions

- **One type per file**, named after the type. Folders are organized by feature, and the test target mirrors the app's folders.
- **Doc comments** (`///`) on every type and member, written in plain sentences. Add inline comments only where the reasoning isn't obvious. Match the density of the surrounding code.
- **No force unwraps or force `try`.** Use `fatalError` with a clear message only for truly unrecoverable states (see `AppModelContainer`).
- **Errors from user actions must reach the user.** Map them through `userMessage(for:)` and show an alert or inline message. Never just `print` them.
- **Localization:** every user-facing string lives in `Resources/Localizable.xcstrings` with `extractionState: manual` and a translator comment. Views use the generated symbols (`Text(.todayTitle)`, `Button(.addFood, …)`), not string literals. For placeholders, use positional specifiers (`%1$@`) and describe each one in the comment.
- **Formatting:** use `FormatStyle` APIs, never legacy formatters.
- **Accessibility:** support Dynamic Type, VoiceOver labels and Reduce Motion (see `TodayView` for the pattern).
- **Branding:** the app icon and launch screen assets are in `Resources/Assets.xcassets`. The display name is `Gramwise`, set through `INFOPLIST_KEY_CFBundleDisplayName` in the project.

## Testing rules

- New unit tests use **Swift Testing** (`@Test`, `#expect`, `try #require`) in structs. XCTest is only for UI tests.
- **Never make live network calls in unit tests.** Use `MockHTTPClient` with the JSON in `CalTrackerTests/Fixtures/` and load it with `FixtureLoader`.
- SwiftData tests use a fresh in-memory container per test via `AppModelContainer.make(inMemory: true)`. In-memory containers skip the migration plan on purpose, because it can make `save()` fail at random.
- `UserDefaults` tests use `IsolatedDefaults` so parallel tests don't share state.
- Test doubles and fixtures live in `CalTrackerTests/Support/` (`SpyFoodLogging`, `StubFoodSearchProvider`, `FoodItem+Fixture`). Reuse them before writing new ones.
- Tag tests with `.networking` or `.persistence` from `Support/Tags.swift` where they apply.
- Test view models directly. Don't test SwiftUI views.
- UI tests reset state with launch arguments (for example `-targets.daily ""` clears saved targets).

## Secrets

- The USDA key comes from `USDA_API_KEY` in `Config/Base.xcconfig`, which defaults to `DEMO_KEY`. It can be overridden in `Config/Secrets.xcconfig`, which is gitignored, and reaches the app through `Info.plist` as `USDAAPIKey`.
- Never commit `Config/Secrets.xcconfig` or write a real key into any tracked file.

## Git

- Commit only when asked.
- Keep commit messages plain: a short summary line and an optional body. Don't add `Co-Authored-By` or other attribution trailers.
- `build/` and `DerivedData/` are gitignored. Don't commit build output.
