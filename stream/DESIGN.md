# Stillwater Reef design

## Experience
A small, quiet reef beside other work. Fish remain the focus; controls frame the water instead of covering it. Reef and Shipwreck garden have one coherent visual language.

## Approved artwork
Use the approved v2 low-pixel fish and scene assets. Keep recognizable silhouettes, small restrained eyes, limited palettes and crisp clusters. The cast is green chromis, clownfish, upright seahorse and purple/yellow royal gramma. No old tang, firefish or blenny routes remain in the production stage.

Later approval supersedes the redesign's paper-flip draft: turns use the side image and an immediate mirror with facing hysteresis. No front/intermediate poses, width squeezing or idle turn loop. Body and tail change facing together.

## Pixel presentation
The world uses 1280×720 simulation coordinates and a 640×360 nearest-neighbor viewport. Display it at integer scales with letterboxing and pixel-aligned transforms. Zoom switches between 1× and 2×. Window resizing and fullscreen preserve pixel geometry. Smooth system-font UI stays outside the pixel world.

## Motion
Chromis shoal and rest steadily at night. Clownfish stay mostly around the anemone, make short food excursions and retreat on taps. Seahorses remain upright: tail contact stays fixed while gently leaning; occasional slow excursions lead to a different free hitch. Royal grammas hover within 50px of their individual home, enter a local cave clip when hiding and remain visible beside fallback rocks.

Ease pose changes with real delta. Small home adjustments use pectoral motion; longer trips turn naturally. Obstacles and other bodies guide movement without position jumps. Old age uses a quiet live departure and fade, without sinking bodies or replayed offline animations.

## Controls
Ivory text, muted secondary labels and restrained slate-green surfaces. Scene selection sits in the header. Decor opens a compact row of fixed-slot choices; required slots have no empty choice. Escape closes controls and resets the view. No animal inspection sidebar or click-to-select flow.

Scene changes fade fully to black and back over 0.75s total. Move the same fish to appropriate homes while black, preserving ecology and random states.

## Quiet operation
No sound. Focused visible rendering runs at 60 FPS, visible unfocused at 30 FPS, hidden/minimized rendering is disabled. Hidden event delivery remains responsive and offline progression is bounded. Actual packaged-app performance, thermal behavior and lifecycle need measured acceptance, tracked in [App completion](docs/APP_COMPLETION.md).
