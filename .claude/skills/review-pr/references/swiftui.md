# SwiftUI review checklist

Baseline: iOS 27.0, Xcode 27.1, iPhone (including iPhone Duo) and iPad with resizable windows. Anything gated to iOS 26 or 27.0 is fine without `#available`. iOS 27.1-only APIs need `if #available(iOS 27.1, *)` with a fallback.

Soft-deprecated APIs (`deprecated: 100000`) don't produce warnings, so a clean build doesn't prove the code is current.

## Deprecated or legacy API (Medium)

| Instead of | Use |
|---|---|
| `foregroundColor()` | `foregroundStyle()` |
| `accentColor()` | `tint()` |
| `cornerRadius()` | `clipShape(.rect(cornerRadius:))`, or `ConcentricRectangle()` next to a screen or sheet edge |
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `NavigationLink(destination:)` | `navigationDestination(for:)`, and never mix the two in one stack |
| `tabItem()` | `Tab("Title", systemImage:, value:)` with an enum selection |
| `.navigationBarLeading` / `.navigationBarTrailing` | a semantic placement (`.cancellationAction`, `.confirmationAction`, `.primaryAction`), else `.topBarLeading` / `.topBarTrailing` |
| `navigationBarHidden()`, `toolbar(.hidden, for:)` | `toolbarVisibility(_:for:)` |
| `statusBarHidden()` | `toolbarVisibility(.hidden, for: .statusBar)` |
| `onChange(of:) { newValue in }` (one parameter) | the zero- or two-parameter form |
| `.animation(_:)` without `value:` | `.animation(_:value:)` or `withAnimation` |
| `AnimatableModifier`, hand-written `animatableData` | `@Animatable` (with `@AnimatableIgnored`) |
| `overlay(SomeView())`, `background(SomeView())`, `mask(SomeView())` | the trailing-closure builder form |
| `PreviewProvider` | `#Preview` |
| `showsIndicators: false` | `.scrollIndicators(.hidden)` |
| `autocapitalization()`, `disableAutocorrection()` | `textInputAutocapitalization()`, `autocorrectionDisabled()` |
| `colorScheme()` | `.environment(\.colorScheme, …)` |
| `sizeCategory`, `ContentSizeCategory` | `@Environment(\.dynamicTypeSize)` |
| `UIScreen.main` | container-relative layout, or `\.displayScale` for pixel scale |
| a hand-wrapped `WKWebView` | SwiftUI `WebView` |
| `UIImpactFeedbackGenerator` | `sensoryFeedback()` |
| a manual `EnvironmentKey` | `@Entry`, with a stable default (not `UUID()`, `.now` or a new reference instance) |
| `Text("a") + Text("b")` | interpolation: `Text("\(a)\(b)")` |
| `Image("name")` | the generated asset symbol `Image(.name)` |
| `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` | `@Observable` with `@State`, `@Bindable` or `@Environment` |

`@ViewBuilder` in existing code is fine. New builders may use `@ContentBuilder`.

## Data flow

- View-owned `@State` must be `private`. With Xcode 27, a non-private `@State` re-runs its initial expression whenever the parent rebuilds. Initialize each `@State` in exactly one place.
- The `@Observable` view model is owned by the view as `@State private var viewModel`. It's created in `init` from a dependency passed in or taken from `AppDependencies`, not as an optional set later with `onAppear`.
- Don't put `@AppStorage` inside an `@Observable` class. It doesn't trigger updates. In this project, settings go through `TargetsStore` anyway.
- Avoid `Binding(get:set:)` in `body`. Bind to a property, or to a writable computed property on the model. Make sure a refactor keeps setter and `onChange` semantics the same.
- Numeric input binds `TextField(value:format:)` to a number, with `.keyboardType(.decimalPad)` or `.numberPad`. The keyboard type alone isn't enough.
- `ForEach` identity comes from the element: `Identifiable`, or a stable `id`. Flag `indices`, `\.offset`, `id: \.self` on large structs, identity derived from editable fields, and IDs created inside `body`.
- Pass each row its element, not the store plus an index or ID.
- Keep window-specific state (selection, navigation path) in scene-local `@State`, not in shared singletons.

## View structure

- Long `body` blocks and computed `some View` helpers should be extracted into `View` structs in their own files. A few tiny private helpers are acceptable.
- Button actions call methods: `Button(.save, action: save)`. Business logic doesn't belong inline in `body`, `task`, `onAppear` or `onChange`.
- Use `.task` for async work, not `onAppear { Task { … } }`. Use `.task(id:)` when the work depends on a value.
- Don't swap the whole root view with `if`/`else` when a modifier value (`opacity`, `disabled`, `overlay`) would do. Never add a `View.if()` helper.
- Inside a lazy container, each `ForEach` element should produce a constant number and kind of views. Filter the data first rather than using `if` inside the row. Wrap branches in a `VStack`, not a `Group`.
- Remove a `Group` that wraps only one view. Avoid `AnyView`.
- Prefer `TextField(axis: .vertical)` over `TextEditor` unless full-screen editing is needed.

