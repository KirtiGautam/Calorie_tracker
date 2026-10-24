# Swift language review checklist

These rules apply to all Swift files. Report something only when it causes a real problem or breaks a project rule. Pure style preferences are at most Low.

## Safety and errors

- No `!` force unwraps, `try!` or `as!`. Use `guard let`, `if let x {`, `??`, `try #require` in tests, or a `fatalError("why")` that is truly unrecoverable.
- Errors from user actions must not be swallowed. Look for `try?`, empty `catch {}`, `catch { print(error) }`, and `Task { try await … }` without a catch. They map through `userMessage(for:)` to UI.
- Use typed `throws(SomeError)` only where callers really switch on the cases.
- `fatalError` and `precondition` belong only on invariants that genuinely can't happen at runtime. Network or user input is never one of those.

## Modern idioms (usually Low, Medium when the old form is buggy)

- `Date.now`, not `Date()`.
- `count(where:)`, not `filter { … }.count`.
- `replacing(_:with:)`, not `replacingOccurrences`.
- `URL.documentsDirectory` and `appending(path:)`.
- `if let value {` shorthand. Omit `return` in single-expression bodies. `if` and `switch` work as expressions.
- `Double`, not `CGFloat`, unless an API needs `CGFloat`.
- Static member lookup: `.circle`, `.borderedProminent`.
- Make a type `Comparable` when the same sort closure repeats.
- User-text filtering uses `localizedStandardContains()`, not `contains()`, `lowercased()` or `localizedCaseInsensitiveContains()`. This matters for food search.
- `String(localized:)` outside SwiftUI, never `NSLocalizedString`. In this project, prefer `LocalizedStringResource`.
- Parse dates with `Date(_:strategy:)`, for example `.iso8601`.

## FormatStyle (Medium: legacy formatters break localization)

- Never use `String(format: "%.1f", …)`, `NumberFormatter`, `DateFormatter`, `MeasurementFormatter`, `DateComponentsFormatter` or `RelativeDateTimeFormatter` for display.
- In SwiftUI, use `Text(value, format: …)`, not `Text("\(value.formatted())")` and not `specifier:`.
- Choose styles for the nutrition domain:
  - Grams: `.number.precision(.fractionLength(0...1))`.
  - Energy and mass: `Measurement` with `.measurement(width:usage:)` when the units follow the user's locale.
  - Percentages: `.percent`.
  - Dates: `.dateTime.weekday().day().month()` and so on.
  - Relative days: `.relative(presentation:)`.
  - Lists: `.list(type: .and)`.
- Don't set the locale explicitly unless a fixed locale is the point. Use `.verbatim` only with an explicit locale, and only for fixed machine formats. Use `.iso8601` for interchange.
- Rounding: totals should come from unrounded values, rounding only for display. Rounding each entry and then summing drifts.

## API design (Swift API Design Guidelines)

- Names are clear at the call site. Include the words needed to remove ambiguity and drop words that repeat the type. Name parameters by role, not type.
- Side-effect-free functions read as nouns (`totals(for:)`). Mutating ones read as verbs (`log(_:)`). Mutating and non-mutating pairs are consistent (`sort` and `sorted`). Booleans read as assertions (`isEmpty`, `hasReachedTarget`).
- Factory methods start with `make` (this matches `AppDependencies.make…ViewModel`).
- Labels: omit the first label when the call reads as a grammatical phrase or is a value-preserving conversion. Use a preposition label when the first argument completes a prepositional phrase. Label everything else. Put defaulted parameters at the end.
- Casing: `URL`, `id`, `usdaClient`, `USDAClient`. Acronyms are all-caps except at the start of a lowerCamel name.
- Avoid overloads that differ only by return type, or that are ambiguous with `Any` or literals.
- `///` summaries say what a function does and returns, what an initializer creates, and what a property is. Use `- Parameter`, `- Returns` and `- Throws` where they help. Document complexity for non-O(1) computed properties.

## Types and structure

- One top-level type per file, named after the type.
- Prefer value types. Use a class only for identity or shared mutable state, such as `@Observable` view models and stores.
- Domain types are `nonisolated` structs and enums, `Sendable` and `Equatable` where it makes sense. `Equatable` also lets Observation skip no-op updates.
- Avoid stringly-typed values where an enum or existing constant exists (nutrient keys, `UserDefaults` keys, source identifiers).
- Look for duplicated logic the PR re-implements when a helper already exists (`NutrientProfile`, `DailyTotals`, `TargetCalculator`, `URLComponents.setStrictlyEncodedQueryItems`). Search before flagging.
- Look for dead code: unused parameters, unreachable branches, commented-out code, leftover `print` debugging.
