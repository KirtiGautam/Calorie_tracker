# Gramwise project rules

These come from `AGENTS.md` and the code as it stands. They override the generic checklists. Load this file for every review.

## Hard "don'ts" (High when broken)

- **No new dependencies.** Look for `XCRemoteSwiftPackageReference`, `XCSwiftPackageProductDependency` or a `Package.resolved` in the diff. Adding a package needs the owner's approval, and that should be stated in the PR.
- **Deployment target stays at 27.0.** Any change to `IPHONEOS_DEPLOYMENT_TARGET` is a finding.
- **Names stay put.** The project, targets and module stay `CalTracker`, and the bundle ID stays `com.kirti.Gramwise`. The display name `Gramwise` comes from `INFOPLIST_KEY_CFBundleDisplayName`.
- **Don't hand-edit `project.pbxproj` to add files.** The targets use file system synchronized groups, so new `PBXFileReference` or `PBXBuildFile` entries for sources under `CalTracker/`, `CalTrackerTests/` or `CalTrackerUITests/` are wrong. Build setting changes can be legitimate, but they need a reason.
- **No secrets in tracked files.** `Config/Secrets.xcconfig` must never appear in the diff. A real USDA key must never appear anywhere. `DEMO_KEY` in `Base.xcconfig` is fine. (A secret is Critical.)
- **No build output.** Nothing under `build/` or `DerivedData/`.
- **Plain commit messages.** A short summary line and an optional body. No `Co-Authored-By` or other attribution trailers. Check them with `gh pr view <n> --json commits`. This is Low unless the PR is about to be squash-merged with those lines.

## Architecture boundaries

- **`Domain/`** holds plain `nonisolated` value types and pure logic. It must not import or reference SwiftUI, SwiftData, URLSession or networking. A new Domain type that isn't `nonisolated` (or that is a class) is a finding.
- **`Data/`** is the only layer that talks to the outside world.
  - Clients take an `HTTPClient` dependency. They never use `URLSession.shared` or construct a `URLSession` directly, because then tests can't inject `MockHTTPClient`.
  - Each source has a client, response DTOs, and a mapper that turns DTOs into `FoodItem`. Mapping logic belongs in the mapper, not in the client or the view model.
  - Query strings go through `URLComponents.setStrictlyEncodedQueryItems(_:)`. Plain `queryItems` leaves `(`, `)` and `+` raw, USDA rejects raw parentheses, and servers read `+` as a space. Never build URLs by string interpolation. USDA search criteria go in the POST body.
  - `CombinedFoodSearch` keeps each source's `Result` separately, so one failing source never hides the other. Any change that makes one failure fail the whole search (`withThrowingTaskGroup` without per-child catching, an early `throw`, or `try` on the combined result) is a High regression.
  - Persistence goes through the `FoodLogging` protocol, implemented by `FoodLogStore`. View models must not touch `ModelContext` directly.
  - `TargetsStore` keeps targets, body profile and goal in `UserDefaults` as JSON under `targets.*` keys. New keys use that prefix. Renaming a key or changing the shape of its JSON silently resets users' saved targets unless there's a fallback decode. Treat that as data loss.
- **`App/`.** `AppDependencies` is the composition root. New services are owned there, and screens get their view models from `make…ViewModel` factories. Dependencies flow through the `\.dependencies` environment key, never through singletons or `static let shared`.
- **`Features/`** has one folder per screen, each with a SwiftUI view and an `@Observable` view model. Small subviews get their own files. `TodayView` owns the navigation path and all sheets, so new destinations and sheets should be registered there and not scattered through child views.

## Code conventions (usually Medium)

- **One type per file**, named after the type. Look for files that declare more than one top-level `struct`, `class`, `enum`, `actor` or `protocol`. Small `private` helper types are a judgment call.
- **Doc comments** (`///`) on every type and member, in plain sentences. Inline comments only where the reasoning isn't obvious. New public or internal members without `///` are a finding, and so are comments that just restate the code.
- **No force unwraps, `try!` or `as!`.** Use `fatalError("clear reason")` only for truly unrecoverable states, as `AppModelContainer` does.
- **Errors from user actions must reach the user.** Map them through `userMessage(for:)` (in `Data/Networking/UserMessage.swift`, returns a `LocalizedStringResource`) and show an alert or inline message. `print(error)`, an empty `catch {}` or `try?` on a user-initiated action is High. Ignore `CancellationError` rather than alerting it.
- **Localization:**
  - Every user-facing string lives in `Resources/Localizable.xcstrings` with `"extractionState" : "manual"` and a translator `comment`.
  - Views use the generated symbols: `Text(.todayTitle)`, `Button(.addFood, …)`. String literals (`Text("Add")`) are wrong outside `#Preview`, and so is `Text(someString)` for UI copy.
  - Placeholders use positional specifiers (`%1$@`, `%2$lld`), and the comment describes each one.
  - Every new symbol used in Swift must have a catalog entry in the same diff, and keys the PR stops using should be removed.
  - Non-view types that carry UI text use `LocalizedStringResource`.
- **Formatting** uses `FormatStyle` (`Text(value, format: …)`, `.formatted(…)`). Never `NumberFormatter`, `DateFormatter` or `String(format:)`.
- **Accessibility:** Dynamic Type, VoiceOver labels and Reduce Motion are all supported. `TodayView` shows the pattern. See `swiftui.md`.

## Testing rules (details in `testing.md`)

- New unit tests use Swift Testing (`@Test`, `#expect`, `try #require`) in structs. XCTest is only for `CalTrackerUITests`.
- No live network in unit tests. Use `MockHTTPClient` with JSON in `CalTrackerTests/Fixtures/`, loaded with `FixtureLoader`.
- Give each SwiftData test a fresh in-memory container from `AppModelContainer.make(inMemory: true)`. In-memory containers skip the migration plan on purpose, because it can make `save()` fail at random. Don't "fix" that.
- `UserDefaults` tests use `IsolatedDefaults`.
- Reuse what's in `CalTrackerTests/Support/` (`SpyFoodLogging`, `StubFoodSearchProvider`, `FoodItem+Fixture`, `ExpectApproximately`, `Loadable+Testing`) before adding new doubles.
- Tag tests with `.networking` or `.persistence` from `Support/Tags.swift` where they apply.
- The test target mirrors the app's folder structure.
- Test view models directly, never SwiftUI views.
- UI tests reset state with launch arguments (for example `-targets.daily ""`).
