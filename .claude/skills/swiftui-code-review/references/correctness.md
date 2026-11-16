# SwiftUI review candidates

## API availability and behavior

Compare the installed SDK and deployment target before proposing modern overloads such as foregroundStyle,
new Tab declarations, onChange, or toolbar placement. Prefer supported APIs in new code, but keep an older
implementation when the replacement cannot backdeploy or changes semantics. Scope modernization to the request.
GeometryReader, explicit EnvironmentKey types, and platform bridges each have valid uses; inspect their purpose.
For Xcode 27 State/ContentBuilder migration, consult the existing swiftui-fundamentals 27 reference if available.

## State lifetime and binding

Trace ownership and writers. An injected value copied into State can become a stale snapshot, but intentionally
editable drafts may require exactly that behavior. Check save/cancel semantics and identity resets before calling
it a bug. A projected Binding is convenient; custom get/set adapters remain appropriate for transformations,
validation, optional values, and external stores. Replacing one with onChange can change write timing and effects.

Observable does not itself require every model to be MainActor. Check actual accesses and isolation, and retain
working ObservableObject/Combine boundaries. Use the existing observation-framework or swift-concurrency skill
only when a concrete unresolved isolation/observation question needs it.

## Identity and work

For mutable collections, verify IDs remain attached to the same logical item through insertion, deletion, and
reordering. Positions are unsafe identities when those operations change which item occupies a position; fixed
positional collections are not categorically broken. Do not regenerate UUIDs during body evaluation.

Conditional branches can reset structural identity. Preserve it when the same control should retain state;
separate branches are valid when distinct lifetimes are intended. View extraction can narrow dependencies, but
small computed helpers are not inherently incorrect. Expensive body/initializer work is a review candidate;
confirm repetition and measure impact before asserting a performance regression. Cached derived data needs
an explicit invalidation policy. `.task` supports view-lifetime cancellation, but work must cooperate with it.

## Navigation and presentation

Check that value-based destinations are registered in the intended hierarchy and that lazy containers do not
make registration unreliable. Look for conflicting registrations and restoration mismatches. Direct-destination
NavigationLink and value-driven navigation are not automatically incompatible; reproduce the actual behavior.
For sheets, an item binding often keeps presentation and data coherent, while a Boolean is valid when no item
is required. Alert/sheet dismissal must write back to the state that controls presentation.

These adapted checks originate in upstream `data.md`, `api.md`, `navigation.md`, and `performance.md`. They
intentionally omit blanket architecture, style, target-version, and API-replacement mandates.
