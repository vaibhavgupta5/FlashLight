# Flashlight

A SwiftUI flashlight for iPhone with nine real 3D lamps, six procedural nature scenes, Apple Liquid Glass controls, and the real LED.

## Features

- **Real torch:** drives the rear LED through `AVCaptureDevice` at 5–100% intensity.
- **Modes:** Torch, Strobe (1–15 Hz), SOS (Morse) and Screen (full-screen colour; the slider sets display brightness).
- **Nine lamps in 3D:** Tin Beacon, Ranger, Pen Steel, Site Light, Harbor Lantern, Filament Bulb, Taper Candle, Ring Light, Table Lamp.
- **Six scenes:** Pine Night, Desert Dusk, Moon Tide, Aurora Tundra, Alpine Dawn, Firefly Meadow. Pick the lamp and the scene separately.
- The beam, halo and flame start at the real 3D lens or flame, and blink in sync with strobe and SOS.
- Lamp, scene, intensity and strobe speed are saved. The torch turns off when the app goes to the background.

## How it is built

- **Models:** SceneKit with physically based materials. Surfaces of revolution are generated in `Models3D/Lathe.swift`. Each lamp is a builder in `Builders+Torches.swift` or `Builders+Lamps.swift`.
- **Backgrounds:** a Metal fragment shader in `Design/LandscapeShader.swift`, compiled at runtime, so no offline Metal toolchain is needed. Particles come from [Vortex](https://github.com/twostraws/Vortex) (MIT).
- **Controls:** Liquid Glass on iOS 26 and later, frosted material before that.

## Build

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Flashlight.xcodeproj
```

The first build fetches Vortex from GitHub. The simulator has no LED, so there the beam is a preview and Screen mode works normally.

## App icon

`Flashlight/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` is a 1024×1024 PNG with no alpha channel, rendered from the real 3D Tin Beacon. To regenerate it, run a Debug build in the simulator:

```bash
xcrun simctl launch booted com.example.flashlight -exportIcon
cp "$(xcrun simctl get_app_container booted com.example.flashlight data)/tmp/AppIcon-1024.png" \
   Flashlight/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

The exporter is compiled only in Debug builds.

## Test hooks (Debug only)

- `-torchID <id> -sceneID <id>` start with a given lamp and scene (ids: `tin tactical penlight workLight lantern bulb candle ring table` and `forest desert ocean aurora alpine meadow`).
- `-startLit` starts with the light on.

## Before App Store submission

- Change the bundle ID (`com.example.flashlight` in `project.yml`) to your own, and set your team under Signing.
- `ITSAppUsesNonExemptEncryption` is already set to `NO`.
- Test on a real iPhone, and take screenshots there so the LED and beam show together.
- SceneKit is deprecated since iOS 26. It still works and ships in App Store apps.
- Run the checklist in `.claude/skills/app-store-review`.
