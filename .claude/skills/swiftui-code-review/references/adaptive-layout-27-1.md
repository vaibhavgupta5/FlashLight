# Adaptive layout in platform 27.1

Verified against Apple documentation on 2026-10-28. This is an adoption reference, not a requirement to redesign every screen.

`ArrangementView` and `ReservedRegion` are platform 27.1 APIs, not baseline 27.0 APIs. An OS availability branch still needs an SDK that declares the symbols. Keep the existing layout for older deployment targets.

Use ArrangementView for two related content areas that should change between split and overlay arrangements. It is not a replacement for every NavigationSplitView or TabView. Apple cautions against nesting it in other layout containers such as scroll views/grids, or nesting navigation split views/tab views inside it; consult the actual container contract before composing them. Keep model ownership and navigation selection stable through arrangement changes.

For custom geometry, distinguish occlusion regions (content must avoid them) from division regions (content should occupy separate sides). Query the affected view's coordinates rather than device model or screen dimensions. Region frames already include margins; adding them again double-pads content. Partial intersections can extend outside view bounds. The default query returns active regions; use includeInactive only when the intended layout needs inactive regions. Account for layout direction and coordinate conversion before positioning.

System toolbars can move to a vertical edge. Read toolbarVerticalEdge for custom adjacent chrome; use toolbar item axis behavior only when the interaction needs it. Do not assume bottom tabs and horizontal toolbars across all configurations. Check each modifier's availability separately.

Verify state preservation, open/partially folded/closed configurations where supported, portrait/landscape, RTL, text size, keyboard and toolbar overflow. Simulator checks are not proof of physical hinge or camera behavior.

Sources:
- https://developer.apple.com/documentation/swiftui/arrangementview
- https://developer.apple.com/documentation/swiftui/reservedregion
- https://developer.apple.com/documentation/updates/swiftui
