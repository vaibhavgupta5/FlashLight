# DESIGN.md — Flashlight (iOS)

## Discovery
- Artifact: iPhone utility app. Primary action: switch the light on, set intensity.
- Audience: anyone who needs light now. Dark rooms, one hand, sometimes gloves.
- Adjectives: tactile, real, calm.
- Aesthetic essence: "a real lamp, out in the real night".

## Committed direction
Two independent choices, combined freely (9 lamps × 6 scenes).

**Lamp (the object).** Every lamp is a real 3D model built in code: surfaces of revolution from measured profiles, physically based materials (metalness, roughness, clear glass), and a dark studio environment for reflections. Nothing is a recoloured shape.

| Lamp | Real detail |
|---|---|
| Tin Beacon | lacquered steel, chrome rims, printed Baskerville label, slide switch, incandescent bulb behind a parabolic reflector |
| Ranger | knurled grip, crenellated strike bezel, rubber tail switch, lanyard eye, side switch, O-ring |
| Pen Steel | brushed aluminium pen, knurl band, pocket clip, push-button end |
| Site Light | rubber overmold with ribs, hazard band, hanging loop, black bumper |
| Harbor Lantern | brass fuel font, glass globe, cage wires, bail handle, enamel plate, live flickering flame |
| Filament Bulb | E27 screw base with real threads, glass envelope, four LED filaments, bakelite socket, cloth cord |
| Taper Candle | brass candlestick, wax with drips and a melt pool, wick with ember, flickering flame |
| Ring Light | LED diffuser ring in a housing, bracket, swivel, telescoping pole, weighted base |
| Table Lamp | glazed ceramic body, brass fittings, pull chain, linen shade that glows, bulb inside |

**Scene (the world).** One Metal shader draws the sky and terrain; Vortex adds particles.
- Sky: gradient, twinkling stars, milky way, aurora curtains, cratered moon or sun, domain-warped clouds.
- Terrain: ridged-multifractal mountains with snow lines, pine forests, dunes with sand grain, meadow grass, atmospheric perspective and valley mist.
- Water: a moon reflection with a glitter path and rippled reflections of the terrain.
- Scenes: Pine Night, Desert Dusk, Moon Tide, Aurora Tundra, Alpine Dawn, Firefly Meadow.
- Particles (Vortex, MIT): fireflies, snow, drifting mist, desert dust.

**Signature move.** The lamp's light is real in the scene. The beam, halo and flame glow start at the lens, wick or filament, using the 3D model's actual projected position. On-screen light blinks in sync with the LED in strobe and SOS.

## Platform language
- Controls use Apple Liquid Glass (`glassEffect`, `GlassEffectContainer`) on iOS 26+, with a frosted-material fallback on iOS 17–25.
- Glass appears only on the control layer. The lamps and scene are content, never glass.
- UI text is SF, to match the system. Lamp labels use each maker's own face (Baskerville, Menlo, Avenir Next, Didot).
- This is a deliberate exception to the deslop skill's "no system font / no glassmorphism" rules. The brief asked for Apple's Liquid Glass look, and glass here is functional chrome, not decoration.

## Tokens
- Per lamp: `beam`, `accent`, `onAccent`. Everything else is geometry and materials.
- Per scene: sky colours, up to four terrain layers (kind, baseline, amplitude, seed, colour), celestial body, water horizon, fog, stars, aurora, particles.
- Radius: 16 pt for tiles and cards, capsules for sliders and status, a 60 pt circle for power. No radius above 16 on a card.
- Motion: 0.08 s for lamp level (keeps strobe crisp), 0.2–0.4 s for mode, lamp and scene changes. No bounce.
- Shadow: none on controls.

## Craft
- Layout: title and palette at the top, the lamp as hero, controls in the thumb zone.
- States: mode tiles, the power button and sliders tint with the lamp's accent when active. Sliders show their value.
- Accessibility: the lamp is an adjustable element (swipe for intensity) with label, value and hint. Mode tiles expose the selected trait. Targets are 58–60 pt. Reduce Motion freezes the sky and removes particles.
- Performance: the landscape renders at half resolution and 15 fps; static lamps render only when they change; thumbnails are cached snapshots.

## Slop audit (frontend-design-deslop checklist)
Passes:
- No purple/indigo gradients, no gradient text, no glow box-shadows on controls, no side-tab borders, no 01/02/03 markers, no decorative grid or stripes, no bounce.
- No stock imagery. Every object is modelled, and every background is computed.
- Radius ≤ 16 pt on tiles and cards.
- A single named signature move is present.

Accepted, with reasons:
- Equal-width mode tiles: the only control group, and it is native-feeling.
- Radial halos: they are the lamp's own light, projected from the model, not ambient decoration.
- Fireflies are small glowing dots, but they are scene content and appear only in two scenes.
- Liquid Glass and SF text: see Platform language.

Gaps:
- Backgrounds are realistic procedural art, not photographs. A real photo or HDRI set (for example CC0 skies from Poly Haven) would go further, but means downloading assets.
- SceneKit is deprecated as of iOS 26. It still builds and runs, but a long-term move to RealityKit is needed.
- Not tested on a physical iPhone: the LED, thermals and frame rate on device.
- Lamp labels in the 3D scene do not scale with Dynamic Type.
