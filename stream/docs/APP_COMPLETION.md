# App completion, 2026-10-06

User goal: 完成整個 app. This supersedes the earlier frontend/backend work split; the current chat owns integration and remaining work. Approved art and immediate mirrored turns remain authoritative. User saves must not be touched by QA; launch with `-- --qa` or isolated persist QA.

The previously isolated `s4-cast-swap` branch is being integrated into main. Its latest commit is eafa772. This is a development integration, not a release acceptance: six reef navigation hesitation cases remain red. Original thresholds are retained.

## Work list

- [x] Inspect latest requirements and existing backend branch.
- [x] Add scene relocation API with identity, RNG, habitat and restore checks (12 checks).
- [x] Add FramePacer 60/30/0 state table (8 checks).
- [x] Connect scene/decor controls and remove fish inspection from main.
- [ ] Verify UI visually, resizing, keyboard and transition controls.
- [ ] Complete seahorse hitch/release/swim/feeding behavior and production rig. Initial implementation connected; dedicated long-motion gates remain.
- [ ] Complete gramma den/hover/hide behavior and production rig. Initial implementation connected; dedicated long-motion gates remain.
- [ ] Night chromis shelters and stable school navigation.
- [x] Quiet old-age departures, including save/restore (10 checks). Performance and visual review remain.
- [ ] Fix all S5 navigation failures without changing thresholds.
- [ ] Remove obsolete production cast paths and revise frontend fixtures.
- [ ] Run all relevant suites and update CI for the final cast.
- [ ] 32-seed offline ecology and 24 live scene/decor/feed acceptance runs.
- [ ] Package universal macOS app and verify signature, assets and saves.
- [ ] Foreground/background/hidden performance acceptance; lifecycle QA.
- [ ] Update README, PRODUCT, DESIGN and backend contracts to final behavior.

Evidence from this goal is under `stream/artifacts/completion/`. No release completion is claimed until the remaining gates are met.

## Initial integration evidence

Scene switch 12, FramePacer 8, home behavior 16, departures 10, frontend 80, scene data 168, stage scenes 41, new fish art 37, H5 review 22, save v3 40, clownfish contract 52, presentation 25, lifecycle 63 passed. Full `test_world` is still running with a 300-second timeout; the original 55-second timeout was too short and had no engine errors. Old cast-transition test needed removal of the obsolete inspector probe after inspection was removed; its remaining transition and pointer checks are retained.

Actual Godot graphical QA launched with `-- --qa --duration=23`, reported mode=qa and path=(none), and produced qa-reef.png, qa-shipwreck.png and qa-controls.png in the Reef user-data directory. Controls screenshot visually inspected: scene/decor controls and unified art render correctly. The app was partially occluded during this short run, so it is explicitly not foreground performance acceptance.

Next: evaluate current long test results; strengthen seahorse/gramma gates and fix geometry/navigation regressions; review departures and optimize their route cache; replace obsolete production/test cast behavior; then CI, ecological acceptance and package.

## Home and departure follow-up

Home geometry: 8 checks passed on both scenes × min/max decor (60 seconds each). Corrected destination-bed clamping after horizontal movement; the first run had 10 very small bed intrusions in each shipwreck preset.

The first full world run completed with 248 checks and 7 failures. All seven were provisional S4 behavior assertions, superseded by S7/S8 (seahorses now hold hitches and grammas retreat to their den). Updated those semantic assertions, retained swimming-fish travel thresholds and introduced the planned seahorse >=80% daytime hitch gate. Fixed an actual seahorse arrival clasp bug. The focused `new_cast_checks()` gate now passes all 53 checks; a complete fresh world rerun remains required.

`test_cast_transition` now passes 46 checks after removing only the obsolete fish-inspector probe. Production gramma den clipping now stops when fully emerged. Export explicitly includes JSON to retain scene/decor data. Departure routes are cached and saved on each visual actor, invalidated on decor changes; scene changes discard these visual actors during the black transition. Departure save/restore gate remains 10/10.

The full natural-motion run was started before the latest fixes; its output must be treated as diagnostic and rerun on final code. No S5 gate or threshold was edited.

The diagnostic natural-motion suite finished: 70 checks, four failing assertions, with engine errors from an obsolete tang fixture. It also exposed seahorse hitch state surviving externally assigned travel targets and new decor covering it; this made forced obstacle trips incorrectly stay attached. Fixed hitch invalidation for external trips and covered centres, and initialized all motion fields on held actors. Requires a fresh natural-motion/obstacle run. Remove the obsolete tang encounter scenario (the tang is no longer in SPECIES); preserve every applicable kinematic and S5 threshold.
