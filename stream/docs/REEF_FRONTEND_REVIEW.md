# Current delivery — 2026-09-25

This section supersedes the older handoff below. Claude backend commits `f423e9f`, `54c4fec`, `a75442c`, `236c178` are now consumed: **four species, 12 opening fish**, no garden eels, wider firefish burrows and tang spacing/reach, and explicit live `ate` events.

## Plan status

- **Done §0 / §0.5 / §1:** owned frontend changes committed previously; existing smooth interpolation, event cursors, delayed removal, relocation and immutable-snapshot tests retained.
- **Done §2:** replaced the obsolete shrimp event-review tool with bounded natural seeded-history discovery. Birth, old-age death, arrival and dispersal have before/during/after images in `artifacts/event-review-reef/`, plus checkpoints, event ids, seed, simulation time and README. Discovery takes about 9 seconds; no ecological fixtures or RNG states are edited to force success. Public offline advancement finds a tick, public live advancement reproduces it. Fixed nighttime firefish arrival traveling underground; it now swims in above sand before hiding.
- **Cancelled §3 / deferred §3.5:** no shrimp or garden-eel work. Backend has now removed garden eels too; the prior temporary invisible-simulation warning is resolved.
- **Done §3.6:** real `ate` events animate only the consuming actor; vanished pellets no longer imply eating. Grazing mouth motion remains distinct; pursuing a pellet does not continuously chew. Explicit event-cursor and pause tests added. The 36-second `artifacts/reef-motion-refined/interactions.mp4` uses real feed/startle/lure APIs: four successful pinches, fifth rejected with Full today, recorded live bites, Startled and Curious states. Inputs and observed state samples are in `events.json`.
- **Implemented / user visual review remains §3.7:** current four-species atlas, background, rigs, contact behavior and interactions are integrated. Latest backend spacing resolves the previously reported firefish overlap. Soft Pixel with 960×540 bounded internal resolution follows the user's later request for finer detail; prior 640×360 plan is superseded by that quality pass. Production visual acceptance is still a user decision.
- **§4:** see packaged self-check below. This is not the formal 30-minute acceptance.
- **§5:** separately exported `builds/Stillwater Reef Frontend QA.app`; ad-hoc signature verified. Claude owns the final versioned distribution, hidden-window/thermal/persistence acceptance and formal 30-minute run. Do not mistake this test package for a released version.

Latest short test outputs: `test_frontend` 80/0, `test_presentation` 29/0, `test_swimmers` 103/0, `test_reef_animation` 31/0. No backend source was edited by Codex. Requested extra CI coverage for Claude: `tests/test_frontend.gd` and `tests/test_reef_animation.gd`.

## Packaged self-check and launch incident

The first package launch omitted Godot's `--` separator before user arguments and entered normal mode. It was stopped; it may have advanced/autosaved the real world. No rollback, manual save edits, or backup replacement was attempted. Those process samples are excluded. The corrected launch is `open -n "builds/Stillwater Reef Frontend QA.app" --args -- --qa --duration=120`; QA initializes a separate in-memory world and disables world/preferences saves. Treat correct mode verification as required for subsequent runs.

Corrected packaged run: **120.042 s**, 12 fish, Apple M5; 4.364 visible/focused seconds, 110.691 hidden seconds after the warm-up; 127 rendered frames. Visible samples averaged 33.978 ms, p95 36.364 ms, but this is too short to qualify. The 59 process samples collected while hidden averaged **0.280% of one core**, peak RSS **168.53 MiB**. Raw evidence: `artifacts/frontend-packaged-qa.json` and `frontend-packaged-qa-process.json`; log confirms `mode=qa path=(none)`. **Foreground short-run acceptance remains incomplete**, and none of this constitutes 30-minute or thermal acceptance. Do not rerun formal acceptance until the window can remain visible/focused.

Claude next actions: add frontend/reef-animation tests to CI; run a valid foreground short check and the planned formal acceptance; produce the versioned release from the current source. No extra ecological API is currently required. The frontend consumes `ate` with actor id and existing live event cursor, without writing any simulation state.

---

# Reef frontend animation handoff — updated 2026-09-25

## Latest override: defer garden eel

User: 「先不做花園鰻」. The active renderer now shows only blenny, yellow tang, green chromis and A3 purple firefish (11 of the current backend opening 13). Garden eels have no rendered body, hole, selection target, arrival/departure effect, water wake or startle ring. Their existing rig/art remains dormant for possible later use; no additional eel work is planned. **Claude: remove garden eel from the active backend cast and make an explicit save transition/departure policy. This frontend change does not remove animals, alter ecology, or edit user saves. Until that backend change, the two hidden eels still exist in simulation.**

Latest four-species test rerun: `test_frontend` 79 checks and `test_reef_animation` 24 checks, all passed.

All five-species performance/playback evidence below predates this final scope reduction. The new four-species preview is regenerated in the same output folder; do not treat eel motion as current acceptance scope.

## Implemented in source

User asked to implement animations per Claude's plan after replacing duplicate 03 red firefish with yellow tang, then requested finer detail. Active cast matches current backend keys: `garden_eel`, `lawnmower_blenny`, `yellow_tang`, `green_chromis`, and user-selected A3 `purple_firefish`. Opening world has 13 individuals. No shrimp, crayfish, nautilus, jellyfish or axolotl are rendered.

