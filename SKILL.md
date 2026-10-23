---
name: swift-apple-platforms-expert
description: Consolidated expert guidance for writing, reviewing, and fixing Swift / SwiftUI / SwiftData / Swift Concurrency / Swift Testing code on Apple platforms, plus accessibility, widgets, App Intents, background execution, observability, security, and App Store submission. Distilled from the skills catalogued in twostraws/Swift-Agent-Skills. Use whenever creating or modifying Swift code, SwiftUI views, persistence, tests, or preparing an iOS release.
---

# Swift & Apple Platforms Expert

Distilled from the skills listed in [twostraws/Swift-Agent-Skills](https://github.com/twostraws/Swift-Agent-Skills/blob/main/README.md) (read 2026-10-23). The "Pro" skills by Paul Hudson are the backbone. Community skills add domain depth. A source index is at the end.

---

## 0. Operating Principles (shared by almost every skill)

1. **Report only real problems.** Don't nitpick, and don't invent issues. Compiling is not proof of correctness, because some SwiftData predicates and concurrency patterns compile but crash at runtime.
2. **Check the deployment target first.** Don't change it. Use newer APIs only when the target supports them or behind `if #available`, with an older-system fallback.
3. **Stay in scope.** When fixing a bug or building a feature, do the requested change. Suggest unrelated modernization separately and don't apply it unless asked. Don't restructure existing tests, convert XCTest suites, or modernize completion handlers without permission.
4. **Baselines:** Swift 6.2+ (SwiftUI Pro targets 6.4), strict concurrency, `async`/`await`, and SwiftUI with `@Observable`. Avoid UIKit unless requested.
5. **No new third-party dependencies without asking.** This includes concurrency libraries, image caches, and Swift Numerics.
6. **Project hygiene:** put one type per file, organize folders by feature, use strict naming, and never commit secrets. If SwiftLint is configured, it must report zero warnings and zero errors. Add comments where logic isn't self-evident.
7. **Treat the installed toolchain as the authority.** Apple docs can be stale. If the Xcode MCP is available, prefer its tools: `DocumentationSearch`, build, build logs, `RenderPreview`, and issue checks.
8. **Load references progressively.** For a partial task, apply only the relevant section.
9. **Verify.** Build, then run tests. Concurrency fixes can break at runtime even when the build is clean, so re-triage any new warnings.

### Review output format (common contract)
- Group findings by file. Give the file and line, name the rule violated, and show a brief **before/after** fix.
- Skip files with no issues.
- End with a **prioritized summary** of the highest-impact fixes.
- For "write" or "improve" requests, make the changes directly instead of producing a report.
- Severity, when used: **Critical** = crash, data loss, memory corruption, or security exposure (spot-verify by reopening the cited line). **High** = correctness or security weakening. **Medium** = reliability, testability, or auditability.

---

## 1. Swift Language

### Modern idioms
- Use `replacing(_:with:)`, not `replacingOccurrences`. Use `URL.documentsDirectory` and `appending(path:)`.
- Use `Date.now`, not `Date()`. Use `count(where:)`, not `filter{}.count`.
- Use `if let value {` shorthand. Omit `return` in single-expression bodies. Use `if` and `switch` as expressions.
- Prefer implicit static members (`.rect(cornerRadius:)`, `.borderedProminent`).
- Prefer `Double` over `CGFloat`, except where an API requires `CGFloat` (optionals, `inout`, generic containers).
- Make a type `Comparable` if it is repeatedly sorted with the same closure.
- Never force-unwrap or force-`try`. Use `if let`, `guard let`, `??`, `try?`, or `do/catch`. Use `fatalError("clear message")` only for truly unrecoverable states.
- Never silently swallow errors from user actions, such as only `print`ing them. Surface them to the user.
- Filter user-input text with `localizedStandardContains()`.
- Don't add `import UIKit` or `import AppKit` alongside `import SwiftUI` just for `UIImage` or `NSImage`.
- Outside SwiftUI, use `String(localized:)`, not `NSLocalizedString`.
- Format people's names with `PersonNameComponents` and `.formatted()`. Format display lists with `.formatted(.list(type: .or))`. Keep `joined(separator:)` for storage and interchange.
- Parse dates with strategy-based `Date` initializers (e.g. ISO 8601). For user-visible `DateFormatter`, use `setLocalizedDateFormatFromTemplate()` and `y` for years. Fixed API formats are exempt.

### API design (Swift API Design Guidelines)
- Prioritize **clarity at the point of use** over brevity. Design from call-site examples first.
- Include every word needed to avoid ambiguity. Omit words that repeat type information. Name things by **role**, not type. Add a role noun when the type is weak (`Any`, `String`, `Int`).
- Name side-effect-free APIs as nouns or queries and side-effecting APIs as imperative verbs. Booleans read as assertions (`isEmpty`, `intersects(_:)`).
- Keep mutating and nonmutating pairs consistent: `sort`/`sorted`, `reverse`/`reversed`, `formUnion`/`union`, `stripNewlines`/`strippingNewlines`. Factories start with `make`.
- **Labels:** omit the first label for value-preserving conversion initializers. A prepositional phrase usually labels with the preposition. Omit the label when the first argument forms a grammatical phrase. Keep labels on defaulted args. Label everything else.
- Prefer default args over method families, and put defaulted params at the end. Label tuple members and name closure params in public APIs. Avoid overloads that differ only by return type or by weak types.
- Every declaration gets a doc comment summarizing what it does or returns (function), accesses (subscript), creates (init), or is (other). Use `- Parameter`, `- Returns`, `- Throws`, and `- Note`. Document complexity for non-O(1) computed properties.
- Avoid nonstandard abbreviations. Keep terms of art at their established meaning. Follow Swift casing for acronyms.

### Formatting (FormatStyle). Never use legacy formatters
- **Banned:** `DateFormatter`, `NumberFormatter`, `MeasurementFormatter`, `DateComponentsFormatter`, `DateIntervalFormatter`, `PersonNameComponentsFormatter`, `ByteCountFormatter`, `String(format:)`, and C-style printf for numbers.
- Use `.formatted()` for simple cases and explicit FormatStyle values for reused or complex ones. They are value types, thread-safe, `Codable`, and `Hashable`, so there's no need to `DispatchQueue` the formatting.
- `String(format: "%02d:%02d", m, s)` → `Duration.seconds(x).formatted(.time(pattern: .minuteSecond))` (iOS 16+).
- SwiftUI: `Text(value, format: .currency(code: "USD"))`, not `Text("\(value.formatted())")`.
- Use `Decimal` for money, never `Float` or `Double`.
- Styles are locale-aware by default. Set a locale only when you need a specific different one.
- For years and IDs, avoid grouping ("2,026"). Use `String(year)` or `.number.grouping(.never)`.
- Availability: basic FormatStyle needs iOS 15. Duration and URL styles need iOS 16.

---

## 2. SwiftUI

### 2.1 Deprecated / soft-deprecated API map (always flag)
Soft-deprecated APIs (`deprecated: 100000.0`) produce **no** Xcode warning, so review the source.

| Old | New |
|---|---|
| `foregroundColor()` | `foregroundStyle()` |
| `accentColor()` | `tint()` (app-wide: the asset catalog AccentColor) |
| `cornerRadius()` | `clipShape(.rect(cornerRadius:))` |
| `tabItem()` | `Tab` API |
| 1-param `onChange { newValue in }` | 0- or 2-param variant |
| `colorScheme()` | `.environment(\.colorScheme, .light)` (not `preferredColorScheme`) |
| `autocapitalization()` / `disableAutocorrection()` | `textInputAutocapitalization()` / `autocorrectionDisabled()` |
| `coordinateSpace(name:)` | `.coordinateSpace(.named("x"))` |
| `Color.cgColor` | `color.resolve(in:)` (cgColor is nil for dynamic colors) |
| `overlay(view)`, `background(view)`, `mask(view)` | trailing builder closure |
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `NavigationLink(destination:)` | `navigationDestination(for:)` |
| `PreviewProvider` | `#Preview` |
| `ScrollView(showsIndicators: false)` | `.scrollIndicators(.hidden)` |
| `ScrollViewReader` | `ScrollPosition` / `defaultScrollAnchor` |
| `GeometryReader` (when avoidable) | `containerRelativeFrame()`, `visualEffect()`, `Layout` |
| `UIScreen.main` | environment / container sizing (deprecated iOS 26) |
| `Image("avatar")` | `Image(.avatar)` (generated asset symbols) |
| `UIGraphicsImageRenderer` | `ImageRenderer` |
| `UIImpactFeedbackGenerator` etc. | `sensoryFeedback()` |
| `toolbar(_:for:)` visibility / `navigationBarHidden()` | `toolbarVisibility()` |
| `toolbarBackground(_:for:)` visibility | `toolbarBackgroundVisibility()` |
| `.navigationBarLeading/Trailing` | `.cancellationAction` / `.confirmationAction` / `.primaryAction`, else `.topBarLeading/Trailing` |
| `statusBarHidden()` (iOS 27+) | `toolbarVisibility(_:for: .statusBar)` |
| `sizeCategory` / `ContentSizeCategory` | `@Environment(\.dynamicTypeSize)` and `.isAccessibilitySize` |
| `AnimatableModifier` / manual `animatableData` | `@Animatable` macro and `@AnimatableIgnored` |
| `.animation(_:)` without value | `.animation(.bouncy, value: x)` |
| `Task.sleep(nanoseconds:)` | `Task.sleep(for:)` |
| manual `EnvironmentKey` | `@Entry` (for EnvironmentValues, FocusedValues, Transaction, ContainerValues) |
| wrapped `WKWebView` (iOS 26+) | native `WebView` |
| `Text("a" + b)` / `Text + Text` | interpolation: `Text("Folder: \(name)")`, `Text("\(red)\(blue)")` |
| `@ViewBuilder` (new code, Xcode 27+) | `@ContentBuilder` (existing uses are fine, not findings) |

- **`ForEach` with `enumerated()`:** on iOS 26+, use `ForEach(items.enumerated(), id: \.element.id)`. On earlier targets, wrap it in `Array(...)`.
- **`@Entry` defaults must be stable.** Never use `UUID()`, `.now`, or `Store()` as the default. Use an optional or a `static let` shared value.
- **Custom environment actions:** use a struct or `@Observable` holding data plus a method (`callAsFunction`), not stored closures.
- `ObservableObject`, when unavoidable, needs an explicit `import Combine`.
- Use automatic grammar agreement: `Text("^[\(n) person](inflect: true)")`.

### 2.2 Views
- **Extract subviews into separate `View` structs**, one per file. Don't build screens out of computed `some View` properties or methods. Small private helpers are OK if they serve the same concern and would fit inline. Flag overly long `body` (more than about a screen, or files over 300 lines).
- Keep logic out of `body`, `task()`, and `onAppear()`. Move button actions into methods. Put testable logic in models or view models. Pass actions directly: `Button("Save", action: save)`.
- **Stable view tree:** don't swap root branches with `if/else`. Put conditions in modifiers (`opacity`, `disabled`, `overlay`). Never write a `View.if()` helper, because it changes identity, resets state, and breaks animation. If ternary styles have mismatched types, use `AnyShapeStyle`.
- Avoid `AnyView`. Use generics, `Group`, an extracted struct, or a builder param.
- Remove a `Group` that wraps a single view. In `List` rows with conditional content, use `VStack`, not `Group`.
- Use `TextField(axis: .vertical)` with `lineLimit(5...)` instead of `TextEditor`, unless it's a full-screen editor.
- `TabView(selection:)` binds to an **enum**, not an Int or String.
- Use `Button` instead of `onTapGesture` unless you need location or count. If you use `onTapGesture`, add `.accessibilityAddTraits(.isButton)`.
- Chain animations with the `withAnimation { } completion: { }` closure, not delayed calls.
- **Reordering (iOS 27+):** `ForEach.reorderable()` + `reorderContainer(for:)`. Apply `ReorderDifference` to the data yourself. **Swipe actions outside List:** `swipeActions()` on rows **and** `swipeActionsContainer()` on the ScrollView (omitting the container silently disables them).
- **View file ordering:** Environment → `let`s → `@State` and stored → computed non-view vars → `init` → `body` → view helpers → functions.

### 2.3 Data flow & state
- Use `@Observable` classes for shared data, marked **`@MainActor`** (unless the module defaults to MainActor). Own them with `@State` and pass them with `@Bindable` or `@Environment`, or as a plain stored property.
- Avoid `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject`, except in legacy code or for iOS 16 or earlier targets.
- **Default to MV, not MVVM.** Use `@State`, `@Environment`, `@Query`, `.task(id:)`, and `onChange` before adding a view model. Don't create view models that just mirror state. If one exists, make it non-optional `@State`, created in `init`, with no `bootstrapIfNeeded` hacks.
- Declare `@State` as **`private`**, and initialize it in exactly one place: either the declaration or `init`, not both.
- Store expensive non-observable objects (such as `CIContext`) in `@State` as a cache.
- Keep window-specific state (tab, selection, path) in scene-root `@State` or `@SceneStorage`. Don't couple windows via `@AppStorage`, singletons, or shared models.
- Never put `@AppStorage` inside an `@Observable` class, because it won't trigger updates. Never store credentials in `@AppStorage`. Use the Keychain.
- Prefer projected bindings (`$model.name`, key paths) over `Binding(get:set:)`. Expose a writable computed property for conversions. Setters and `onChange` have different semantics, so don't swap one for the other blindly.
- Bind numeric `TextField`s to `Int` or `Double` with `format:`, and add `.keyboardType(.numberPad/.decimalPad)`.
- Make value types stored in observables `Equatable`, so equal writes don't notify. A stored struct counts as one dependency, and reading one field subscribes to all of them.
- **Identity:** conform to `Identifiable`. Don't use indices, offsets, `id: \.self` on whole structs, editable fields, or fresh `UUID()`s generated in `body`. Use `id: \.self` only for small unique values (Int, UUID, URL, short strings).
- **State ownership:** local UI uses `@State`. A child mutating a parent value uses `@Binding`. A root reference model uses `@State` with `@Observable`. Shared services use `@Environment(Type.self)`. Feature-local dependencies use explicit init injection.

### 2.4 Navigation & presentation
- Use `NavigationStack` or `NavigationSplitView` with `navigationDestination(for:)`. Never mix it with `NavigationLink(destination:)` in the same hierarchy. Register each data type once per stack.
- Use enum-based routes and sheets rather than multiple Booleans for mutually exclusive presentations.
- Use `sheet(item:)` over `isPresented` for optional data. Use `sheet(item: $x, content: DetailView.init)` when possible. Sheets own their actions and call `dismiss()` themselves.
- Use `alert(_:item:)` and `confirmationDialog(_:item:)` (Xcode 27, back-deploys to iOS 15). An OK-only alert can have an empty actions closure.
- Attach `confirmationDialog` to the triggering control (for Liquid Glass source animation), except inside `ToolbarOverflowMenu`.
- **Toolbars:** use semantic placements. Use `ToolbarOverflowMenu` (iOS 27) instead of a custom ellipsis menu. Give single-purpose menus a descriptive SF Symbol. Set `visibilityPriority(.high/.low)`, and use `ToolbarItemGroup` for related items. Every tab and toolbar item needs **both a title and an icon**.

### 2.5 Design & HIG
- Keep a shared constants enum for fonts, spacing, radii, colors, and animation timings.
- **Restraint:** use fewer colors, sizes, spacing values, and words, and no decorative gradients or bespoke dividers.
- **Spacing grid:** 4, 8, 12, 16, 20, 24, 32, 40, 48. Use 16–20pt outer horizontal padding, 24–32pt between sections, 4–12pt within groups, and 12–16pt vertical by 16pt horizontal for rows. (Hudson: avoid hard-coded padding unless requested and prefer system defaults. Use the grid when explicit values are needed.)
- **Typography:** use Dynamic Type styles. Use 5 or fewer distinct sizes and build hierarchy through weight. Use `bold()`, not `fontWeight(.bold)`. Avoid `.caption2`, and use `.caption` sparingly. Use one font design app-wide, widgets included. Use at most 2 tracking values, only on uppercase labels.
- **Color:** use semantic colors (`.primary`, `.secondary`, `.tertiary`, `Color(.secondarySystemBackground)`, `Color(.separator)`) and hierarchical styles, not manual opacity. Don't use `UIColor`.
- **Cards:** `secondarySystemBackground`, a 10pt radius, and system `Divider().padding(.leading, 16)`. `RoundedRectangle` is continuous by default. On iOS 26+, use `ConcentricRectangle()` next to screen or sheet edges.
- Use `ContentUnavailableView` (and `.search` with `searchable`), `Label` for icon+text, and `LabeledContent` (also in `Form` for Sliders).
- **Touch targets are at least 44×44pt**, strictly enforced.
- Use `.contentTransition(.numericText())` for changing numbers. Don't use `minimumScaleFactor` hacks. Fix the layout instead.
- Exclusive options use one enum selection, not several Toggles. Don't hide Toggle labels (`.labelsHidden()`).

### 2.6 Adaptive layout & resizability (iPad, iPhone Duo, iOS 27.x)
- Window size can change at any time. Decide layout by **size class** (`== .regular`, never `!= .compact`), not by idiom or orientation.
- Every feature must be reachable at every size. Don't gate features by size class.
- Use `ViewThatFits` and scrolling for "everything fits" screens (onboarding, purchase). Keep selection and path state **above** size-class branches.
- **Safe areas:** don't fake insets with padding. Use `ignoresSafeArea(edges:)` for interactive content and bare `ignoresSafeArea()` only for decoration. Attach custom bars with `safeAreaBar()` (iOS 26) or `safeAreaInset()`. Use `backgroundExtensionEffect()` for imagery behind sidebars.
- Prefer system `TabView`, toolbars, sheets with `presentationDetents`, popovers, and `inspector()`. Custom ZStack sheets don't adapt.
- iOS 27.1+ items (fold `reservedRegions`, `ArrangementView`, `toolbarVerticalEdge`, `presentationPlacement`) apply only when requested or when a concrete problem exists, always behind availability checks with fallbacks.
- Hygiene: report a missing launch-screen config (iOS 27 SDK builds are rejected without one). Flag `UIRequiresFullScreen`, which no longer prevents resizing. Don't fix project settings automatically.

### 2.7 Localization
- Use the project's existing workflow (`.strings` or `.xcstrings`). With generated symbols, add keys with `extractionState: "manual"` and use `Text(.symbolKey)`. Offer translations for every supported language.
- Use `LocalizedStringResource` for new properties that carry UI text. A runtime `String` passed to `Text` is not localized.
- In packages and frameworks, pass `bundle: #bundle`.
- Read locale, calendar, and time zone from `@Environment`, not `.current`.
- Add translator comments for ambiguous words and for every placeholder.

### 2.8 Performance
- Assume `body` runs often. Move sorting, filtering, and heavy transforms out of it. Keep `init` trivial and put work in `.task`.
- Use `Text(date, format:)` instead of stored formatters.
- Use `LazyVStack` or `LazyHStack` for large scroll content.
- Prefer `.task` to `onAppear` plus `Task`, since it auto-cancels.
- Pass rows their **element**, not store+ID. Create row models once. Each `ForEach` element should produce the same number and kind of top-level views. Filter before `ForEach` rather than using `if` inside it. Diagnose with the `-LogForEachSlowPath YES` launch argument.
- Keep rapidly changing values (scroll offset, drag, timers) out of the environment. Store them in an observable and expose derived low-frequency results. Use `scrollTransition` and `visualEffect` for scroll-driven visuals.
- Remove unused `@Environment` and `@FocusedValue` reads. Don't store escaping builder closures. Store the built view.
- `AsyncImage` on iOS 27 honors HTTP caching, so don't add a cache library.
- **Deep review only (when explicitly requested or measured):** split hot fields into separate stored properties or smaller observables, use per-row observables, cache computed values via `didSet`, and isolate `onChange`-only reads in a `ViewModifier`.
- **Audit flow:** classify the symptom → review code against smells (invalidation storms, unstable identity, heavy body work, layout thrash, main-thread image decode, broad animations) → profile with the Instruments SwiftUI template and Time Profiler → rank by impact → verify against a baseline. Use `equatable()` only when equality is cheaper than recompute. Downsample images.

---

## 3. Swift Concurrency

### Triage before any fix
1. Read build settings: language mode, `SWIFT_STRICT_CONCURRENCY`, **default isolation** (`SWIFT_DEFAULT_ACTOR_ISOLATION` or `.defaultIsolation(MainActor.self)`), upcoming features, and Approachable Concurrency. Settings are **per module**, so compare across targets. If they're unknown, ask.
2. Capture the exact diagnostic and symbol. Identify the isolation boundary and whether the code is UI-bound.
3. Apply the smallest behavior-preserving fix. Fix one error category at a time, then rebuild and test.

### Rules
- Prefer structured concurrency. Use `async let` for a fixed number of heterogeneous ops and task groups for a dynamic number of homogeneous ops. Use `withDiscardingTaskGroup` for side-effect-only children. **No `Task {}` in loops.**
- Limit group width manually: seed N tasks, then add one each time one finishes. When a child throws, siblings are cancelled. Return `Result` to keep partial results.
- **`Task.detached` is rarely right.** Use `@concurrent` (Swift 6.2) for CPU-heavy work instead. A plain `nonisolated async` func now **stays on the caller's actor**, so add `@concurrent` when offload is intended. Don't use `@concurrent` for ordinary I/O.
- `MainActor.run {}` is often redundant. Mark the function `@MainActor` instead.
- Don't use `@MainActor` as a blanket fix. Justify that the code is UI-bound. Don't annotate where isolation is inferred (subclasses, extensions, `View` conformances, `@MainActor` protocols).
- Prefer Swift concurrency over GCD in app code. GCD is acceptable for low-level, interop, or performance-critical synchronous code. Prefer async APIs over closure APIs.
- **Never use `@unchecked Sendable` to silence errors.** Use value types, actors, `sending`, or `Mutex`, and check whether region-based isolation already solves it. It's legitimate only for provably lock-protected types. `@preconcurrency`, `@unchecked Sendable`, and `nonisolated(unsafe)` require a documented invariant and a removal plan.
- Isolate conformances with `extension Foo: @MainActor SomeProtocol {}`.
- Give global and static mutable state `@MainActor`, an actor, or immutable `Sendable` types.
- Use `isolated deinit` when teardown touches actor state. `Task.immediate` is only for when the immediate start matters. Name tasks for diagnostics. Leave priority escalation to the runtime.
- Use `MainActor.assertIsolated()` (debug-only) in main-only code. Use `MainActor.assumeIsolated` only when the guarantee truly exists.
- Don't create actors that just forward work or own little state.

### Actor reentrancy
- State may change across **every `await`**. Never check, await, then force-unwrap. Capture results in locals.
- To deduplicate, cache in-flight `Task`s, check cache then in-flight, and clear the entry on success **and** failure.

### Cancellation
- Cancellation is cooperative. Use `try Task.checkCancellation()` in throwing code and `Task.isCancelled` in non-throwing code. Check periodically in CPU loops.
- Unstructured tasks need stored handles. Cancel the old task before replacing it, and cancel on teardown.
- Bridge legacy cancel APIs with `withTaskCancellationHandler`. `onCancel` can run on any thread.
- **Never treat `CancellationError` as a user error.** Catch it first, do nothing, then handle the rest. Don't alert or retry.
- Never discard errors from a throwing `Task`. Handle them inside the closure.

### Bridging & streams
- **Continuations resume exactly once on every path.** Zero resumes hangs, and two crashes. Default to the *checked* variants, even in production.
- Use `AsyncStream.makeStream(of:)`, not the closure initializer. `finish()` on every path. Use `onTermination` to stop the producer.
- Set a buffering policy (`.bufferingNewest(n)`) for fast producers. `for await` exits on cancel, and code after the loop still runs.
- **Migrations:** `DispatchQueue.main.async` → `@MainActor`. `global().async` → `@concurrent` or a task group. A serial queue protecting state → `actor`. Synchronous APIs that need locking → `Mutex`. `PassthroughSubject` → `AsyncStream`. Use a publisher's `.values` directly. Completion handler → `withCheckedThrowingContinuation`, or the SDK's async overload if one exists.

### Diagnostic quick fixes
- *"Sending 'x' risks causing data races"* → check region isolation, then `sending`, then make it `Sendable`, then `nonisolated(nonsending)`. `@unchecked` is the last resort.
- *"Static property not concurrency-safe"* → `@MainActor`, or an immutable `Sendable` type. Use `nonisolated(unsafe)` only for truly immutable C constants.
- *"Capture of non-sendable in @Sendable closure"* → make it Sendable, copy only the needed value (an `id`), or keep the closure on the caller's actor.
- *"Conformance crosses into main actor-isolated code"* → isolate the conformance, or remove unnecessary isolation.
- SwiftLint `async_without_await` → remove `async` or suppress narrowly. **Never add fake awaits.**
- Core Data warnings → pass `NSManagedObjectID`. `@Observable` errors → add `@MainActor` and pass Sendable snapshots.

---

## 4. SwiftData

### Core rules
- **Call `save()` explicitly** when correctness matters, because autosave is unpredictable. Don't pre-check `hasChanges`.
- Keep `ModelContext` and models on one actor. Cross boundaries with `PersistentIdentifier` (or the `ModelContainer`, which is Sendable) and re-fetch. Use `@ModelActor` for background work.
- IDs are **temporary until first save**.
- Put `@Relationship` on **one side only**, with an explicit `inverse:`. Set an explicit delete rule, usually `.cascade`, since the default `.nullify` can orphan rows or crash with non-optional properties.
- Don't name a property `description`. `willSet` and `didSet` are silently ignored on `@Model`.
- `@Attribute(.externalStorage)` is a hint, and only applies to `Data`. `@Transient` needs a default and resets on fetch, so prefer computed properties.
- Stored enums must be `Codable`. Associated values **are** supported.
- Use one `#Unique` per model, with multiple key-path arrays inside it.
- Always use a versioned schema and migration plan, even for lightweight changes. Rehearse migrations on existing data.
- Use `@Query` only in SwiftUI views. Use `fetchCount()` for counts (not live). Set `relationshipKeyPathsForPrefetching` and `propertiesToFetch`. Bound fetches with limits and offsets.
- **Indexes (iOS 18+):** `#Index<Article>([\.type], [\.type, \.author])`. Skip them for write-heavy, rarely-read data such as logs.
- **Inheritance (iOS 26+):** `@Model` on parent and child, `@available(iOS 26, *)` on children, all classes listed in the schema. Querying the base type returns its subclasses. Filter with `is` and `as` in `#Predicate`. Prefer protocols unless subclassing truly helps.

### Predicates (compile ≠ works)
- Use `localizedStandardContains()` and `starts(with:)`.
- **Won't compile:** `hasPrefix`, `hasSuffix`, `lowercased()`, `map`, `reduce`, `count(where:)`, `.first`, and custom operators.
- **Compile but crash at runtime:** `isEmpty == false` (use `!x.isEmpty`), computed properties, `@Transient` properties, custom Codable struct fields, and regex.
- Use only stored `@Model` data. Don't filter in memory when a store-backed predicate works.

### CloudKit
- No `@Attribute(.unique)` or `#Unique`, because they break local data too. Every property needs a default or is optional. **All relationships must be optional.**
- Design for eventual consistency. The production CloudKit schema is immutable.

### Debugging playbook
- Empty fetches usually mean the container isn't attached at the root or the model type is missing. Duplicates after a refresh need a unique constraint plus upsert. Unexpected deletes need a delete-rule audit.
- If widget or intent writes aren't seen, read persistent history with a token and author filter. Persist tokens and clean up history.

---

## 5. Core Data (when SwiftData can't do the job)
- Identify the view context (UI) versus a background context (heavy work). **Never pass `NSManagedObject` across contexts.** Pass `NSManagedObjectID`.
- Prefer lightweight migration. Use staged migration (iOS 17+) for complex changes.
- Batch insert, update, and delete need **persistent history tracking** plus a merge pipeline, or the UI won't update.
- Constraints need a defined merge policy. In tests, share one `NSManagedObjectModel`, which avoids "Failed to find a unique match for an NSEntityDescription".
- Profile with Instruments and use fetch batching and limits. Don't silence Sendable warnings with `@unchecked`.

---

## 6. Testing

### Swift Testing (all new unit and integration tests)
- Use XCTest **only** for UI tests (`XCUIApplication`), performance tests (`XCTMetric`), and Obj-C code. Never use `XCTestCase` or `XCTAssert*` in new unit tests. Import `Testing` only in test targets.
- Use **structs** for suites (classes only when you need `deinit` or subclassing). Use `init` and `deinit`, not setUp and tearDown. Suites need a zero-argument init. Add `@Suite` only to name it or attach traits. Drop the `test` prefix.
- Tests run in **random order, in parallel**, so fix shared state rather than reaching for `.serialized`. `.serialized` affects **only parameterized** tests.
- **Parameterized tests:** at most 2 argument collections, which form a Cartesian product. Use `zip()` to pair them.
- Use `#expect` for checks. Use `try #require` for preconditions and unwrapping (never `!`). Don't negate with `!` inside macros. Write `#expect(isLoggedIn == false)`.
- Use `#expect(throws: SpecificError.case)`, never `Error.self`, and `#expect(throws: Never.self)` for "doesn't throw". `#expect(throws:)` returns the error so you can validate it afterward. The `performing:throws:` forms are deprecated.
- Use `withKnownIssue` for known bugs and `isIntermittent: true` for flaky ones. Use the `.bug("id")` trait. Define tags with `extension Tag { @Tag static var networking: Self }`. Use `.networking` even for mocked networking, plus tags like `.slow`, `.edgeCase`, and `.smoke`.
- Put `@available` on individual tests, never on suites. Don't use runtime `#available` in test bodies.
- **Time limits:** `.timeLimit(.minutes(n))` (no `.seconds`). The shorter of the suite and test limits wins.
- **Async:** make the test `async`. No `Task {}`, semaphores, or sleeps. Use `confirmation()` with the work finishing inside the closure (it doesn't wait for completion handlers). Return a `Task` from production code if needed. `expectedCount: 0` asserts "never happens", and ranges like `5...` are allowed (`...10` is not). Wrap callbacks with `withCheckedContinuation`.
- **Isolation:** use `@MainActor` on tests or suites, or the `isolation:` parameter of `confirmation` and `withKnownIssue`. Check the test target's default isolation.
- **Newer features:** test scoping traits (`TestTrait` + `TestScoping` + `provideScope` with task-locals, Swift 6.1). Exit tests use `await #expect(processExitsWith:)`. Attachments use `Attachment.record`. `ConditionTrait.evaluate()`. Use raw identifiers only if the project already does.
- **Good tests:** follow F.I.R.S.T., use Arrange-Act-Assert, test one behavior each, and cover happy, boundary, and invalid cases. Add failure messages. Mirror the production folder structure. Use a Fixtures file or folder. Never test SwiftUI views directly. Test `@Observable` view models directly, without a protocol wrapper.
- **Dependencies:** inject with a default matching current behavior. Wrap them in minimal protocols. **Never make live network calls.** Have `URLSession` conform to a fetch protocol and mock it. Use a unique `UserDefaults` suite per test and remove it afterward. Control time and randomness.
- **Test doubles (Fowler):** Dummy, Fake, Stub, Spy, SpyingStub (what most people call a "mock"), and Mock. Prefer state verification. Fixtures use `static func fixture(...)` with deterministic defaults. (bocato places doubles and fixtures beside their interfaces under `#if DEBUG`.)
- Use `CustomTestStringConvertible` (with `@retroactive`) in the **test target only**. Verification helpers take `sourceLocation: SourceLocation = #_sourceLocation` and pass it to `#expect` and `#require`.
- **XCTest migration (only when asked):** class → struct, `testFoo` → `@Test func foo`. `XCTAssertEqual` → `#expect(a == b)`. `XCTUnwrap` → `try #require`. `XCTFail` → `Issue.record`. `XCTAssertIdentical` → `===`. Float tolerance uses Swift Numerics `isApproximatelyEqual`, and only if the package is already present. Use `await fulfillment(of:)` for legacy waits. Use TSan in a dedicated CI job.
- **Cancellation tests:** block the code under test, cancel it while suspended, and assert `CancellationError`. Don't add cancellation checks to the test itself.

### SwiftData testing
- Every test uses `ModelConfiguration(isStoredInMemoryOnly: true)` and a **fresh container per test**. Never share contexts.
- ViewModel tests use mock repositories, not a real container. If business logic needs a `ModelContainer`, flag that persistence isn't separated.
- Never pass `@Model` objects across actors in tests either.
- **Gotcha:** a `migrationPlan` on an in-memory config can make `save()` fail nondeterministically. Skip the plan when in memory, including in app-launch code used by UI tests.
- Use `Decimal` assertions for money. Test content-hash deduplication in import pipelines.

---

## 7. Accessibility
- Respect user settings: Dynamic Type (`@ScaledMetric`, or `.font(.body.scaled(by:))` on iOS 26), `dynamicTypeSize.isAccessibilitySize` for layout switches, Reduce Motion (swap motion for opacity), Differentiate Without Color (add icons or patterns), Increase Contrast, Reduce Transparency, and Bold Text.
- Every icon-only button or menu needs a text label (use `.labelStyle(.iconOnly)` to hide it visually). Decorative images use `Image(decorative:)` or `accessibilityHidden`. Meaningful images get `accessibilityLabel`.
- Add `accessibilityInputLabels` for Voice Control on complex labels. Group related elements, set traits, use custom actions, and keep reading order and focus sensible.
- Use a 44×44 minimum target and keep information multimodal (color, shape, text, haptics).
- **Audit approach:** prioritize user impact (P0/P1/P2), keep fixes minimal and local, don't change copy or layout unless needed, don't add modifiers blindly, mark inferred labels `[VERIFY]`, and always include **manual verification steps** (VoiceOver, Voice Control "Show names", Switch Control, Full Keyboard Access, Accessibility Inspector). Automation has limits.
- Map work to App Store **Accessibility Nutrition Labels** (VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color, Sufficient Contrast, Reduced Motion, Captions, Audio Descriptions) and to WCAG 2.2 where relevant.

### Focus (tvOS / macOS / iPadOS keyboard / visionOS)
- Focus is **geometric**, not hierarchical. Test it on hardware.
- tvOS: don't use `.disabled()`, because it removes the view from focus. Gate inside the action instead. Add `.focusSection()` to horizontal and vertical scroll rows. Never add `.focusable()` to Buttons or NavigationLinks. Don't `reloadData()` mid-animation. Don't allocate in focus callbacks.
- Set focus via `preferredFocusEnvironments`, then `setNeedsFocusUpdate()` and `updateFocusIfNeeded()` on the right environment. In SwiftUI, use `defaultFocus`. Use an optional enum `@FocusState` and advance with `onSubmit`.
- macOS: override `acceptsFirstResponder`, complete the key-view loop, use `window.makeFirstResponder`, restore focus after sheets close, and handle a nil `focusedValue` in menus.

---

## 8. Platform Features

### App Intents
- Never make a SwiftData `@Model` an `AppEntity` (it requires Sendable). Never use `@Query` in intents, because it silently does nothing. Don't create a `ModelContainer` in `perform()`. Inject a shared controller via `@Dependency` and `AppDependencyManager`.
- Every Siri phrase includes `\(.applicationName)`, or the build fails. Register every intent in `AppShortcutsProvider` (maximum 10 shortcuts, 1000 phrases). Set `shortcutTileColor`. Use `SiriTipView` and `ShortcutsLink`.
- Return the correct `IntentResult` type, because a mismatch crashes at runtime. Intents have about a 30-second budget, so use `LongRunningIntent` with progress for longer work. Snippets have a 340pt height ceiling.
- Use `TransientAppEntity` where appropriate, `EntityCollection` at scale, `valueState` instead of nil checks, and `requestConfirmation` and `requestChoice`. Call `WidgetCenter.reloadAllTimelines()` after writes. Prefer App Intents over SiriKit and `NSUserActivity`. Test with `AppIntentsTesting` and direct `perform()` unit tests.

### Widgets (WidgetKit)
- The extension is a **separate process**. Share data via an App Group, never `UserDefaults.standard`. The placeholder renders synchronously.
- Interactivity uses only `Button(intent:)` and `Toggle(intent:)`, not tap gestures or closures. Reload timelines after mutations.
- Respect the reload budget. Refresh at midnight for daily data, every 15 minutes for time-of-day data, and never every minute. Always use `containerBackground(.fill.tertiary, for: .widget)`, with no opaque background on accessory widgets.
- Design for full-color, accented/tinted, and vibrant modes (`widgetAccentable`). Use `Gauge` for rings and bars on the Lock Screen, not hand-drawn circles. Draw dense visuals with `Canvas` (about a 30 MB memory budget). Share models between the app and the widget.
- Avoid app names or icons, "last updated" text, and spinners. Use `widgetURL` versus `Link` per family. Use `#Preview(as:)`.

### Background execution
- Register `BGTaskScheduler` handlers **at launch** (not in views, never twice), list their identifiers in `BGTaskSchedulerPermittedIdentifiers`, always set an expiration handler, and **always call `setTaskCompleted`**.
- Balance `beginBackgroundTask` with `endBackgroundTask`. Background `URLSession` needs a delegate (no completion-handler or `dataTask` APIs), a single session per identifier, and the relaunch flow (`handleEventsForBackgroundURLSession`).
- Silent pushes need `apns-push-type: background` and priority 5, and they are not guaranteed. VoIP pushes must report to CallKit. `allowsBackgroundLocationUpdates` without the `location` mode crashes.
- Background work is never guaranteed: force-quit, Low Power Mode, and a disabled Background App Refresh all stop it. Test on device, using lldb `_simulateLaunchForTaskWithIdentifier:`. Use `BGContinuedProcessingTask` (iOS 26) for user-initiated long work and the SwiftUI `.backgroundTask` modifier.

### Observability
- Use `Logger` (subsystem and category), not `print` or `os_log`. Use privacy annotations (`.public`, `.private`, `.private(mask: .hash)`), and never mark PII `.public`. Don't wrap `Logger` in a String-taking function, because that kills lazy interpolation and privacy. Know which levels persist.
- Measure with `OSSignposter` intervals (unique IDs for concurrent work), not timestamped logs. Use `XCTOSSignpostMetric` as a regression gate.
- **MetricKit:** subscribe early and never test in the simulator. Jetsam produces no crash report, so use `MXAppExitMetric`. The micro-hang threshold is 250 ms. Learn the watchdog codes `0x8badf00d` and `0xdead10cc`, and don't test watchdogs under the debugger.
- Match dSYMs by UUID. Run only one crash reporter. Use percentiles, not means.

### Security (Keychain / CryptoKit)
- **Critical:** never store tokens in `UserDefaults` or plists, so migrate them to the Keychain. Always check `OSStatus`. Bind biometrics to the Keychain via `SecAccessControl`, because a bare `LAContext.evaluatePolicy()` Boolean is patchable. Never reuse AES-GCM nonces.
- Pick the right `kSecAttrAccessible*` level. Use add-or-update flows. Use the Secure Enclave for P256 keys (it isn't available in the simulator). Use `ASWebAuthenticationSession` for OAuth. Use SPKI pinning via `SecTrust` when pinning is required.
- Tag every API with its minimum iOS version. Cite Apple docs, WWDC, or OWASP MASVS for non-obvious claims, and never invent session numbers.

---

## 9. App Store Release

### Review-readiness audit (run every section, PASS/WARN/FAIL each)
1. **Completeness (2.1):** no crashes on a clean install, placeholders, dead ends, broken URLs, or login failures. Handle offline gracefully.
2. **Privacy manifest:** `PrivacyInfo.xcprivacy` declares every Required-Reason API (file timestamp, boot time, disk space, active keyboards, UserDefaults) and third-party SDKs ship their own manifests.
3. **IAP and subscriptions (3.1):** the paywall shows the name, duration, and full renewal price (most prominent), the trial terms, working Terms and Privacy links, Restore, and no dark patterns. Use StoreKit 2 with verified transactions. The **first IAP must ship in the same submission as the version**. Provide review screenshots and notes per IAP.
4. **Privacy (5.1):** a reachable privacy policy, accurate nutrition labels, ATT if using IDFA, consent before sending data to third-party AI, and account deletion if accounts exist. Pre-permission buttons say "Continue", not "Allow". Face-data usage needs an explicit policy section.
5. ATS with no arbitrary loads. Set `ITSAppUsesNonExemptEncryption`. Use minimal entitlements, and set `TARGETED_DEVICE_FAMILY` deliberately.
6. **Code:** no `print` (use `Logger`), force-unwraps, hard-coded secrets, staging URLs, or debug UI in release builds.
7. **Metadata:** name and subtitle at most 30 characters, keywords at most 100 (comma-separated, not repeating title words), and current copyright. iPhone screenshots at 6.9" (1320×2868) or 6.5" (1284×2778). Icon at 1024×1024 with no alpha. Previews at most 30 s. Bump the version and build. Answer the age rating accurately, including AI content. Review notes include demo credentials.

### Release notes / "What's New"
- Collect commits since the last tag, keep only user-visible changes, and group them into New, Improved, and Fixed. Drop refactors, CI, and dependency updates.
- Write 5–10 one-sentence, benefit-first bullets in plain language. Every bullet must trace to a real change. Respect storefront character limits. Ask when unsure whether a change is internal.

### App Store Connect automation (`asc` CLI skills)
- Read and plan first, show a dry run, and apply only after explicit confirmation. Prefer JSON output and handle pagination. Validate character limits and screenshot sizes before upload. Localize keywords per locale rather than translating them literally.

---

## 10. Tooling & Workflow Skills
- **Codebase audit:** read-only, producing one `CODE_AUDIT.md`. Capture compiler warnings first (Xcode MCP or `xcodebuild`). Review concurrency and API modernity, dead code and duplication, and bugs, security, and performance. Every Critical or High finding cites `file:line` and is re-verified. Group findings by root cause, keep section numbering stable, and include a "What was NOT audited" section.
- **Simulator automation:** navigate by the **accessibility tree**, not coordinates. Keep output short, take screenshots only when needed, and require `--yes` for destructive simctl operations. Xcode 27 replaces `Simulator.app` with `DeviceHub.app`, and idb-companion must be 1.5.1 or later.
- **Figma → SwiftUI:** treat generated code as **design data**. Reuse the project's components and tokens. Export real assets (PNG, preserving scale and tint). Preserve existing behavior. Ask only about material ambiguity, then verify the rendered result and report limitations honestly.
- **Architecture:** choose by UI stack, state complexity, and existing conventions (MVVM, MVI, TCA, Clean, VIPER, Coordinator, MVP, Reactive). Default to vanilla SwiftUI MV for SwiftUI apps. Keep one pattern per feature, and don't bleed patterns together.
- **UI writing:** precedence is **clarity > voice > craft**. Establish or infer the product voice, and tune tone per situation (errors are clear and calm, celebrations warmer). Cut filler ("simply", "just", "Oops!", "successfully"). Be specific: "Cancel Subscription" / "Keep Subscription", not Yes/No. Keep a word list with one term per concept. Handle 0, 1, and many cases plus long names. Avoid "we". Read it aloud as the final test.

---

## 11. Quick Pre-Ship Checklist
- [ ] No deprecated APIs (§2.1). `@Observable` is `@MainActor`. `@State` is `private`.
- [ ] No force unwraps or force try, no swallowed errors, no GCD in new app code, no `Task {}` in loops, no `@unchecked Sendable` hacks.
- [ ] Every continuation resumes once, and every stream finishes. `CancellationError` is ignored, not alerted.
- [ ] SwiftData: explicit saves, explicit inverses and delete rules, safe predicates, CloudKit-compatible models.
- [ ] Dynamic Type, VoiceOver labels on icon buttons, 44pt targets, Reduce Motion handled.
- [ ] Every feature is reachable at every window size. Tabs and toolbar items have title + icon.
- [ ] Strings are localized (`LocalizedStringResource`, `#bundle` in packages), and values use FormatStyle.
- [ ] Swift Testing tests are parallel-safe and use no live network. SwiftData tests are in-memory with a fresh container each.
- [ ] Secrets in the Keychain, `Logger` with privacy annotations, no `print`.
- [ ] Privacy manifest, launch screen, and App Store metadata limits verified. SwiftLint is clean.

---

## Source Index

| Area | Skill (author) | Depth read |
|---|---|---|
| SwiftUI | SwiftUI Pro (Paul Hudson) | SKILL.md and all 12 references |
| SwiftUI | SwiftUI UI Patterns, View Refactor, Performance Audit (Thomas Ricouard) | SKILL.md |
| SwiftUI | SwiftUI Design Principles (Arjit Jaiswal) | SKILL.md |
| SwiftData | SwiftData Pro (Paul Hudson) | SKILL.md and all 5 references |
| SwiftData | SwiftData Expert (Kudrin Dmitry), SwiftData Testing (Akshay Pimprikar) | SKILL.md |
| Concurrency | Swift Concurrency Pro (Paul Hudson) | SKILL.md and all 12 references |
| Concurrency | Swift Concurrency Expert (Antoine van der Lee; Thomas Ricouard) | SKILL.md |
| Testing | Swift Testing Pro (Paul Hudson) | SKILL.md and all 5 references |
| Testing | Swift Testing Expert (Antoine van der Lee), Swift Testing (Eduardo Bocato) | SKILL.md |
| Language | API Design Guidelines (Erik de Erice), FormatStyle (Anton Novoselov) | SKILL.md |
| Core Data | Core Data Expert (Antoine van der Lee) | SKILL.md |
| Accessibility | iOS Accessibility (Daniel Devesa), Swift Accessibility (Pasquale Vittoriosi), Apple Accessibility (Roberto Gómez) | README |
| Platform | App Intents, Background Execution, Observability, Widgets (Anton Novoselov) | README |
| Platform | FocusEngine Pro (Michael Haviv), Swift Security Expert (Ivan Magda) | README |
| App Store | App Store Review (Dann Beauregard), App Store Changelog (Thomas Ricouard) | SKILL.md |
| App Store | App Store Connect CLI (Rudrank Riyam), ASO (Tim Broddin; moved to TimBroddin/skills) | README |
| Tooling | iOS Code Audit (Chad Etzel), iOS Simulator (Conor Luddy), Figma to SwiftUI (Ermolaev Maxim), Swift Architecture (Lasha Efremidze) | README |
| UI copy | Writing for Interfaces (Andrew Gleave) | SKILL.md |
| AGENTS.md | SwiftAgents (Paul Hudson) | full |

The catalog notes that being listed is not an endorsement. Review any third-party skill before installing it.
