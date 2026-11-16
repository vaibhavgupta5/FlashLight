---
name: swiftui-code-review
description: >-
  Review SwiftUI source for concrete API-availability, view-identity, state-lifetime,
  binding, and navigation correctness issues when the user requests a SwiftUI
  code-quality or modernization review. Not a general implementation, visual/HIG
  audit, performance-profiling, or generic PR-review workflow.
license: MIT
metadata:
  upstream: twostraws/SwiftUI-Agent-Skill
---

# SwiftUI Code Review

Review only the requested source scope. Read the target platform, deployment target, SDK, language mode,
and isolation settings before judging an API or state-management choice. Preserve the existing architecture.
A request to review produces findings; apply changes only when fixes are also requested.

Read [references/correctness.md](references/correctness.md) for the relevant checks. Load only the portions
needed for the question. The checklist supplies review candidates, not automatic violations.


Use [soft deprecation and live SDK lookup](references/soft-deprecation.md) for API modernization. For Xcode
27 compiler diagnostics consult `swiftui-fundamentals`; state/collection/environment mechanics come from
`swiftui-state-and-data-flow`. Contribute findings in this review's existing report rather than a second audit.

## Scope and evidence

- For an existing PR/diff review workflow such as `gitnexus-review`, contribute SwiftUI-specific checks within
  its established diff and report. Do not restart repository discovery or run a second broad review.
- For HIG, accessibility-compliance, or App Store policy requests, use `apple-hig-review`, `macos-hig-review`,
  or `app-store-review` as appropriate. An icon-only button is not automatically inaccessible: verify its
  effective label and traits. This skill does not certify accessibility.
- For UI creation/refactoring, Liquid Glass, and measured performance work, use the installed platform skill
  that owns that task. Do not turn every SwiftUI edit into a code review.
- A deprecated declaration, a soft deprecation, and a personal style preference are different findings.
  Confirm current SDK declarations before claiming deprecation. An API replacement must preserve behavior
  and remain available on every supported target; do not raise the deployment target to satisfy the checklist.
- Do not flag valid custom Binding adapters, Combine/ObservableObject integration, helper views, or AppKit/UIKit
  bridges merely for existing. Demonstrate a concrete state, correctness, or maintenance problem.

Report actionable findings with file/line, a triggering scenario, its consequence, and the smallest compatible
fix. Prioritize behavioral defects. Mark performance suspicions as unmeasured; report no findings when none
are supported. Do not require a fixed number of findings, new architecture, or mandatory additional agents.

Adapted from Paul Hudson’s SwiftUI Pro; [provenance](references/upstream.md) and [license](LICENSE.txt).

For ArrangementView, reserved regions, or vertical toolbars on platform 27.1, read [the current Apple guidance](references/adaptive-layout-27-1.md).
