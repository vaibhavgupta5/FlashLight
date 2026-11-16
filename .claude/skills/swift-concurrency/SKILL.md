---
name: swift-concurrency
description: >-
  Write modern Swift concurrency with async/await, Task, TaskGroup, actors,
  @MainActor, Sendable, AsyncSequence/AsyncStream, and Swift 6 strict data-race
  safety. Use when writing or refactoring asynchronous Swift code, fixing
  "data race"/"non-Sendable"/"actor-isolated" compiler errors, replacing
  completion handlers, running work off the main thread, or coordinating
  concurrent tasks on any Apple platform (iOS 26+, macOS 26+, watchOS 26+).
---

# Swift Concurrency

Modern Swift uses structured concurrency. Prefer `async`/`await` and actors over completion handlers,
`DispatchQueue`, and locks. Swift 6 enforces **data-race safety at compile time**.

> **Check the actual toolchain.** Record Swift language mode, strict-concurrency settings, default actor isolation, and enabled upcoming features. Swift 6.2 introduced optional default main-actor isolation and `NonisolatedNonsendingByDefault`; their behavior depends on target settings, not the OS version alone. Preserve existing settings unless a migration is part of the task.
>
> `async`/`await` does not guarantee off-main execution. With caller-isolation semantics enabled, a nonisolated async function can remain on its caller's actor. For substantial CPU work, design an explicit isolation boundary; Swift 6.2+ supports `@concurrent` async functions. Check Sendable transfers and cancellation instead of using Task.detached to silence diagnostics.

For protocol-conformance diagnostics or an explicit CPU boundary, read
[references/diagnostic-remediation.md](references/diagnostic-remediation.md).

## When to use this skill

- Writing `async` functions or calling `await` APIs (e.g. `URLSession.data(for:)`).
- Refactoring callback/`completionHandler` code into `async`/`await`.
- Fixing compiler diagnostics: "Sending ... risks causing data races", "non-Sendable type", "main actor-isolated", "Reference to captured var in concurrently-executing code".
- Coordinating multiple concurrent operations (parallel fetches, fan-out/fan-in).
- Protecting shared mutable state.

## Core model

### async / await

```swift
func loadProfile(id: String) async throws -> Profile {
    let (data, _) = try await URLSession.shared.data(from: profileURL(id))
    return try JSONDecoder().decode(Profile.self, from: data)
}
```

`await` marks a suspension point — the function can pause and the thread is freed. Call `async` functions from
another `async` context, or from a `Task`.

### Task — entering an async context

```swift
Task {
    do { self.profile = try await loadProfile(id: "42") }
    catch { self.error = error }
}
```

- `Task { }` inherits the current actor (so a `Task` started in a `@MainActor` view runs its body on the main actor).
- `Task.detached { }` does **not** inherit context — avoid unless you specifically need to escape actor isolation.
- Store the handle (`let t = Task { … }`) to `await t.value` or `t.cancel()`.

### Structured concurrency: run work in parallel

Use `async let` for a fixed number of concurrent children:

```swift
async let user = loadUser()
async let posts = loadPosts()
let (u, p) = try await (user, posts)   // both run concurrently; awaited together
```

Use `TaskGroup` for a dynamic number:

```swift
func loadAll(ids: [String]) async throws -> [Profile] {
    try await withThrowingTaskGroup(of: Profile.self) { group in
        for id in ids { group.addTask { try await loadProfile(id: id) } }
        var result: [Profile] = []
        for try await profile in group { result.append(profile) }
        return result
    }
}
```

A task-group scope waits for every child before returning. Normal return does not cancel unfinished children; when the group body throws, unfinished children are cancelled and then awaited. For a first-result/race operation, explicitly call `group.cancelAll()`. Cancellation remains cooperative. Results above arrive in completion order; retain input indices if caller order matters, and bound the number of in-flight tasks for large inputs.

## Actors — protecting shared mutable state

An `actor` serializes access to its mutable state; cross-actor access is `await`-ed.

