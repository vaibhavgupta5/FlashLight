# Collection identity and row cost

ForEach, data-driven List/Table/OutlineGroup and selection controls need stable, unique element identities.
Use a durable model ID, never a fresh computed UUID or an editable label. A stored UUID is fine if its owner
outlives body reconstruction. Indices/offsets identify positions and break identity during insertion, deletion,
filtering and reordering; fixed positional data is a different case. Enumerated offsets can be displayed while
id uses element.id. Direct enumerated RandomAccessCollection support depends on toolchain/runtime
availability; check the chosen deployment target and use Array when required.

Prefer a small identity key over hashing the entire large/mutable element. Identifiable is useful when the
type has genuine identity; retain explicit id paths for context-specific identity. Don't remove Hashable
conformance used elsewhere merely to fix a costly id selection. URLs/strings still have length-dependent
costs; do not promise that every possible identifier is constant-time.

Keep nontrivial filter/sort/group/reconstruction work out of repeated body evaluation: derive it once per
relevant input change, or in a query/model, with cache invalidation tested for source and filter changes.
Cheap slices and small transforms need no speculative cache. Filter unwanted rows before ForEach instead
of generating zero content for some elements.

Lazy containers work best with a known constant row count per element. Use one real root container around
a row's branching/multiple content. Group and ForEach are passthroughs; a bare switch or AnyView can force
row evaluation to discover structure. Returning some View from a helper does not itself make a varying
row unary. Wrap optional inner content when a row must remain present; upstream filtering is appropriate
when the item should disappear entirely. Verify that wrapping does not change intended separators, selection,
accessibility grouping or layout. A supported `-LogForEachSlowPath` launch diagnostic can locate candidates;
use runtime profiling to quantify them, not automatic severity based on syntax alone.
