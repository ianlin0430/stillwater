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

The diagnostic natural-motion suite finished: 70 checks, four failing assertions, with an engine error from missing heading fields on held seahorses. It also exposed seahorse hitch state surviving externally assigned travel targets and new decor covering it; this made forced obstacle trips incorrectly stay attached. Fixed hitch invalidation for external trips and covered centres, and initialized all motion fields on held actors. Requires a fresh natural-motion/obstacle run. The historical tang labels in this suite already refer to the new cast. Keep those encounter gates and all kinematic/S5 thresholds. Controlled seahorse trips also contribute to heading-turn coverage, since a correctly held horse may never turn in the unprovoked daylight sample.

## Navigation and attachment follow-up

The six original reef hesitation cases now have zero excess hesitation/flip, no-progress, raw-centre intrusion, heading-rate, teleport or relocation failures. The selected subset still fails the original global detour-sample assertion (533 < 2000); this is diagnostic only. Full scene/decor navigation runs remain required. Bed-aware neighbor passing fixed seed31 reef/min gramma returning from a removed cave.

Added `tests/test_seahorse.gd`: eight fixed seeds × two scenes, 30 minutes daylight and 120 seconds night, 64 checks. An intermediate landing implementation passed all 64. The subsequent body-crossing fix exposed three fresh failures (reef42 hitch share/night; shipwreck1 daylight share). Do not mark S7 complete until the final implementation passes both attachment and natural body-separation gates. Fixed body-box crossing includes a floating-point boundary tolerance; the focused separation/feeding suite subsequently passed separation and overlap, but initially failed clown food access. Clownfish now wait below approaching pellets within the existing 120px home feeding radius; focused feeding passes 4/4, with every species eating. Full S6 and contract reruns remain required.

Fresh scene switch12, FramePacer8, home behavior16, home geometry8, departures10 and save v3 40 passed. Current logs are under artifacts/completion and artifacts/nav-redesign/completion-safe-body. Full navigation matrix is still running; current changes are work in progress, not a release.

Latest focused body/feeding run: 7 checks passed; maximum same-species overlap .199 (limit .2), feeding overlap 0, all four species ate. Full eight-seed S6 clownfish gate passed 128 checks, including both scenes and tap-return times <=1.4 seconds. The attempted always-tangential horse return worsened S7 and was reverted. Current excursion selection also rejects a free hitch whose straight approach crosses another horse's body; blocked horses wait for the neighbor's excursion instead. The fresh 64-check S7 gate is running in `seahorse-clear-trip.log` and is not yet a verdict. Full navigation `natural_obstacles,guard6,targeted_guard` is running in `nav-safe-body.log`; it began before the latest feeding/excursion changes and must be treated as diagnostic if it exposes differences. No thresholds weakened.

Latest navigation `natural_obstacles` completed 39/39; latest clownfish contract 52/52. `guard6` remains running.

## Full-cap habitat follow-up

S7 fixed-hitch coordinates now include body spacing at the full four-horse cap, with facing chosen outward at contacts 1 and 3. Small contact adjustments: seagrass contact3 x+10; gorgonian contact3 y+4; kelp contact2 x+10/contact3 x-36. These are gameplay anchors, not replacement art; final visual contact QA remains. Added saved waypoint routes around held neighbors and excluded those destinations from roaming/staging substitutions. Added route-state validation. Full eight-seed S7 has been diagnostic while this changes; do not treat earlier 64/64 as final.

Added `test_gramma.gd` (224 checks): eight fixed seeds × two scenes × min/max decor, full species cap, daytime hover50, unique homes, night cave clipping/rock visibility and tap. Home-aware reachability uses the same own-home obstacle margins as actual navigation. Gramma free-home selection now prefers available caves. Reef fallback rock2 moved into the swimming bounds; shipwreck fallback rocks now occupy reachable positions. The first wide pass had one boundary floating-point drift (shipwreck/max/5 50.788px); fixed radius-crossing tolerance and rerunning.

Full navigation diagnostic completed natural_obstacles39/39 and targeted_guard11/11. guard6 retained its original assertions and had three excess hesitation cases: reef/min240921 gramma11 at359.8; shipwreck/min29 gramma11 at900.6; shipwreck/max240921 chromis4 at271.4. Those are on earlier home geometry and require fresh investigation after home behavior stabilizes; no threshold changed. Focused body/feeding gate with new home semantics passed7/7 (feeding overlap.083, all species ate).

Latest S8 wide rerun: 224 checks passed after boundary tolerance fix. Added `test_chromis_roost.gd` with the original S9 requirement: nearby eligible night shelter, actual navigable resting target <=60px, no relocation on roost approach or dawn, return to daylight band and untouched ecology RNG. It is an intentionally unimplemented gate at this checkpoint; the current 430px daytime band cannot reach shelters around570–614px. S9 needs a derived night layer and smooth dawn return, not an unconditional daytime-band expansion or hard clamp/teleport.

World suite on preceding home revision completed249 checks, with one residual seahorse proximity failure (65px vs60); S7 excursions and routes must be checked against this applicable neighborhood assertion. Latest S7 full-cap change still has two reattach30 failures; body overlap now remains within the original20% gate. Current latest implementation uses exact waypoint ownership, water-valid waypoint coordinates, opportunistic direct-route shortcuts, and tangential landing with physical box spacing. Fresh tests running: seahorse-landing-tangent-final.log, body-feeding-landing-final.log, chromis-roost-red.log. Work remains uncommitted while S7 settles; no release claim.

World's sole remaining249-check diagnostic failure was the provisional S4 rule that even a horse changing homes must stay within60px of its newly assigned home. S7 explicitly allows excursions between contacts. This semantic fixture now measures held horses against that unchanged resident60px bound and keeps the existing >=80% daylight hitch gate; the independent S7 contact gate is stricter (actual body centre within2px of the grip-derived position). All S5 navigation/physics thresholds remain unchanged. Gramma's Returning state is accepted for genuine habitat relocation; the dedicated S8 hover50 gate remains unchanged.

Latest S7 run remains red: full-cap gorgonian/seagrass reattach30 plus daylight reef3/shipwreck812 and night reef3/shipwreck1. Focused body/feeding still passes7/7; no physics thresholds edited. Reproduce the individual S7 cases before further tuning. S9 red gate confirms both target-distance failures and hard-clamp relocation in shipwreck; see chromis-roost-red.log.

Individual current reef3 trace identifies the last stall mechanism: a horse is clipped at the .8 body-box boundary; its actual velocity becomes0. Landing avoidance used the exact same .8 reaction box, so it considered that stationary boundary outside and generated no dodge. Expanded the landing reaction box to.83 while retaining the hard .8 crossing boundary and unchanged20% assertions. New logs seahorse-anticipation-margin.log/hitch-capacity-margin.log are pending. The focused new-cast world gate now passes53/53 after the resident/travel semantic correction; full world rerun still required.

Checkpoint details: scene data168/168, home geometry8/8, home behaviors16/16, scene switch12/12, save v340/40 and departures10/10 passed on the current habitat revision; clown contract52/52 also passed after explicit sculling correction. The seagrass contact3 adjustment was revised to [32,-70] (x unchanged, y+12), since x+10 crossed shipwreck terrain; all authored hitch-contact obstacle gates pass. Explicit sculling now suppresses the entire forward stroke, including the unintended vertical contribution. Attached horses settle the last <2px gradually at <=scull speed, preserving actual body-spacing and keeping visual tail contact exact. Latest pending S7 logs: seahorse-contact-settle.log/hitch-capacity-contact-settle.log. The goal remains active; this is a development checkpoint, not release acceptance.
