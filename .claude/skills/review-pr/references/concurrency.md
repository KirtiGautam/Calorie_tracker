# Swift concurrency review checklist

Project settings change what counts as a finding:

- **Default isolation is MainActor.** App-target declarations are main-actor unless they're marked `nonisolated`. Don't ask for `@MainActor` annotations, and treat `MainActor.run {}` in app code as usually redundant.
- **Approachable concurrency is on.** A `nonisolated` async function runs on the caller's actor (Swift 6.2 behavior). A plain `async` helper does **not** move CPU work off the main actor. CPU-heavy work, such as parsing big JSON or aggregating many log entries, needs `@concurrent`. Networking already suspends, so it doesn't.
- **Strict concurrency is `complete`.** A new concurrency warning is a High finding, not a nit.
- `Domain/` and DTO and mapper types are `nonisolated`. If one of them reaches main-actor state, isolation is leaking.

## Hotspots: inspect every one in the diff

| Pattern | What to check |
|---|---|
| `Task {` | Is it inside a loop? Use a task group. Is it in `onAppear`? Use `.task`. Are errors handled inside it? A `try` in a `Task` drops the error. Is the handle stored and cancelled when it's replaced? Could the caller just be `async`? |
| `Task.detached` | Rarely right. Usually `@concurrent` or structured concurrency is what's wanted. Make sure dropping isolation and priority is intended. |
| `withCheckedContinuation`, `withCheckedThrowingContinuation` | The continuation must resume **exactly once** on every path, including early returns, errors, callbacks that never fire, and the object being deallocated. Zero resumes hangs forever. Two resumes crashes. Never use the `withUnsafe…` variants without profiling evidence. |
| `AsyncStream { continuation in … }` | Prefer `AsyncStream.makeStream(of:)`. Check that `finish()` runs on every exit path, that `onTermination` cleans up, and that a fast producer has a bounded `bufferingPolicy`. |
| `@unchecked Sendable` | Almost always hides a race. It's acceptable only with real internal locking (`Mutex`) that you've verified. Prefer value types, actors or `sending`. |
| `nonisolated(unsafe)` | Only for truly immutable state the compiler can't prove safe. |
| `DispatchQueue`, `DispatchGroup`, semaphores | Not in app code. Use async/await, actors, or `Mutex` for synchronous locking. |
| `Task.sleep(nanoseconds:)` | Use `Task.sleep(for:)`. Sleeping to wait for state is a bug. |
| `actor` | Check reentrancy (below). Is an actor needed at all? Flag actors that just forward calls. |
| `!` after `await` in an actor | Crash risk if another caller changed the state. |

## Correctness

- **Actor reentrancy.** All assumptions about state are invalid after an `await`. A check, then `await`, then act on the check is the classic bug. Capture results in locals, then write. To dedupe work, store in-flight `Task`s.
- **Unstructured tasks in loops** lose cancellation and errors. Use `withTaskGroup` or `withThrowingTaskGroup`, or `withDiscardingTaskGroup` for side effects. Use `async let` for a fixed set of different calls.
- **Partial results.** When one child failing shouldn't cancel the others, as in `CombinedFoodSearch`, catch inside each child and return a `Result`. A throwing group cancels all siblings on the first error.
- **Cancellation is cooperative.** Long loops call `try Task.checkCancellation()`. Use `withTaskCancellationHandler` for APIs that have their own cancel. Cancel the old stored task before starting a new one (search-as-you-type), and in `deinit` (use an `isolated deinit` if it touches state).
- **Stale responses.** In search-as-you-type, a slow earlier request can overwrite newer results. Look for cancellation of the previous task, `.task(id: query)`, or a check that the query is still current before assigning.
- **`CancellationError` isn't a user error.** `catch is CancellationError { }` should come before the generic catch that shows a message. Showing "cancelled" alerts when the user types quickly is a bug.
- **Swallowed errors.** `Task { try await x() }` with no `do`/`catch`, or `try?` on a user action, means the failure never reaches the user (see `userMessage(for:)`).
- **Main-actor blocking.** Look for synchronous heavy work in view models or `@MainActor` code: decoding big payloads, aggregating history, image processing. Suggest `@concurrent`.
- **Sendable crossings.** Non-Sendable values captured in `@Sendable` closures or `addTask`. Fix by passing values instead of objects, making the type Sendable, or keeping the work on one actor. `ModelContext` and `@Model` instances never cross actors. Pass a `PersistentIdentifier` and fetch it again.
- **Isolated conformances.** A main-actor type conforming to a nonisolated protocol should use `extension T: @MainActor P`, rather than `@preconcurrency` or `nonisolated` hacks.

## Tests for concurrent code

- Make the test `async` and `await` the real work. No `Task.sleep` or fixed delays.
- Use `confirmation()` for events, and make sure all the work finishes inside the closure. If production code fires off an internal `Task`, it should return the handle or be `async`.
- `.serialized` only affects parameterized tests.
- Cancellation tests must exercise a cancellation check in production code, not one written in the test.