- Dedicated atlas meshes with GPU deformation: head-led turns with delayed tail, swimming effort from actual movement, separate pectoral/caudal motion, local gill breathing, feeding jaw and the firefish's flexible dorsal ray. Resting reduces movement; blenny support fins stay planted while perching/grazing. Alpha clipping removes generated halos without changing raster assets.
- Garden eels retract into their fixed holes, reemerge slowly and locally respond to water touch. Backend `extend` still controls sleep/startle. Firefish hover at backend `hover_y` (also correct for juveniles) and dive nose first into their holes. Selection follows the visible body.
- Blenny hops lift only the visual body from the backend substrate anchor; resting settles back onto that surface. Tang grazing preserves backend body position and foreshortens the fish toward its explicit mouth contact point.
- Burrow deaths retract rather than sink; arrivals retain fixed burrow anchors; outgoing silhouettes use the reef atlas. Eel arrival is currently an illustrative upright approach, not a validated horizontal swimming cycle.
- Fixed marine backdrop, interactive ribbon seagrass at the sides, reef algae and restrained water/food effects. The backdrop no longer distorts rock contact surfaces.
- Feed/Tap controls call the existing backend APIs, remain fixed through zoom, and do nothing while paused. Food comes from read-only snapshot positions. Keyboard T feedback follows newly startled actors; clicking Tap always draws a ring.
- Latest detail pass raises the bounded internal viewport from 640×360 to **960×540** in main and preview. Logical world/input coordinates stay 1280×720, nearest filtering and the 30 FPS cap remain. This is a deliberate frontend resolution adjustment to the earlier plan, not an ecological change.

## Verification

Short tests: `test_frontend` 79 checks, `test_reef_animation` 30 checks; both rerun after the detail pass, all passed. `test_presentation` 29 and `test_swimmers` 103 also passed during this integration. Tests cover paused motion, fixed burrows, contact placement, hover height, head/tail turn completion, selection, input handling, immutable snapshots and unchanged simulation random states.

A 14-second native playback uses an isolated real world, seed 42, biological hour 12: feed at 1 s, tap at 3 s, zoom at 6 s. No ecological activities are injected. Recording forces rendering to avoid macOS occlusion dropping frames; one capture per simulation step prevents duplicates. This is **not a performance measurement**. New output is `artifacts/reef-motion-refined/reef-motion.mp4`, with per-second PNGs and `events.json`. Normal view, disappearance after tap and return in close-up were visually inspected. Recording log has no script/shader errors.

```sh
godot --headless --path . --script tests/test_frontend.gd
godot --headless --path . --script tests/test_reef_animation.gd
godot --path . res://scenes/reef_motion_review.tscn -- --duration=0
godot --path . res://scenes/reef_motion_review.tscn -- --record --duration=14
```

Preview controls: F feed, T tap, R ripple, Z zoom, Space pause, Esc close. Preview never loads or writes user saves. A default run ends after 14 seconds. The older `tools/reef_review.gd` is a background/interaction review utility, not current motion evidence.

## Short rendering cost sample

Apple M5, Godot 4.6.3 native Compatibility renderer, 960×540, 13 opening animals, no recording/readbacks. Final 30 `ps` samples: mean **10.71% of one logical core**, peak RSS **231.09 MiB**. 1,138 rendered frames over 37.927 wall seconds (about 30 FPS). The preview uses `--disable-render-loop` plus explicit draw calls in benchmark mode so macOS occlusion cannot silently lower rendering cost. This measures bounded source rendering work; it does not establish packaged foreground/hidden power or thermal acceptance. The preview omits the production inspector/save lifecycle.

The first valid fixed-draw sample averaged 15.46%; removing redundant per-frame HUD text and static rig-overlay redraws reduced the observed cost. Fish animation and resolution remain unchanged. An earlier occluded-window sample was discarded. Raw local evidence: `artifacts/reef-motion-refined/process-benchmark.json` and `render-benchmark.json`.

```sh
godot --disable-render-loop --path . res://scenes/reef_motion_review.tscn -- --benchmark --duration=38
# Concurrent read-only sample of that process:
python3 tools/sample_process.py PID --seconds 30 --out artifacts/reef-motion-refined/process-benchmark.json
```

## Claude follow-up / acceptance gaps

1. **Firefish burrow spacing:** current starting holes at x=420 and 452 are only 32 world pixels apart; adult artwork is 91 world pixels long. Same-facing fish overlap substantially in close-up. Adjust backend habitat placement/spacing or hover lanes so visible bodies separate naturally. Do not fake different saved positions in the renderer. Tang adult artwork is 122 world pixels wide; consider that when checking separation and obstacle/contact placement too.
2. Burrow food disappearance currently triggers a short visual bite only when a pellet vanished near the actor; that can also represent expiry or another animal eating it. An explicit live food-consumption actor/pellet event would make exact attribution possible. Renderer does not consume food or alter outcomes.
3. Test rare birth/arrival/departure/death sequences in live playback, especially eel arrival. Short unit checks are not full visual lifecycle acceptance.
4. Package the current source and run the planned foreground/hidden, thermal and persistence acceptance. The revised viewport invalidates old graphics performance numbers. No new 30-minute run, hidden-window acceptance, packaged acceptance or thermal claim is made here.
5. Latest aesthetics remain subject to user review. This pass provides working animation, not a claim that all visual acceptance criteria are satisfied.

No backend, saves, schema or ecology files were edited by this frontend pass. `main.gd` changes are localized to input/help and the two viewport resolution/transform lines. Claude's current five-species backend is consumed directly.

## Art provenance

Runtime files and exact character prompts: `assets/reef/PROVENANCE.md`. Generated sources are copied unchanged into `assets/reef/`. Earlier board 03 red firefish is superseded. Original background/board prompts remain in `artifacts/reef-review/prompts.json`.
