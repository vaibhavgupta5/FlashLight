# Diagnose the isolation mismatch before adding annotations

Capture the exact diagnostic and the caller, callee, protocol requirement, and crossing value. Record Swift
language mode separately from compiler version and check default isolation and enabled upcoming features.
Classify whether the operation must stay on an actor, can operate on a Sendable snapshot, or intentionally
transfers ownership. Do not make the entire type MainActor just to remove one error.

## Isolated protocol conformance (Swift 6.2+)

If every use of a conformance belongs to MainActor, an isolated conformance can express that restriction:

```swift
protocol TitleSource {
    func title() -> String
}

@MainActor
final class EditorTitle: @MainActor TitleSource {
    var text = "Untitled"
    func title() -> String { text }
}
```

The annotation on the conformance matters. A blanket @MainActor extension is not an equivalent fix for every
nonisolated requirement. Check consumers: an isolated conformance cannot simply satisfy a generic requirement
that needs to use it across actors. Prefer an immutable Sendable snapshot or nonisolated pure implementation
when the protocol contract requires access elsewhere. Do not assume MainActor.assumeIsolated provides a hop.
See [SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md).

## Explicit CPU boundary (Swift 6.2+)

```swift
@concurrent
func normalized(_ values: [Double]) async throws -> [Double] {
    var output: [Double] = []
    output.reserveCapacity(values.count)
    for value in values {
        try Task.checkCancellation()
        output.append(value.isFinite ? value : 0)
    }
    return output
}
```

Choose this boundary for measured CPU work, not for every small transformation. A direct async call keeps the
current task’s cancellation relationship; checking cancellation cooperatively matters for long loops. It does
not need an unstructured detached task. A separate actor is appropriate when mutable state needs serialized
ownership, not merely because a calculation should leave MainActor. See
[SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md).

Verify the smallest affected target first, then behavior involving cancellation, ordering, or concurrent access.
New diagnostics in the changed boundary require analysis; unrelated preexisting warnings do not authorize an
unbounded repository migration. Adapted from Dimillian’s concurrency triage, with corrected conformance syntax
and detached-task guidance; see [community provenance](community-sources.md).
