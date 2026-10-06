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
- [x] Night chromis shelter behavior and dawn layer return (128 checks); shared S5 navigation acceptance remains below.
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

Post-checkpoint landing fixes match box avoidance normals to the box controller, set explicit sculling to3.6px/s (within approved3–6 drift speed; cruise4 unchanged), and allow a horse's own contacted obstacle to use its raw boundary rather than the generic2px pad. The last shipwreck seagrass contact's body centre was outside the actual obstacle but inside that pad; `_clear_of` moved its goal another3%, permanently >2px from the true contact. This reproduces the 30-second attachment failure and explains why speed changes did not cure it. Spontaneous hitch routes also reject a destination physically occupied by another species. Fresh results are pending in hitch-capacity-raw-margin.log, seahorse-raw-margin.log; natural-final-homes.log is running on the prior sculling revision and remains diagnostic. No acceptance thresholds changed.

Latest full-cap habitat-change gate passes20/20 on the raw-home-margin correction: both scenes, all four required-plant style choices, reattach<=30s, body overlap<=20%, route validation/restore and deterministic continuation. Eight-seed S7 daylight/night remains running (seahorse-raw-margin.log). Before final S7 sign-off, measure excursion frequency against the approved average-few-minutes behavior: the current.12 chance per60–180s choice averages about16.7 minutes before blocked-route retries; this still needs refinement once route correctness is stable. Also verify compatibility of existing v3 saves with updated authored contact/rock coordinates; current restore preserves serialized home positions and does not yet migrate changed layout anchors.


## Night habitat, persistence and excursion cadence

Implemented S9 derived night swimming bounds with stable shelter targets. The school stays in its daylight band by day, uses an eligible nearby night shelter with a navigable target<=60px, and swims back at dawn before the extended bounds close. Restore derives those bounds without eagerly mutating saved activity/targets. Final `test_chromis_roost` passes128/128 (`test_chromis_roost-roost-final.log`). Focused natural-motion/night/escape checks passed25/25 on the earlier stable night-layer revision (`motion-roost-smoke.log`); the full current suite is pending in `natural-roost-spawn-final.log`.

Added v3 authored-home layout migration and duplicate-home occupancy repair. Migration preserves fish positions, both RNG states, ecology and caller input; current-layout snapshots stay byte-identical. `test_home_layout_restore` passes13/13 (`home-layout-spawn-final.log`), including dawn restore/continuation and the old kelp contact. Current scene_data168, scene_switch12, home_behaviors16, home_geometry8, save_v340 and departures10 all pass (`*-roost-final.log`).

S7 previously passed84/84 after planning each excursion with the candidate home's obstacle margins, but its .12 release probability implied an unacceptable16.7-minute average. Retained the approved few-minute cadence and added an86-check gate with per-scene excursion frequency. The new cadence uses .5 release probability after a hold proportional to the previous trip duration (4x). Initial rest is60s; release/hold timing is serialized and validated. A shortcut's old route-facing could prevent its reverse final approach, so hitch journeys now face their actual remaining leg after an obstacle route ends. The preceding `seahorse-final-approach.log` remains red on shipwreck42 daylight/night and812 daylight. The current full rerun after the spawn correction is `seahorse-spawn-approach-final.log`; do not sign off S7 until it passes all86 and the shared separation/navigation gates.

S5 diagnostic identified soft obstacle overlap at gramma spawn: placement reserved only a centre/pad instead of the actual body envelope. Gramma spawn now clears with its body and own-home exception. Fixed-seed42/2 obstacle subset passes15/15 (`obstacle-soft-spawn.log`), maximum soft overlap.073, zero stuck/flip/relocation. This subset is diagnostic, not full navigation acceptance. Full S8 after this correction passes224/224 (`gramma-spawn-final.log`), both scenes, min/max decor, all8 seeds and3-gramma cap. No thresholds were changed.

CI's core suite list now includes final scene/save/home migration, S6/S7/S8/S9, departure, pacing, cast and art gates. Cloud run dispatch and final scene/decor/feed matrix remain outstanding; the existing long-run checkpoint path still restricts chunked scene/decor to reef/default, which must be completed before the24-case live acceptance can run there. Work is local and uncommitted at this checkpoint; no release or goal completion claimed.


