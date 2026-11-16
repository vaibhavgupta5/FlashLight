# Editing boundaries and identity

A State value initialized from parent input is a snapshot, not a live binding. That is appropriate for an
editable draft when Save commits and Cancel discards it. Define what happens when a different item is selected
or the source changes during editing: preserve the draft, reset by stable item identity, or resolve a conflict.
Avoid automatically overwriting dirty edits in onChange. Use a Binding when edits should immediately affect
the parent and a plain input when the child only reads it.

Projected bindings preserve the existing storage path. Custom Binding(get:set:) is valid for transformations,
optional fields, validation, or external stores; keep its getter pure and its writes predictable. Replacing a
custom setter with onChange can change timing and which writes trigger an effect. If a manual adapter loses
animation transaction information, examine the transaction-aware setter and how it forwards writes before
removing animation or duplicating the source of truth.

For a numeric value, TextField(value:format:) supplies parsing/formatting semantics. A numeric keyboard alone
does not validate pasted input. If the user must enter intermediate text such as an empty field or partial
negative/decimal value, an explicit String draft with a defined commit/validation policy can be appropriate.

## State ownership is separate from collection identity

An ID must follow a logical item across reorder/insert/delete. Index identity is wrong when those operations
change what the index represents; a fixed positional collection can legitimately use indices. A computed UUID
is not stable. Duplicate labels are not unique IDs. Changing `.id` deliberately resets the subtree’s state,
focus, and tasks, so use it only when that is the intended lifecycle boundary.

For custom environment closures and Entry defaults, use the more specific [official-derived guidance](environment.md).
It distinguishes framework actions from custom keys, stable from freshly allocated defaults, and live fallback
readers from latent issues. Do not retain the former blanket "inspect only" advice for new custom keys.

Adapted from the twostraws data/performance references and AvdLee state/list references; see
[community provenance](community-sources.md). Existing project architecture takes precedence over their defaults.
