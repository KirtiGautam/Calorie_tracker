# Testing review checklist

`CalTrackerTests` uses Swift Testing only. `CalTrackerUITests` uses XCTest only, because Swift Testing doesn't support UI tests.

## Coverage expectations

- New or changed logic in `Domain/`, `Data/` (clients, mappers, stores, `CombinedFoodSearch`) and view models needs tests. Missing tests for non-trivial logic is Medium. If the logic involves money-like totals, calorie and macro maths, migrations or deletes, it's High.
- For each changed function, look for a happy path, boundaries (0, 1, many; empty query; missing nutrients; zero or huge serving size), invalid input or error, and concurrency if relevant.
- A bug fix includes a test that fails without the fix. Use `.bug("…")` if there's an issue link.
- Mapper changes come with a fixture in `CalTrackerTests/Fixtures/`, loaded with `FixtureLoader`, that has the new shape. That includes missing or null fields from Open Food Facts, which is user-generated and messy.
- Test view models directly. Don't test SwiftUI views.

## Swift Testing rules

- Suites are `struct`s, not classes inheriting from `XCTestCase`. Don't add `@Suite` unless it carries a name or traits.
- Put setup in `init()`, not `setUp()`. Test names don't need a `test` prefix.
- Every test must pass in any order and in parallel. Shared mutable state, `UserDefaults.standard`, real files and singletons are findings.
- Use `try #require(…)` for preconditions and unwrapping, and `#expect` for the assertions that matter. Don't force-unwrap in tests.
- Don't negate inside the macro: `#expect(!x)` gives a poor failure message. Write `#expect(x == false)`.
- `#expect(throws: SpecificError.self)` or a specific case. Never `Error.self`. The macro returns the error for further checks.
- Use parameterized `@Test(arguments:)` instead of copy-pasted tests. Two argument collections form a Cartesian product, so use `zip` to pair them.
- `.serialized` only affects parameterized tests. Applying it elsewhere does nothing, so it doesn't fix shared state.
- `.timeLimit` takes `.minutes`, never `.seconds`.
- Floating-point checks use a tolerance. Use the project's `ExpectApproximately` helper, and don't add Swift Numerics.
- Put `@available` on individual tests, never on suites.
- `withKnownIssue` is for known bugs. A test disabled with no reason is a finding.
- Verification helpers take `sourceLocation: SourceLocation = #_sourceLocation` and pass it to every `#expect` and `#require`.
- Don't import `Testing` into the app target.

## Project-specific rules

- Never make live network calls. Use `MockHTTPClient` with fixture JSON. A real `URLSession`, or a client built without an injected `HTTPClient`, is High.
- Each SwiftData test gets a fresh in-memory container from `AppModelContainer.make(inMemory: true)`. Don't route tests through the migration plan.
- `UserDefaults` tests use `IsolatedDefaults`, never `.standard`.
- Reuse `SpyFoodLogging`, `StubFoodSearchProvider`, `FoodItem+Fixture` and `Loadable+Testing` before writing new doubles. When a protocol changes, its doubles must change in the same PR.
- Tag tests `.networking` or `.persistence` from `Support/Tags.swift`.
- Test files mirror the app's folders. For example, `CalTracker/Data/USDA/USDAMapper.swift` is tested in `CalTrackerTests/Data/USDA/USDAMapperTests.swift`.

## Async tests

- Mark the test `async` and `await` the real operation. Never wait with `Task.sleep`, `Thread.sleep` or fixed delays, because those tests are flaky.
- With `confirmation()`, all the confirmed work must finish before the closure returns. A fire-and-forget `Task` inside production code makes such a test pass or fail at random.
- Bridge callback-based code with `withCheckedContinuation`.

## UI tests

- They reset state with launch arguments (for example `-targets.daily ""`), not by relying on a previous run.
- They hit live APIs, so they must handle slow responses with `waitForExistence(timeout:)`, not sleeps.
- Look up elements by accessibility identifier or localized label, not by index.
