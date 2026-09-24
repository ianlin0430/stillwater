# Stillwater Reef

A native Godot 4.6.3 Mac app: one soft-pixel stream pool, 14 individual animals, and autonomous ecology. This is a separate project; the previous wetland app and saves are untouched.

Open **builds/Stillwater Reef.app**. The bundle contains both Apple Silicon and Intel executables, with a local ad-hoc signature. It requires no server, account, installation service or network connection.

## Controls

- Click an animal to inspect its name, identity, age, activity, parent and recent events.
- Scroll or use + / − to zoom, up to 1.65×. Select an animal first to center the zoom there.
- F drops a pinch of food at the pointer. Food is real energy but never required; after four pinches a day the fish are full.
- T, or a click on the frame outside the water, taps the glass: nearby fish dart off and the garden eels duck.
- Rest the pointer in the water and curious fish drift over to look.
- Tab selects the next animal. Escape closes inspection and restores the whole pool.
- L toggles the viewing light. Natural biological time continues independently.
- Space pauses/resumes. The ? button explains the world.
- Quit normally to save. Automatic checkpoints are made every minute while visible.

## The world

A small reef: a pair of lawnmower blennies grazing the bed, a pair of yellow tangs cruising the upper water and pecking at the rocks, a school of six green chromis in midwater and a pair of purple firefish hovering over their burrows begin the scene. They need no care, but you may feed them (see controls). Reef resources (seagrass, drifting algae, biofilm, microfauna, detritus and nutrients carried by the ocean current) support growth, breeding and migration; death is possible. Individuals retain identities and lineage. Related young do not receive invented cooperative parenting.

Blue crayfish (2026-09-22), cherry shrimp and marbled hatchetfish (2026-09-23), threadfin rainbowfish (2026-09-24) and spotted garden eels (2026-09-25) were removed from the cast at the user's request. Older saves record any of them as departures, once, and keep their history; the reef cast then arrives once. Predation was removed at the user's request on 2026-09-23: no animal eats another. Older saves keep their past predation records.

The population target is 12–17 (the opening cast to the combined habitat of three blennies, two yellow tangs, four purple firefish and eight chromis, sized against the food pools by offline probe); the defensive hard limit remains 24. Surplus offspring disperse with the current as explicit events. Adults do not randomly depart, and existing animals are not silently removed to meet the budget. Food, breeding and natural mortality drive local generations; immigration mainly helps depleted species recover. Species can disappear locally and return later. See [model assumptions](docs/ecology.md) and [validation results and outstanding acceptance work](docs/validation.md).

On reopening or waking, elapsed time advances in bounded minute steps, capped at 72 hours per absence. Offline encounters are approximations, not frame-for-frame replays. Nothing runs after quitting. Hidden/minimized windows disable rendering and perform lightweight periodic updates.

## Saves

Separate location: `~/Library/Application Support/Godot/app_userdata/Stillwater Reef/`. Renamed from Stillwater Stream in 0.6.0 (2026-09-24): Godot derives this folder from the project name (no custom user dir; checked with `OS.get_user_data_dir()`), so 0.6.0 starts a fresh world and the old `Stillwater Stream` folder is left untouched as a backup.

`stream.world` is a versioned, SHA-256-verified binary save; `.bak` holds the previous verified state. A temporary file is verified before atomic replacement. Elapsed progress and its timestamp commit together. If both files are unreadable, they are preserved and a separate recovery world is created. Earlier v1 stream saves upgrade to the six-pool v2 model while preserving individual identities and lineage. The separate wetland app’s saves are not imported. `preferences.cfg` stores the viewing light and active recovery path.

## Build and verify

Requires Godot **4.6.3** and matching macOS export templates.

```sh
godot --path .
godot --headless --path . --script tests/test_world.gd
godot --headless --path . --script tests/test_swimmers.gd
godot --headless --path . --script tests/long_run.gd
godot --headless --path . --export-release macOS "$PWD/builds/Stillwater Reef.app"
```

Simulation lives in `scripts/stream_world.gd` (`advance_live`, `advance_offline`, `catch_up`, `snapshot`, `export_state`, `restore`). `stream_store.gd` owns verified persistence. `stream_stage.gd` and `swimmer_rig.gd` consume snapshots; presentation does not feed animation randomness back into ecology. Main handles controls, lifecycle and local time.

Rendering is capped at 30 FPS, the scene renders at 640×360 (using 1280×720 simulation coordinates), movement decisions run at 5 Hz, and ecology advances once per minute. Audio output is disabled because this version has no soundtrack. Assets use the selected soft-pixel direction, with articulated shrimp and head-led, deforming fish turns. Generation prompts are in [pixel artwork provenance](docs/pixel-artwork.md) and [fish/shrimp prompts](docs/pixel-cast-prompts.md). Plant biomass is simulated but the background artwork does not yet respond to it.

## Reproducible visual and performance QA

Run the packaged executable with `-- --qa --duration=1860` for a 31-minute isolated world (allowing warm-up). QA never writes the user's world or preferences. It captures several views and writes `qa-performance.json` into the app's data folder. Keep the Mac unlocked and the window frontmost for a valid foreground result. Check `foreground_30_minute_eligible`, actual drawn frames, and visible/focused seconds; elapsed process time alone does not qualify. `--hidden-test` exercises the application's suspended-rendering path after eight seconds; actual Cmd-H/minimize/resume also needs GUI validation.

`tools/sample_process.py PID --seconds 1800 --out artifacts/foreground-process.json` records process CPU (100% = one core) and RSS. `tools/thermal` reports macOS thermal pressure; it does not measure fan RPM or acoustic noise. Avoid simultaneous builds, recording or simulations during performance sampling.

`scenes/motion_strip.tscn` follows one shrimp or fish at true pixel scale and saves frames only after they are drawn, for frame-by-frame inspection (`-- --species=shrimp|threadfin|hatchet --out=DIR`). Keep its window visible: macOS skips drawing occluded windows. Diagnostic scenes are excluded from the packaged app.

For the complete packaged foreground measurement, run `python3 tools/foreground_acceptance.py`. It launches a 31-minute isolated QA run, samples process CPU/RSS every second and thermal pressure every 30 seconds, and records results under `artifacts/performance-30m/`. Keep the window frontmost. The report rejects runs without 30 measured foreground minutes and enough actual drawn frames. CPU mean uses the change in cumulative process CPU time after warm-up.

Version 0.4.1 adds occasional cross-pool exploration, curved fish paths, individual speeds, and varied stops. The movement generator remains seeded and saved; individuals retain their identities. The motion-review movie is a scripted rig demonstration, not a recording of autonomous roaming.

Version 0.5.0 integrates the fish/shrimp background, subtle bank-plant and surface motion, sparse drifting motes, curved fish turns, feeding details, and continuous male threadfin rays. See [art direction](docs/ART_DIRECTION.md) and [Claude non-art handoff](docs/NON_ART_CLAUDE_PLAN.md). Background generation provenance is in [art-050-provenance.md](docs/art-050-provenance.md).