## Navigation and presentation

- `TodayView` owns the path and the sheets, so check that new ones are registered there.
- Register `navigationDestination(for:)` once per type in each stack.
- Use `sheet(item:)` for optional data, and `alert(_:item:)` or `confirmationDialog(_:item:)` for a single pending value.
- An alert with only an OK button can use an empty actions closure.
- Attach `confirmationDialog` to the control that triggers it, except inside `ToolbarOverflowMenu`.

## Layout and resizing (iPhone Duo and iPad)

- Choose layouts from size classes, and test `== .regular`, never `!= .compact`. Don't use `userInterfaceIdiom` or orientation.
- Every feature must be reachable at every window size. Don't hide controls in compact layouts.
- Screens that assume content fits (onboarding, forms) need scrolling or a `ViewThatFits` fallback. The iPhone Duo outer display is short.
- Don't fake safe-area insets with fixed padding. Use edge-qualified `ignoresSafeArea(edges:)` on content, and `safeAreaInset()` or `safeAreaBar()` for pinned bars.
- Prefer `containerRelativeFrame()`, `visualEffect()` or `Layout` over `GeometryReader`.
- Tabs and toolbar items need both a title and an icon. Use semantic placements, `ToolbarItemGroup` for related actions, and `ToolbarOverflowMenu` instead of a custom ellipsis `Menu`.
- When size classes pick different view hierarchies, keep selection and path state above the branch so a fold doesn't reset it.

## Accessibility

- Icon-only `Button` and `Menu` need text: `Button(.addFood, systemImage: "plus", action: add)`, plus `.labelStyle(.iconOnly)` if it should look icon-only. Missing labels are Medium, or High on a primary action.
- Use a `Button`, not `onTapGesture`. If a gesture is unavoidable, add `.accessibilityAddTraits(.isButton)` and a label.
- Use Dynamic Type text styles. No fixed `.font(.system(size:))`. Use `@ScaledMetric` or `.font(.body.scaled(by:))` when a custom size is needed. Avoid `.caption2`. Adapt layouts for `dynamicTypeSize.isAccessibilitySize` (for example, switch the stack axis).
- Respect `accessibilityReduceMotion` and use opacity instead of large motion. Follow `TodayView`.
- Decorative images use `Image(decorative:)` or `accessibilityHidden(true)`. Meaningful images get a localized label. Never hide interactive elements.
- Charts, rings and progress views for calories and macros need an `accessibilityLabel` and `accessibilityValue`, for example "Protein, 82 of 120 grams".
- Don't put trait words in labels: "Delete", not "Delete button". Add hints only when needed.
- Tap targets are at least 44×44 points.
- Don't use color alone to tell things apart (over or under target). Respect `accessibilityDifferentiateWithoutColor`.
- Accessibility labels and values are localized like any other text.

## Localization and UI copy

- See the localization rules in `project-rules.md`.
- Read locale, calendar and time zone from `@Environment`, not `.current`.
- Use automatic grammar agreement or plural variants in the catalog for counts ("1 item" or "2 items"). Don't concatenate strings.
- Copy priorities: clarity first, then voice, then craft. Errors say what happened and what to do next ("Couldn't reach USDA. Check your connection and try again."). Destructive confirmations name the action ("Delete Entry" or "Keep Entry", not Yes or No). Remove filler words ("simply", "just", "Oops", "successfully"). Use one term per concept across the app (for example, "entry" versus "log" versus "item").

## Performance (only in hot paths)

- No sorting, filtering, decoding or formatter creation in `body`, view initializers or row views. Derive data in the view model.
- Use `Text(value, format:)` instead of stored formatters.
- Keep conditional modifier values inside the modifier.
- Use `LazyVStack` or `List` for long collections.
- Keep rapidly changing values (scroll offset, drag position) out of the environment.
- Remove `@Environment` key-path properties the view doesn't read.

## Design

- Use `ContentUnavailableView` for empty and no-results states (`.search` with `searchable`).
- Use `Label` for icon plus text, and `LabeledContent` in forms.
- Use hierarchical styles (`.secondary`) instead of manual opacity.
- Use `bold()` instead of `fontWeight(.bold)`.
- Use SwiftUI `Color` and asset colors, not `UIColor`.
- Avoid hard-coded padding and spacing unless there's a design reason. Reuse shared constants if the project has them.
