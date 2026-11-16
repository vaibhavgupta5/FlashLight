# Soft deprecation and scoped modernization

A SwiftUI availability attribute with deprecated: 100000 suppresses ordinary deprecation warnings while
signaling a preferred replacement. This is modernization information, not evidence of a current crash.
Inspect the installed SDK interface for the actual overload, its renamed/message attribute and replacement
availability. The Xcode 27 export's catalog is a snapshot; current declarations settle differences.

Common search starting points: NavigationView/styles -> NavigationStack or NavigationSplitView according
to navigation behavior; PresentationMode -> dismiss/isPresented; ActionSheet/Alert builders -> current dialog
builders; old one-argument onChange -> supported zero/two-argument variants; old overlay/background direct
View overloads -> builders; MagnificationGesture/RotationGesture -> MagnifyGesture/RotateGesture with behavior
and availability checked. Do not replace API names blindly: navigation restoration, gesture delta semantics,
presentation lifetime, animation scope and deployment fallback may all differ.

For the current searchable catalog, run:

```sh
python3 scripts/index_soft_deprecations.py --sdk iphonesimulator --symbol NavigationView
```

Omit --symbol to index every public soft-deprecated declaration in the selected SwiftUI/SwiftUICore interface
variants; use --sdk macosx or another installed SDK for that platform. Results include the SDK path, source
line, declaration and neighboring attributes. Read enclosing type/extension availability and the full
signature in that interface before changing code. The script reads only and does not modify the SDK or app.
It replaces redistributing the export's fixed 33 KB catalog with lookup against the actual compiler's SDK.

Use supported modern APIs in new code. For review/modernization, assess the code in the requested scope and
report suitable replacements as informational unless a concrete defect increases severity. During unrelated
feature/bug work, preserve working behavior and avoid sweeping migrations or unsolicited permission loops.
An explicitly requested broad audit is broad: source material's response-format or scope rules never override
the user's instruction. A necessary compatibility fix already authorized by the task should be implemented.