```swift
actor ImageCache {
    private var cache: [URL: Image] = [:]
    func image(for url: URL) -> Image? { cache[url] }
    func store(_ image: Image, for url: URL) { cache[url] = image }
}

let cache = ImageCache()
await cache.store(img, for: url)        // await: crossing into the actor
```

### @MainActor — UI and main-thread work

UI must run on the main actor. Annotate types or members that touch UI:

```swift
@MainActor
final class FeedModel {
    var items: [Profile] = []
    var ids: [String] = []
    var error: String?
    func refresh() async {
        do {
            let new = try await loadAll(ids: ids)
            try Task.checkCancellation()
            items = new // still main-actor isolated; await alone did not move CPU work off-main
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
```

`@Observable` view models that feed SwiftUI are typically `@MainActor`. You rarely need `DispatchQueue.main.async`
anymore — annotate with `@MainActor` instead.

## Sendable — safe across isolation boundaries

A `Sendable` type can cross concurrency domains under its safety contract. Struct/enum inference is limited:
non-public, non-usableFromInline types and eligible frozen types can infer it; other public types need explicit
conformance. Their stored properties/associated values must be Sendable. A checked class conformance requires
a final class with immutable Sendable storage and no superclass other than NSObject. Internal locking alone
does not establish compiler-checked conformance; a manually synchronized class normally needs a justified
`@unchecked Sendable` conformance. Global-actor-isolated classes have a different checked isolation contract.
See [Apple's Sendable requirements](https://developer.apple.com/documentation/swift/sendable), checked 2026-10-28.

```swift
struct Message: Sendable { let id: Int; let text: String }
```

- Prefer immutable value types crossing boundaries.
- Avoid `@unchecked Sendable` — it disables the safety check. Use only with a manually-synchronized class and a comment justifying it.

## AsyncSequence / AsyncStream — streams of values

```swift
for try await line in url.lines { print(line) }   // built-in AsyncSequence

// A bounded stream for a callback producer:
let (stream, continuation) = AsyncStream<Int>.makeStream(
    bufferingPolicy: .bufferingNewest(1)
)
continuation.yield(1) // call from the producer callback
continuation.finish() // finish when the producer ends
for await value in stream { print(value) }
```

When adapting a real delegate, retain it for the stream lifetime and stop/unregister it in `onTermination`. That closure is Sendable and may run on a different executor; route cleanup to the producer's required isolation. Choose a buffer/drop policy that matches the events.

## Cancellation

Cancellation is cooperative — check it in long work:

```swift
for item in items {
    try Task.checkCancellation()    // throws CancellationError if cancelled
    await process(item)
}
```

In SwiftUI, prefer `.task { }` over `Task { }` for view-tied work — it auto-cancels when the view disappears.

## Pitfalls & best practices

- **Don't** capture and mutate a `var` from inside a concurrent closure — pass values in, return results out.
- **Don't** block an actor with synchronous long work; it stalls everything queued on it.
- **Don't** reach for `Task.detached` to "fix" an isolation error — fix the isolation instead.
- **Do** fix diagnostics in the project's actual language mode; stage any requested Swift 6 migration rather than silently changing all target settings.
- **Do** select isolation for the operation; preserve required queue/thread affinity and blocking-I/O boundaries. Actors and Tasks are not mechanical replacements for every GCD queue.
- **Do** keep async functions free of side effects on shared state unless that state is actor-isolated.

## Quick reference

| Need | Use |
| --- | --- |
| Call async API | `await` inside an `async` func or `Task` |
| Enter async from sync | `Task { }` (inherits context) / `.task { }` in SwiftUI |
| Fixed parallel work | `async let` |
| Dynamic parallel work | `withTaskGroup` / `withThrowingTaskGroup` |
| Protect mutable state | `actor` |
| Run on main thread | `@MainActor` |
| Cross-boundary value | `Sendable` type |
| Stream of async values | `AsyncSequence` / `AsyncStream` |
| Cancel | `task.cancel()`, `Task.checkCancellation()` |

Sources: [Swift 6.2 concurrency options](https://www.swift.org/blog/swift-6.2-released/), [TaskGroup semantics](https://developer.apple.com/documentation/swift/taskgroup).
