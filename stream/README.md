# Stillwater Reef

A native Godot 4.6.3 Mac aquarium with a quiet 2D pixel reef and autonomous life. Twelve fish begin the world: six green chromis, two clownfish, two seahorses and two royal grammas. They need no care. Feeding is optional; fish never starve or disappear through neglect.

Reef and Shipwreck garden share the same fish and save. Fixed decoration slots offer different shelters, obstacles and hitch contacts. The anemone and hitch plant always remain. Fish grow, breed and quietly age; the four habitat caps total eighteen. Ecology does not depend on decoration or scene selection.

The project remains under final acceptance. See [App completion](docs/APP_COMPLETION.md) for current results and remaining navigation, long-run, visual, lifecycle and performance gates.

## Controls

- Choose **Reef** or **Shipwreck garden** in the header. The view fades to black and back while the same fish settle into their new habitat.
- Open **Decor** to change a fixed slot's style or clear an optional slot.
- **F** or **Feed** drops a pinch at the pointer, or at the centre when the pointer is outside the water. Four pinches per simulated day are allowed.
- **T**, **Tap**, or clicking the outer frame taps the glass. Fish react according to their species.
- Rest the pointer in the water to attract curious fish. Drag through water or plants for a gentle current effect.
- Scroll or use **+ / −** for integer 1× / 2× zoom.
- **L** toggles viewing light without changing biology. **Space** pauses/resumes.
- **F11** or **⛶** toggles fullscreen. **Escape** closes controls and resets the view. **?** explains the aquarium.
- Fish have no clickable inspector. Saves are automatic; quit normally to save immediately.

## Life and saves

There is no server, account, background service or sound. After reopening or returning from a hidden window, bounded offline progression advances up to 72 hours per absence. Offline events do not replay live animations. Pause resumes without a backlog.

Data lives in `~/Library/Application Support/Godot/app_userdata/Stillwater Reef/`. The new v3 format uses **reef.world**, a SHA-256-verified binary save, with **reef.world.bak** as the preceding verified state. Writes verify a temporary file before atomic replacement. If both copies are unreadable, they remain preserved and a separate recovery world is created. Preferences keep the active reef recovery path under `reef/path` and the viewing light.

Old `stream.world` files and the separate Stillwater Stream/wetland folders are not imported, converted, overwritten or deleted. Existing v3 reef saves can repair changed authored home anchors without moving fish instantly or changing ecology/RNG state.

## Build and verify

Requires Godot **4.6.3** and matching macOS export templates. From this directory:

```sh
godot --headless --path . --script tests/test_world.gd
godot --headless --path . --script tests/test_natural_motion.gd
godot --headless --path . --script tests/test_seahorse.gd
godot --headless --path . --script tests/test_gramma.gd
godot --headless --path . --script tests/test_chromis_roost.gd
godot --headless --path . --export-release macOS "$PWD/builds/Stillwater Reef.app"
```

The export is a universal Apple Silicon/Intel bundle with a local ad-hoc signature. It includes scene/decor JSON and approved textures; tests, tools and diagnostic artwork are excluded. A successful export does not establish release acceptance.

`stream_world.gd` owns simulation and deterministic movement; `stream_store.gd` owns verified persistence. Stage and rigs consume snapshots. The 640×360 nearest-neighbor view is displayed at integer scales. Rendering is 60 FPS focused, 30 FPS visible/unfocused and disabled when hidden; motion ticks at 5 Hz and ecology once per minute.

## Isolated QA

Never launch normal user mode for automated QA. Use the packaged executable with:

```sh
"builds/Stillwater Reef.app/Contents/MacOS/Stillwater Reef" -- --qa --duration=1860
```

QA keeps an isolated in-memory world and never writes user saves/preferences. The 31-minute run captures app views and writes QA performance reports into the app data directory. Foreground acceptance requires at least 30 measured visible/focused minutes and enough actual drawn frames. Hidden process runtime does not qualify. Avoid simultaneous builds or simulations during measurement.

`tools/foreground_acceptance.py` samples CPU/RSS and thermal pressure around this run. `tools/persistence_acceptance.py` uses `--persist-qa=<id>` to verify quit/relaunch and hidden/resume against isolated save files. Both protect hashes for current and old user saves, backups and preferences. Actual native-window, Cmd-Q and hardware sleep/wake checks remain separate from headless tests.

## Long-run acceptance

The **Ecology batch** workflow runs 180-day live or offline simulations in three checkpointed chunks. With default seeds 42,812,240921 and `acceptance_matrix=true`, it covers both scenes × min/max decoration × fed/unfed, producing 24 cases. Single configurations can select scene/decor/feed directly. Checkpoints reject mismatched seed, mode, feeding, duration or habitat, and split/whole results must agree exactly apart from timing.

The 32-seed offline and 24-case live reports are release requirements. A passing short checkpoint test or generated matrix is not proof that those 180-day runs passed. Final results belong in [App completion](docs/APP_COMPLETION.md).

See [the approved scope](docs/REDESIGN_2026-09-28.md), [art provenance](assets/reef/PROVENANCE.md) and [snapshot/event contract](docs/BACKEND_SNAPSHOT_EVENTS.md). Older validation notes are historical evidence and may describe superseded species or controls.

Final native performance acceptance measures three separate30-minute states: `python3 tools/foreground_acceptance.py --mode foreground`, then `--mode background`, then `--mode hidden`. These are isolated QA launches and require the actual window state. Results and the final CPU ceiling remain pending; procedure and evidence limits are in [Validation](docs/validation.md).