Final S7 current rerun passes86/86 (`seahorse-spawn-approach-final.log`): daylight shares>=.8303, both scenes all night horses hitched, actual grip<=2px, unique homes, all four style/cap/restore checks. Average excursions reef5.85min/shipwreck3.93min. Foodless cadence is unchanged by the subsequent food-arrival guard.

The full natural-motion suite completed78 checks on the preceding food-arrival revision; its sole failure was no seahorse eating. All eight-seed obstacle checks now pass with max soft overlap.073, zero route flips/stuck/raw-centre intrusion/relocation; all night-rest, kinematic, separation and escape assertions pass unchanged. A horse now waits for food already falling toward its mouth before releasing. The feeding fixture's last pinch is sampled beside the current school leader instead of its270-second-old position; every original consumption/overlap assertion is retained. Focused separation/feeding passes7/7 (`body-feeding-cadence-final.log`), all four species eat, max same-species overlap.193 (limit.2). Full final fresh suite is running in `natural-cadence-verified.log`.

Long-run chunked scene/decor support is now implemented, including metadata verification and rejection of habitat-mismatched checkpoints. `test_long_run_chunks` passes43/43 (`chunks-habitat-final.log`): both scenes min/max presets have identical whole/split worlds, reports and tallies. The workflow now supports a single scene/decor config or `acceptance_matrix=true` with the default3seeds generating all24 scene/decor/feed cases. YAML parsing, case generation, unique case keys and scene/decor arguments on all3chunks were checked locally. Cloud dispatch remains outstanding; these are harness proofs, not180-day acceptance results.


Final full natural-motion suite now passes78/78 (`natural-cadence-verified.log`): unchanged S5 physics and kinematic thresholds, all food consumers, eight-seed obstacle grid, night stability and controlled encounters. Broad nav rerun natural_obstacles passes39/39; guard6 remains red on two excess hesitation cases (reef/min240921 2vscontrol0; shipwreck/min2 1vscontrol0); targeted_guard is running (`nav-night-cadence.log`). Investigate those before S5 sign-off.

Closed the production old-cast route in StreamStage and removed unreachable legacy arrival/death branches in StreamEvents/Stage. Superseded transitional animation fixtures now test the final four-species rig behavior (tail contact/clasp/lean, den clipping/rock visibility, nestling, bite events, mirror turns, pause and read-only state). Final animation51/51 and cast-transition41/41 pass, including rejection of old species in snapshots and archived deaths. Frontend80, stage_scenes41, new_fish_art37, mirror_turn49, lifecycle63 and frame_pacer8 pass. These final presentation changes are currently uncommitted.

Presentation regression exposed an overbroad night-layer extension: any edited out-of-band chromis was treated as legitimately returning from a roost. Introduced validated optional boolean `night_returning`; only roost-derived returning schools extend daytime geometry. Decorating a lower night school preserves this flag while clearing invalid roost targets. Scene switches clear it. `test_presentation` now passes25/25, and fresh roost/restore/scene-switch checks are pending in `*-night-return-final.log`. The previous78/78 natural run was before this flag correction; repeat affected night/persistence checks and then the final full matrix if necessary. Fresh full world suite is running in `world-final-cadence.log`.


Latest dawn-state repair verification: presentation25/25, chromis_roost128/128, scene_switch12/12 pass (`*-night-return-final.log`). Strengthened the layout-restore fixture to hold a real below-daylight roost before dawn; added an explicit in-flight `night_returning` checkpoint and byte-identical restore/continuation. `home-layout-real-roost-return.log` now passes15/15. The initial strengthened fixture failed because the school randomly resumed schooling before the dawn checkpoint; the final fixture explicitly holds its resting choice until dawn, matching the intended scenario.

Broad navigation result is final for this run: natural_obstacles39/39; guard6 one failed assertion with reef/min240921 (gramma11 t162.2, gramma12 t441.4) and shipwreck/min2 (gramma11 t251.4); targeted_guard one failed assertion shipwreck/min5 (gramma11 t900.6). No raw intrusion, no-progress, excess route flips, heading, teleport or relocation failures. Retain the hesitation thresholds and inspect `nav-remaining-hesitation.log`, which is currently tracing those exact3cases with the inherited unchanged controller and counters. Current full world run is pending in `world-final-cadence.log`. Clownfish128, contract52 and long-run-chunk43 reruns are pending in `*-cadence-return-final.log`. These processes continue independently in the next goal continuation.
