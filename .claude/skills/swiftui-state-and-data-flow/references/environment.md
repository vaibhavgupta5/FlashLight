# Stable environment and focused values

Prefer @Entry when supported by the compiler and the actual enclosing API. It is a macro: inspect generated
code and the underlying protocol's availability rather than assigning every expansion the same OS floor.
A manual key remains appropriate for a stored default or compatibility. Boilerplate alone is modernization
information, not evidence of a correctness defect or an urgent performance regression.

## Defaults and actions

@Entry evaluates its default expression through a getter. Fresh Model(), Date(), UUID(), random data, or a
struct containing a freshly allocated reference can therefore create a changing default on each fallback
read. Trace whether readers actually fall back: full upstream injection makes this a latent issue, not measured
current invalidation. Literals, enum cases, nil and references to an already stable instance are stable; no
Equatable conformance or defensive memoization is required merely because a struct contains a reference.

If readers test a sentinel to mean 'missing', use an optional nil default and handle absence. If the default
is a real shared value, retain it in a concurrency-safe stored constant and reference it from @Entry or use
a manual key's stored default. Do not fabricate equality that ignores changes to hide repeated allocation.
Respect actor isolation and Sendable rules for static storage; do not introduce unsafe global mutable state.

For new custom Environment/FocusedValue actions, prefer a value handler with captured data as fields and a
method/callAsFunction, or a stable model that owns the behavior. Distinct open-ended implementations can
conform to a handler protocol; closely related handlers can share a model. A struct that still stores a
closure, or a let closure on a repeatedly reconstructed View, does not establish reliable comparison.
Existing custom closures are a concrete invalidation risk to investigate and improve within scope, not a
compile error. Framework action keys such as openURL, dismiss and refresh intentionally accept their action
types; do not replace those APIs because they wrap closures.

## High-frequency updates

Avoid pushing raw scroll position, drag coordinates, timer ticks, window size or per-frame progress through
the environment. Inject a stable Observable model, then store the coarsest state each consumer needs (e.g.
isWide or a row's isVisible). A computed threshold that still reads the raw offset retains that dependency;
store/update the threshold only when it changes. Reading one shared Set or Dictionary creates a dependency
on that entire stored property; use persistent per-item models when per-item isolation matters. Do not create
fresh row models in body. For purely visual scroll effects, prefer scrollTransition/visualEffect where
available; prefetching or model actions still need explicit lifecycle and coarse state.

Remove unused key-path Environment/FocusedValue reads after checking helpers and projected storage: they
can register dependencies even without a visible body read. An unused type-based Observable environment
reference is different: no model property read means no property-level observation, so removal is usually
cleanup, not proof of a live performance win. Profile representative updates before claiming a speedup.
