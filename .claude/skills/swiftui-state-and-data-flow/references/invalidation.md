# Invalidation boundaries and model inputs

Use separate View structs for substantial screen sections with explicit narrow inputs. A computed property
or ViewBuilder helper improves organization but is evaluated in the parent's body and does not create an
independent observation boundary. Tiny fragments with no separate dependency story can remain helpers.
Keep view init cheap: input assignment, not I/O, decoding, format construction or repeated large transforms.
Remove redundant Group around one concrete child when it serves no semantic purpose; conditional or multiple
content Groups may be intentional.

Pass only consumed fields of value-type inputs; forwarding data to children counts as consumption. For a
large payload, use per-section values or a stable Observable model. Reference identity and observed property
reads differ from value inputs: don't mechanically unpack every Observable into primitive arguments. Multiple
legitimate property reads do not alone justify splitting a view.

Observation tracks stored properties, not dictionary keys or struct subfields. A computed selectedItem that
searches items still depends on items. Cache an expensive derived value only with a complete invalidation
policy covering every input/mutation; use persistent smaller models or independent stored properties when
that actually reduces dependencies. Do not create unsynchronized duplicate sources of truth. Correct
Equatable semantics can suppress redundant assignments in current Observable macro expansions; inspect the
compiler and type's cost, never use equality that ignores meaningful changes. Model tracking/isolation is
owned by `observation-framework`; UI models require an appropriate actor, usually MainActor (explicit or
project default), and Observable itself does not make races safe or support actor declarations.

Keep State private and owned by view identity; exposing it is an API/lifetime change that must be made
within scope. Prefer projected/key-path bindings, including a writable computed property/subscript for
reusable transformations. A custom Binding remains appropriate for stores or validation that cannot use a
projection; preserve write and transaction semantics. Bindable enables projections, not observation itself.

An onChange-only dependency can invalidate an expensive parent. Move that dependency and its side effect
into a small dedicated View when the parent does not render it. This gives no reduction if the parent also
renders the value, and adds needless structure for a trivial parent. Keep effect cancellation and lifetime
attached to the intended view/model owner.

For onScrollGeometryChange, transform geometry into the smallest Equatable value needed by the behavior
(for example a threshold Bool); act only when that value changes. Avoid forwarding every offset into broad
model state. Attach the modifier to the intended scroll view: a parent containing multiple scroll views
only observes the first and logs a runtime issue. Check API availability against the deployment target.
Source: [Apple scroll-geometry contract](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)).
