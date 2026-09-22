# Stillwater

A local macOS wetland observatory built with Godot 4.6.3. Watch minnows, frogs, midges, voles and herons interact across a lake, wetland and woodland. Animals feed, reproduce, age, migrate and die; population collapse is possible.

## Open the app

Double-click `builds/Stillwater.app`, or run from this folder:

```sh
open builds/Stillwater.app
```

The app runs offline. The included universal Mac build is locally signed for personal use.

## Observe and experiment

- Drag the landscape to pan; scroll to zoom. **Reset view** returns to the overview.
- Click an animal to inspect its age, reserves, activity and recent events. **Follow selected animal** tracks it; Escape clears selection.
- Click the lake to move the underwater cutaway. Its animals come from the same world state as the landscape.
- Space or **Pause** pauses the world. **1×**, **5×** and **20×** control ecological time. At 1× a year takes approximately two hours.
- Use the view menu for food or habitat overlays. The sidebar shows population history and recent observations.
- **Branch experiment** saves the parent and creates a paused independent world. Change rainfall, add nutrients, or add/remove animals, then resume. All interventions are recorded.
- **Save** or Command-S saves immediately. **Open** resumes an existing `.world` file, including a branch.

The app autosaves every minute and on normal exit. It does not advance the world while closed, and discards long frame gaps after suspension. Restart opens the default world; use **Open** to return to an experimental branch.

## Saves

Worlds are stored in:

```text
~/Library/Application Support/Godot/app_userdata/Stillwater/
```

`stillwater.world` is the default world. Branches use `experiment-….world`. Saves contain the full simulation and random-generator state. Each save is verified before replacing the previous file; `.bak` retains the last valid version. An unreadable primary falls back to its backup. If neither can load, both original files are preserved and the new world uses a separate `-recovery-….world` destination.

## Model and implementation

Read [the ecological assumptions](docs/ecology.md) before interpreting results. Resource pools use an illustrative conserved material equivalent; this is not a validated scientific forecasting model. Fish cannot recolonize the isolated lake. Other arrivals follow explicit calendar-driven probabilities, independent of population declines.

- `scripts/ecosystem.gd`: seeded fixed-step model, organism behavior, resource accounting and interventions.
- `data/species.json`: illustrative organism parameters.
- `scripts/world_view.gd`: landscape and underwater projections.
- `scripts/main.gd`: observation tools, clock and application lifecycle.
- `scripts/save_store.gd`: checksummed saves, atomic replacement and backup recovery.

One biological step is 0.25 days. Visual movement interpolates positions on a separate timescale. Playback executes the same steps at every speed, retaining pending work rather than skipping steps under load. Event and individual histories are bounded; cumulative death causes remain available.

## Reproduce validation and builds

Use Godot **4.6.3** for reproducibility. From this directory:

```sh
godot --headless --path . --script tests/test_ecosystem.gd
godot --headless --path . --script tests/long_run.gd
godot --headless --path . --export-release macOS builds/Stillwater.app
builds/Stillwater.app/Contents/MacOS/Stillwater -- --qa --qa-ecology
codesign --verify --deep --strict builds/Stillwater.app
```

Long-run tests cover seeds 42, 812 and 240921 for ten years each. A single seed can be supplied after `--`. Results and logs are in `artifacts/`. Packaged QA uses an isolated world, writes screenshots and reports to the app's user-data directory, and exits automatically without touching saved worlds. Its ecological pass captures naturally occurring feeding, pursuit, fleeing, reproduction and all four seasons, and checks the cutaway's organism IDs against the shared snapshot.
