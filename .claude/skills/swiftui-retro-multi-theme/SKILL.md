---
name: swiftui-retro-multi-theme
description: Build SwiftUI apps with switchable visual themes (retro CRT/pixel, neon, paper/minimal, high-contrast, dark/light) using a token-based theme system, environment injection, custom fonts, and retro effects, with accessibility and Apple App Store safety in mind. Use when the user asks for retro styling, multiple themes, theme switching, custom skins, or a themed design system in an iOS app.
---

# SwiftUI retro + multi-theme UI

Goal: one codebase, many looks. Views never hard-code colors, fonts, or shapes. They read a `Theme` from the environment, so a new skin is one new value, not a sweep through every view.

## 1. Theme as a value (design tokens)

```swift
import SwiftUI

struct Theme: Equatable, Identifiable {
    let id: String
    let name: String
    let colors: Colors
    let typography: Typography
    let shape: Shape
    let effects: Effects
    let colorScheme: ColorScheme?   // nil = follow system

    struct Colors: Equatable {
        var background: Color
        var surface: Color
        var primary: Color        // main accent / interactive
        var secondary: Color
        var onPrimary: Color      // text on primary
        var text: Color
        var textMuted: Color
        var border: Color
        var success: Color
        var warning: Color
        var danger: Color
    }

    struct Typography: Equatable {
        var displayFamily: String?  // nil = system font
        var bodyFamily: String?
        var baseSize: CGFloat = 17  // scale off Dynamic Type, don't replace it
        func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
            // Custom fonts scale with Dynamic Type through relativeTo:
            if let family = bodyFamily {
                return .custom(family, size: baseSize, relativeTo: style).weight(weight)
            }
            return .system(style, weight: weight)
        }
    }

    struct Shape: Equatable {
        var cornerRadius: CGFloat
        var borderWidth: CGFloat
        var usesHardShadow: Bool    // neo-brutalist / retro drop shadows
    }

    struct Effects: Equatable {
        var scanlines: Bool
        var glow: Bool
        var grain: Bool
    }
}
```

Keep each theme a static value in its own file:

```swift
extension Theme {
    static let crtGreen = Theme(
        id: "crt-green", name: "CRT Green",
        colors: .init(background: Color(hex: 0x0B0F0B), surface: Color(hex: 0x121A12),
                      primary: Color(hex: 0x39FF14), secondary: Color(hex: 0x1F7A1F),
                      onPrimary: .black, text: Color(hex: 0xB8FFB0),
                      textMuted: Color(hex: 0x5C8A58), border: Color(hex: 0x39FF14),
                      success: Color(hex: 0x39FF14), warning: Color(hex: 0xFFD700),
                      danger: Color(hex: 0xFF4D4D)),
        typography: .init(displayFamily: "PressStart2P-Regular", bodyFamily: "VT323-Regular"),
        shape: .init(cornerRadius: 0, borderWidth: 2, usesHardShadow: false),
        effects: .init(scanlines: true, glow: true, grain: false),
        colorScheme: .dark)

    static let paper = Theme(
        id: "paper", name: "Paper",
        colors: .init(background: Color(hex: 0xF7F3E8), surface: .white,
                      primary: Color(hex: 0x2B2B2B), secondary: Color(hex: 0xC8B98F),
                      onPrimary: Color(hex: 0xF7F3E8), text: Color(hex: 0x2B2B2B),
                      textMuted: Color(hex: 0x7A7466), border: Color(hex: 0x2B2B2B),
                      success: Color(hex: 0x2E7D32), warning: Color(hex: 0xB26A00),
                      danger: Color(hex: 0xB00020)),
        typography: .init(displayFamily: nil, bodyFamily: nil),
        shape: .init(cornerRadius: 6, borderWidth: 1, usesHardShadow: true),
        effects: .init(scanlines: false, glow: false, grain: true),
        colorScheme: .light)
}
```

Add more themes the same way (e.g. `neonNight`, `synthwave`, `highContrast`, `system`). `highContrast` should meet WCAG AA (4.5:1 for body text).

## 2. Inject and read

```swift
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .paper
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

@Observable
final class ThemeStore {
    var current: Theme
    private let key = "selectedThemeID"
    static let all: [Theme] = [.crtGreen, .paper /*, ... */]

    init() {
        let saved = UserDefaults.standard.string(forKey: key)
        current = Self.all.first { $0.id == saved } ?? .paper
    }
    func select(_ theme: Theme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: key)
    }
}
```

At the app root:

```swift
@main
struct FlashlightApp: App {
    @State private var themes = ThemeStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, themes.current)
                .environment(themes)
                .preferredColorScheme(themes.current.colorScheme)
                .tint(themes.current.colors.primary)
        }
    }
}
```

Views read `@Environment(\.theme) private var theme`. Never reference `Color.red` or `.system(size:)` in feature code; go through the theme.

## 3. Retro building blocks

- **Pixel / CRT text:** use a bundled pixel font (register in Info.plist `UIAppFonts`, verify the PostScript name at runtime). Keep body copy in a readable font; use the pixel face for headings and labels only.
- **Hard-edged chrome:** `RoundedRectangle(cornerRadius: theme.shape.cornerRadius)` plus `.border(theme.colors.border, width: theme.shape.borderWidth)`. For hard shadows, draw an offset copy behind the surface rather than using blur.
- **Scanlines overlay (opt-in, respects Reduce Motion):**
  ```swift
  struct Scanlines: View {
      var body: some View {
          Canvas { ctx, size in
              for y in stride(from: 0, to: size.height, by: 3) {
                  ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                           with: .color(.black.opacity(0.25)))
              }
          }
          .allowsHitTesting(false)
          .ignoresSafeArea()
      }
  }
  ```
  Apply with `.overlay { if theme.effects.scanlines { Scanlines() } }`. Keep it purely decorative and never over text input or controls that need to be read clearly.
- **Glow:** `.shadow(color: theme.colors.primary.opacity(0.6), radius: 6)`, only on accents, never on body text.
- **Motion:** gate every animation on `@Environment(\.accessibilityReduceMotion)`.

## 4. Pattern checklist

- One source of truth: `Theme` value, injected via environment; `ThemeStore` only persists the selection.
- Components (`ThemedButton`, `ThemedCard`, `ThemedToggle`) take the theme from the environment; features compose components only.
- Theme switching needs no relaunch and keeps navigation state.
- Previews: `#Preview` each theme side by side (`ForEach(ThemeStore.all)`).
- Test: snapshot each theme in light and dark size classes at the largest Dynamic Type size.
- Contrast: verify every `(text, background)` token pair. Retro themes often fail; adjust before shipping.
- Apple review: custom fonts must be licensed for app bundling (check the font's license, e.g. OFL). Don't ship a theme that mimics a real brand's trade dress or logo.
- Respect the system: honor Dark Mode when the user chooses "System", Dynamic Type, Reduce Motion, and Increase Contrast.

## 5. Anti-patterns

- Hard-coded hex colors or font names inside feature views.
- Scattering `if theme == .crt { ... }` checks. Add a token instead.
- Using scanlines or flicker over the flashlight control or any tap target.
- Fixed point sizes for text that users need to read.
