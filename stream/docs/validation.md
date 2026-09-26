# Validation — 2026-09-22

**Performance baseline: fish-and-shrimp build 0.4.0 passes the 30-minute packaged foreground performance test. Real Cmd-H and Cmd-M hide/restore checks also pass. Hardware sleep/wake and complete behavioral visual acceptance remain open.**

Blue crayfish were removed at the user's request on 2026-09-22. Their rig, atlases, and diagnostic scene were moved out of the project (to `../stream-crayfish-backup-*/moved/`). Older saves are still readable and record any crayfish as departures.

## Measured results

| Check | Result | Evidence |
|---|---|---|
| Godot version / native platform | 4.6.3; Apple M5; universal (x86_64 + arm64) bundle, `codesign --verify --deep --strict` passes | artifacts/pixel/export-v2.log |
| Core regression suite | 104 checks passed; 72-hour catch-up 0.209 s (concurrent ecological validation) | tests/test_world.gd |
| Swimmer rig suite | 103 checks passed, including head-led fish and shrimp turns that never collapse the whole body edge-on | tests/test_swimmers.gd |
| Three 180-day ecological runs | Seeds 42, 812, 240921 pass all v2 gates; 12–18 animals on 95.6%, 100%, 100% of days | artifacts/six-month-runs.json |
| Resource accounting | 365-day run: residual 4.71e-9 resource units; no species absent on any sampled day | artifacts/six-month-runs.json |
| Earlier build: packaged 60-second QA, window frontmost | 14 animals; mean CPU 10.48% of one core (median 10.1%, one 31.9% sample); peak RSS 216.0 MiB; mean frame 33.4 ms, p95 33.3 ms | artifacts/pixel/release-smoke-process.json |
| User save during QA | `stream.world` unchanged (SHA-1 match before/after) | — |

Process samples use macOS `ps` (100% = one core); RSS is reported in MiB.

## V2 ecology — rerun on 2026-09-22

| Seed | Retained births | Dispersed offspring | Offspring produced | Arrivals | Old age | Starvation | Juvenile predation |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 42 | 23 | 25 | 48 | 7 | 17 | 1 | 11 |
| 812 | 29 | 18 | 47 | 4 | 18 | 0 | 15 |
| 240921 | 27 | 11 | 38 | 5 | 16 | 0 | 16 |

Acceptance now counts **offspring produced = retained births + dispersed offspring ≥ 20**. These are individual offspring, not breeding events. A separate gate still requires retained births > arrivals. This checks reproduction without forcing vacancies by starving animals. Five boundary/regression checks cover this decision. No ecological parameters were changed in this handoff.

All three formal 180-day runs and the 365-day stability run passed. Adults have no random departure rule. Predation affects juvenile shrimp. Seed 42 had one starvation death; this is reported rather than suppressed. The additional 11-seed sweep described in the handoff was not rerun here.

## Motion inspection

`scenes/motion_strip.tscn` follows one animal at true pixel scale (640×360 view) and saves every third drawn frame across cruising, braking, turning, feeding/display and escape. Findings:

- Previous fish and shrimp turns squashed the whole sprite through a one-pixel sliver, which read as a card flip. Turns now lead with the head while the tail (fish) or abdominal segments (shrimp) follow, so the body folds through a bend. The midpoint of a turn is still narrow for one or two frames, because the head is momentarily facing the viewer.
- Threadfin fin filaments are drawn as translucent grey-blue rather than hard black strokes. At true pixel scale they break into short dashes.
- Fish tail-beat amplitude was increased (0.5 + 3.4 × effort world px) because the earlier beat was sub-pixel at normal view.

macOS skips drawing occluded windows. A Godot window hidden behind another app makes recordings freeze and makes CPU samples unrepresentative. The diagnostic advances only on drawn frames, and performance runs must keep the app frontmost.

## Remaining acceptance work

1. Foreground performance completed and passed on 2026-09-22; see the sustained measurement below.
2. Cmd-H and Cmd-M CPU/render-stop/restore checks completed below. Hardware sleep/wake and packaged persistent quit/reopen still need direct lifecycle validation.
3. Scripted normal/1.65× rig recording completed below; natural hiding and predation still require visual coverage.

## Measurement safeguards

QA records visible, hidden and focused seconds separately, plus actual `frame_post_draw` counts. A 30-minute run qualifies only with at least 1,800 visible/focused seconds, under 0.5 hidden seconds, and at least 50,400 drawn frames after warm-up. Merely leaving a process running does not satisfy foreground acceptance. QA mode starts a separate seeded world and does not save over the user world.

## Packaged 0.4.0 smoke checks

- Native universal app exports and strict code-signature verification pass.
- A 180-second QA run completed with 14 animals and zero resource-accounting residual. It recorded 118.9 visible seconds, 58.1 focused seconds, 56.1 hidden seconds, and 3,539 drawn frames. Mean visible process frame interval was 33.66 ms; p95 33.33 ms. It correctly reports `foreground_30_minute_eligible: false`.
- A 50-sample CPU/RSS excerpt averaged 8.35% of one core, peak RSS 76.4 MiB. This is a mixed-visibility excerpt, **not** sustained foreground acceptance. Evidence: `artifacts/pixel/v2-visible-attempt-process.json` and `v2-qa-performance.json`.
- Native UI screenshot confirms fish/shrimp-only composition. UI automation can inspect/raise the window, but did not maintain uninterrupted foreground focus. Minimize was attempted; this is insufficient to certify the full hide/restore lifecycle.
- User world SHA-256 is unchanged after isolated QA; evidence: `artifacts/pixel/v2-save-isolation.json`.
- Thermal pressure spot check was nominal; this is not a sustained thermal or fan-noise result.

This short smoke attempt did not satisfy foreground acceptance; the later sustained measurement below does. Hidden-window checks were subsequently completed below; hardware sleep/wake and persistent quit/reopen remain open. Run at least `--duration=1860` to allow the five-second measurement warm-up before accumulating 30 minutes.

## Sustained foreground acceptance — PASSED

Packaged Stillwater Stream 0.4.0 on Apple M5, 2026-09-22, approximately 18:19–18:50 Asia/Taipei. The app ran for 31 minutes with an isolated QA world. No rendering or ecology changes were made during this run.

| Measurement | Result | Target |
|---|---:|---:|
| Foreground duration after warm-up | 1855.03 s (30 min 55 s) | ≥1,800 s |
| Hidden duration | 0.0 s | No interruption |
| Actual drawn frames | 55,645 (30.00 FPS) | 30 FPS cap |
| Process frame interval: mean / p95 | 33.336 / 33.333 ms | Approximately 33.33 ms |
| Mean CPU, one logical core = 100% | 9.04% | <15% |
| Peak process RSS, including startup | 177.625 MiB (186.3 MB) | <350 MB |
| Thermal pressure | All 63 samples nominal | No thermal pressure observed |
| User world SHA-256 | Unchanged | No QA save modification |

At completion the world held 6 shrimp, 4 threadfin rainbowfish and 4 hatchetfish. Material-accounting residual was -2.84e-14. Both foreground eligibility and CPU/memory acceptance flags are true.

Method: `tools/foreground_acceptance.py` samples process CPU/RSS once per second and macOS thermal pressure every 30 seconds. CPU average uses cumulative process CPU-time change after the first five seconds, divided by measured wall time. Frame intervals are Godot process intervals; actual render counts are separately recorded via `frame_post_draw`. This run measures the starting 14-animal cast. It does not establish worst-case performance at the 24-animal defensive cap, hidden-window CPU, sleep/wake behavior, fan RPM or acoustic noise.

Evidence: `artifacts/performance-30m/results.json` (raw process and thermal samples, flags and save hashes), `qa-performance.json` (app frame/visibility counters), and `runner.log` (progress and completion). The QA app exited normally after measurement; no background service remains.

## Native hide/restore acceptance — PASSED

On the same packaged 0.4.0 app, isolated QA worlds were hidden through macOS UI automation; neither run used `--hidden-test` or `--hide-cycle`.

| Action | Sampling duration | Mean CPU (one core) | Peak RSS | Hidden draw count |
|---|---:|---:|---:|---|
| Cmd-H | 130 one-second samples | 0.329% | 227.6 MiB | Fixed at 548 across 120 s of app progress |
| Cmd-M | 125 one-second samples | 0.271% | 194.0 MiB | Fixed at 391 across the 60 s and 120 s app checkpoints |

Both are below the 1% hidden CPU target. After restoring via the native window Raise action, drawing resumed (first run ended with 6,614 drawn frames; Cmd-M run ended with 1,906). Screenshots confirmed a normal scene, final counters show `suspended_view: false`, and both worlds retained the 6/4/4 species counts. Material residuals remained below 1e-12. User save SHA-256 stayed unchanged during each sampling run.

The first minimize-button attempt resumed drawing almost immediately and **did not pass**; its 10.54% CPU result is retained as `minimize.json`. The repeat used Cmd-M and avoided window inspection during the sampling interval. Native accessibility inspection may reactivate the window; do not certify hidden behavior from the action alone.

Evidence: `artifacts/lifecycle/cmd-h.json`, `cmd-m.json`, `first-run.json`, `cmd-m-restored.json`. Early Cmd-M sampler rows contain the previous QA run's progress file; the 60 s and 120 s checkpoints belong to the new run. CPU is measured from that new process's cumulative CPU time throughout. These checks establish rendering suspension and recovery, not per-individual persistent identity or hardware sleep/wake behavior.

## Recorded swimmer review

`artifacts/motion-review/swimmers-normal-and-close.mp4` contains 1,081 actual drawn frames at 30 FPS (36.03 seconds): 18 seconds normal scale, then 18 seconds at 1.65×. The recorder uses the production rig, shader and artwork but scripted behavior states, so it does not certify ecological encounter presentation. Sequence and limitations are documented in `artifacts/motion-review/README.md`.

Frame inspection covered head/tail turn sequencing, the connected shrimp abdomen during escape, and the full characters fitting the close-view composition. Turns still briefly narrow in the front-facing pose. A clipping problem in the first diagnostic take was corrected by moving the diagnostic hatchetfish down; the production app was unchanged. Recording now advances only after actual draws, and the shrimp scale matches the app's 0.75 scale. Full raw frames and a capture manifest are retained for review.

## 0.4.1 — broader individual roaming (2026-09-23)

The previous shared video was a scripted animation diagnostic, not live ecology. Live movement also sampled only nearby destinations and often replaced them before arrival, making routes look repetitive.

Fish now mix nearby destinations with occasional trips to the opposite side, follow gently bending paths, and have deterministic individual cruise-speed differences. Shrimp occasionally relocate between distant grazing patches or swim to a new patch. Exploratory decisions allow travel time plus a small random margin; arrival still leads to a randomized pause. Nearby routes favor continuing forward and reflect away from the stream edges. Species-specific depth bands and night-time rest remain. Decisions use the persisted motion RNG; no extra per-frame random sampling was introduced.

Three fixed seeds were simulated live for ten daylight minutes each. Median horizontal range across individuals changed from 342 to 834 world units for shrimp, 760 to 922 for threadfin, and 639 to 843 for hatchetfish (see raw before/after reports for exact values). This is a behavior-coverage check, not a claim about biological travel rates. New regression checks enforce bounds, broad exploration and varied individual routes. Core 104 checks and rig 103 checks pass; catch-up was 168 ms.

Evidence: `artifacts/roaming-before.jsonl`, `roaming-after.jsonl`, `roaming-core-tests.log`, and `roaming-rig-tests.log`. The existing 30-minute and hidden-CPU measurements apply to 0.4.0; a full sustained acceptance has not been repeated for 0.4.1. Motion changes can affect proximity-dependent live predation, so offline ecology acceptance alone does not certify identical live encounters.

## 0.5.0 — art integration (2026-09-23)

The fish/shrimp-specific generated background is integrated, replacing the symmetrical crayfish cave composition. Presentation adds restrained bank sway, surface glints, 14 low-opacity motes, fish turn curvature, feeding deformation, and attached male threadfin rays replacing aliased atlas filaments. Full specification and provenance: `ART_DIRECTION.md`, `art-050-provenance.md`.

Rig regression: 103 checks pass. Native import/export and strict ad-hoc signature verification pass. Packaged screenshots were inspected at normal and zoomed views with the viewing light. Short QA runs exercise the rendering path; they do not replace sustained performance acceptance. An intermediate art run overlapped export, so its process samples must not be used as a clean performance result. Full 0.5.0 foreground/hidden performance revalidation is explicitly assigned to Claude after non-art fixes.

Production art files are handed off as a stable baseline. Remaining non-art work and acceptance order: `NON_ART_CLAUDE_PLAN.md`. No new biological tuning or save schema changes were made in this art pass. `artifacts/.gdignore` now prevents mass importing the raw frame recordings.

## 0.5.0 — lifecycle and time-boundary integration (2026-09-23)

Scope of this section: the absence-summary defect and the lifecycle/time-boundary coverage assigned as
step 2 of `NON_ART_CLAUDE_PLAN.md`. The isolated `--persist-qa` mode and the quit/relaunch harness from
step 1 are reused unchanged; **their earlier results are not restated here and were not rerun**. The
0.4.0 performance and hide/restore numbers above remain 0.4.0 results.

### Defect: only the last fragment of an absence was summarised — FIXED

While the window was hidden, `main.gd` advanced the world about once a minute and discarded each
report. On resume it passed only the final leftover to `_set_away`, which drops any report under 120
seconds. Replaying the pre-fix logic against a real `StreamWorld` (seed 42, 600 s hidden, one tick per
second) produced: 10 hidden advances, **600.0 s of stream life actually simulated**, resume report
**0.0 s**, **summary shown: false**. A ten-minute absence therefore showed the user nothing.

`scripts/absence.gd` now accumulates `seconds`, per-event counts and the `capped` flag across every
advance of one absence, and tracks the wall time already simulated so no span is applied twice. The
three hidden-period call sites in `main.gd` (per-minute advance, hidden save, resume) all fold into the
same total, and the summary text moved into the helper so the 120-second floor is under test. No
ecology rate and no save-schema field changed.

### Measured results

| Check | Result | Evidence |
|---|---|---|
| Lifecycle/time-boundary suite (new) | PASSED — 63 checks, 0 failures | `tests/test_lifecycle.gd` |
| Core regression suite | PASSED — 104 checks; 72-hour catch-up 167 ms | `tests/test_world.gd` |
| Swimmer rig suite | PASSED — 103 checks | `tests/test_swimmers.gd` |
| Roaming suite | PASSED — no failures, seeds 42 / 812 / 240921 | `tests/test_roaming.gd` |
| Persist-QA helper suite | PASSED — 27 checks | `tests/test_persist_qa.gd` |
| Packaged hidden → resume run | PASSED — 15 checks | `artifacts/persistence-qa/20260923-011817/` |
| User `stream.world` / `.bak` / `preferences.cfg` | PASSED — SHA-256 unchanged across the whole session | see hashes below |

`tests/test_lifecycle.gd` writes only under `user://lifecycle-test/`, hashes the three real user files
at start and end, and asserts they match. Fault injection (truncated/garbage payloads) is applied only
to files in that directory. Coverage:

- Catch-up over 300 s, 72 h and 18 days through `StreamStore.load_or_create`. The 18-day case advances
  exactly `MAX_AWAY` (259 200 s), reports `capped: true`, and still commits `wall_checkpoint` to the
  real present so the remaining debt is not replayed later.
- Negative elapsed (clock moved back one hour): nothing advances, the checkpoint does not move
  backwards, the state still validates and every identity is intact.
- Corrupted primary with a good backup: recovers from `.bak`, writes back to the primary path, still
  catches up, and preserves identity and lineage.
- Corrupted primary **and** corrupted backup: both files are left byte-identical (SHA-256 compared
  before and after), `preserved` is reported, and a fresh world is written to a separate
  `-recovery-<epoch>.world` file. The user's data is never overwritten or deleted.
- Interruption before the catch-up commit: the on-disk bytes are unchanged, and the next launch replays
  the full hour from the old save, byte-for-byte identical to the interrupted in-memory world.
- Relaunch immediately after the commit: 0 s caught up, elapsed and checkpoint unchanged, same bytes
  rewritten — no double advance.
- Absence accumulator: a 605 s absence split into ten 60 s advances plus the leftover produces exactly
  one 605 s summary, advances the world by exactly 605 s, and is byte-identical to a single
  `advance_offline(605)`. Pause, a backwards clock mid-absence and repeated calls at the same instant
  all advance nothing. An over-long absence caps and keeps the capped flag.

### Packaged hidden → resume run — PASSED

Re-exported after the fix (`--export-release macOS`; `codesign --verify --deep --strict` passes), then
run for real via `python3 tools/persistence_acceptance.py --modes hidden_resume --hidden-seconds 200`.
The app was hidden with `NSRunningApplication.hide` (no Accessibility needed) and unhidden
programmatically. Actual numbers from run `20260923-011817_hidden_resume`:

| Measurement | Value |
|---|---:|
| Confirmed hidden wall time | 203.3 s (`isHidden` true at both ends) |
| Hidden advances folded into one absence | 5 |
| Reported absence | 203.33 s (wall span 203.33 s) |
| World elapsed at hide → at resume | 2.40 s → 205.73 s = **203.33 s advanced** |
| Summary shown | `While you were away: 0.1 hours of stream life` |
| Extra absence reports for the same hide | none |
| Exit after resume | quit event, exit code 0 after 0.2 s, no process left |

Two earlier harness runs in the same artifacts directory are **not** passes and are retained as-is:
`20260923-011555` (an earlier tool version picked up the launch's own brief occlusion instead of the
scripted hide, so it reported a 1.7 s absence and FAILED) and `20260923-011649` (an intentional
`--trigger external` smoke test with a 20 s timeout and nobody acting, which correctly reported
UNVERIFIED then FAILED). Only `20260923-011817` is the accepted run.

Elapsed advanced by exactly the absence length, so the per-minute hidden advances were not re-applied.
In `--persist-qa` mode only, each resume writes `absence-N.json` (since, resumed, advances, seconds,
event counts, elapsed at hide and at resume, the summary text) into the run directory; normal launches
write nothing extra.

### Real machine sleep/wake — UNVERIFIED

Not run. The Mac was deliberately not slept and no energy setting was changed, and suspending the
process is not a substitute for hardware sleep. A ready-to-run procedure is left for the user:

```sh
cd stream
/opt/homebrew/bin/godot --headless --path . --export-release macOS "$PWD/builds/Stillwater Stream.app"
python3 tools/persistence_acceptance.py --modes hidden_resume --trigger external \
        --hidden-seconds 300 --external-timeout 3600
```

The harness launches the isolated persist-QA app, prints `ACTION NEEDED` and writes
`artifacts/persistence-qa/<stamp>/pending-action.json` with the app's pid, then waits (up to
`--external-timeout`) without touching the window. Put the Mac to sleep naturally (Apple menu → Sleep,
or close the lid), leave it asleep for at least `--hidden-seconds`, then wake it and bring Stillwater
back to the front. The harness resumes as soon as the app writes its absence report and checks the same
things as the programmatic run: that several hidden advances were folded into one absence, that the
absence covers the whole wall span, that elapsed advanced exactly once, and that a single summary was
shown. `since` and `resumed` in `absence-N.json` are the before/after wall timestamps; `advances` says
whether catch-up ran once or repeatedly. The user's real save files are only hashed, before and after.

Two related mechanisms also remain UNVERIFIED from step 1 and were not retested here: a real window
close-button click and a real Cmd-Q, because macOS Accessibility permission for the calling process is
denied. `--trigger external` covers those the same way.

### Real window close-button click — PASSED (2026-09-23, manual)

Run `20260923-110938_window_close`: the user launched `persistence_acceptance.py --modes window_close,cmd_q
--trigger external` and clicked the window's close button after 14.2 s. The app logged
`reason: wm_close_request` (visible, focused) and wrote `exit-1.json`. The harness itself was then closed
before its relaunch, so the relaunch and comparison were completed by hand: the same run id was relaunched,
quit with the Apple-event terminate, and `exit-1` was compared with `launch-2`'s pre-catch-up record.
Digest `783223726b64e405…` identical; resources, rng, motion_rng, wall_checkpoint and elapsed equal; 14/14
animals keep id/name/parent/species, none lost; catch-up 50.2 s, not capped; the user's three files hashed
unchanged (values above). No report.json exists for this run because the harness did not finish.

Real Cmd-Q remains UNVERIFIED: the harness was closed before its cmd_q case ran.

### User file hashes (unchanged for this whole session)

```
8fddb7b6338cb76d32385c0e3d8ea0c91df842b006c5ad9c9ed1ffe095587a5c  stream.world
3e0b994531ece6a02306761abc34bd5d0250da15b728a3e992b1e31da0db6b34  stream.world.bak
610b5d9c1e15e49c47db9cfe763d3c14c11ab8535a11c58188f49b66a73bf8f0  preferences.cfg
```

Still open after this step: live ecology validation for the new roaming (step 3), natural event
presentation (step 4), and full 0.5.0 packaged performance acceptance (step 5).

## Predation removed (2026-09-23)

User decision 2026-09-23: no animal eats another, live or offline. `_predation`, `exposure()`, the
nursery constants, `PREY_*`, `OFFLINE_ENCOUNTER` and the `feeding` event were removed; `death` events
no longer carry `target`. Molting shelter, the shrimp `Retreating` startle, births, old age, starvation,
dispersal, rescue arrivals, identities and lineage are unchanged. Save schema unchanged (`VERSION` 2);
`totals.predation` is still required and keeps whatever an older save holds. The long-run gate
`predation 3–20` became `predation == 0` and the `predation_conditions` audit was dropped; no other
threshold changed.

### Local quick suites (macOS, Godot 4.6.3 headless)

| Check | Result | Evidence |
|---|---|---|
| Core regression suite | 已通過 — 106 checks, 0 failures; 72-hour catch-up 308 ms | `tests/test_world.gd` |
| Legacy save with 3 predation deaths + 3 `feeding` events | 已通過 — validates, restores, round-trips through `StreamStore`, keeps the records, `totals.predation` and `causes.predation` stay 3 after one offline day and one live minute, and still validates | `tests/test_world.gd` (`legacy_predation_save`) |
| No predation live (1 800 s) or offline (3 days), hungry fish above exposed shrimplets on a bare bed | 已通過 — `totals.predation` 0, no `predation` cause, no `feeding` event | `tests/test_world.gd` (`no_predation`) |
| Swimmer rig suite | 已通過 — 103 checks | `tests/test_swimmers.gd` |
| Roaming suite | 已通過 — no failures, seeds 42 / 812 / 240921 | `tests/test_roaming.gd` |
| Lifecycle/time-boundary suite | 已通過 — 63 checks; user file hashes unchanged | `tests/test_lifecycle.gd` |
| Persist-QA helper suite | 已通過 — 27 checks | `tests/test_persist_qa.gd` |
| Presentation suite | 已通過 — 26 checks (death event has no `target`) | `tests/test_presentation.gd` |
| Frontend suite (Codex, run read-only) | 已通過 — 10 checks | `tests/test_frontend.gd` |

### Live 180-day ecology (GitHub Actions)

未驗證 — pending the cloud run recorded below.

## Berried shrimp and individual tint (2026-09-23)

User decision 2026-09-23. A mature female shrimp meeting the breeding condition becomes berried
(`berried` event, `brood_until` = elapsed + 5 days) and the brood hatches at the first ecology tick after
that; the brood cost is taken at hatching. The cooldown counts from the berried start and no second brood
starts while berried. Death while berried loses the brood (`death.brood_lost`, no young). Fish breed as
before. Every shrimp carries an appearance-only `tint` in [0,1] from a private `RandomNumberGenerator`
seeded by world seed and id (young: mother ± 0.08, clamped), so `rng` and `motion_rng` are never drawn;
shrimp loaded without one get it on restore. Container `stillwater-stream-1` and `VERSION` 2 unchanged;
both fields optional; `validate()` rejects non-numeric, non-finite, negative `brood_until` and `tint`
outside [0,1]. No acceptance threshold changed; predation gate stays `== 0`.

### Local quick suites (macOS, Godot 4.6.3 headless)

| Check | Result | Evidence |
|---|---|---|
| Core regression suite | 已通過 — 137 checks (106 before + 31 new), 0 failures; 72-hour catch-up 315 ms | `tests/test_world.gd` |
| Berried: 5-day `brood_until`, `berried` event (actor, x/y, live, until), no young at berried, cooldown start | 已通過 | `tests/test_world.gd` (`brood_checks`) |
| Hatch within 60 s after `brood_until`, parent = female; residual < 1e-5; validates | 已通過 | `brood_checks` |
| Save written mid-brood validates, restores `brood_until`, and hatches byte-identically to the unsaved world | 已通過 | `brood_checks` |
| Three consecutive 72-hour `catch_up`s: brood hatches exactly once (all young at one time) | 已通過 | `brood_checks` |
| Death while berried: `brood_lost`, no young over 6 more days, archive has no `brood_until`, material balances | 已通過 | `brood_checks` |
| Seed 42, 30 offline days: every shrimp birth/dispersal falls within 60 s after its mother's `berried.until`; only shrimp are berried | 已通過 | `brood_checks` |
| `tint`: 6 opening shrimp in [0,1] with spread ≥ 0.15; fish have none; deterministic per seed; 50 `_tint` calls leave `rng`/`motion_rng` states unchanged; young within 0.08 of mother | 已通過 | `tests/test_world.gd` (`tint_checks`) |
| Tint never affects ecology: seed 42 with all tints forced to 0 vs normal, 10 live min + 12 offline days + 10 live min, `export_state()` identical after removing `tint` | 已通過 | `tint_checks` |
| Old saves: legacy predation save with tints removed and the v1 fixture validate, restore, get deterministic tints, keep `totals.predation==3` and keep validating after 6 days | 已通過 | `tint_checks` |
| Bad `brood_until` ("soon", −1, NAN) and `tint` (1.5, −0.1, "red") rejected; missing accepted | 已通過 | `brood_checks`, `tint_checks` |
| Against the previous commit's `stream_world.gd` (one-off script, not committed), seeds 42/812/240921: `export_state()` minus `tint` identical at t=0, after 30 live min and after 1 more offline day, `rng` and `motion_rng` states equal (no breeding yet in that span) | 已通過 | one-off comparison, 2026-09-23 |
| Swimmer / roaming / lifecycle / persist-QA / presentation | 已通過 — 103 / no failures (3 seeds) / 63 (user file hashes unchanged) / 27 / 26 | respective suites |
| Frontend suite (Codex, run read-only on Codex's uncommitted tree) | 已通過 — 10 checks | `tests/test_frontend.gd` |

### Live 180-day ecology (GitHub Actions)

未驗證 — pending the cloud run recorded below.

## Shrimp removed (2026-09-23)

User decision 2026-09-23 ("不要蝦子 魚就好"): the pool holds threadfin rainbowfish, marbled hatchetfish
and spotted garden eels only. Caps threadfin 6 / hatchetfish 6 / garden eel 4 (sum 16), opening cast
5 / 5 / 2 (12); ordinary arrivals stop at 16; hard cap 24 unchanged. Shrimp-only code removed: shrimp
movement (`_shrimp_surface`, `Grazing`/`Settling`/`Exploring`/`Retreating`), molting (`molt` events,
`Molting` shelter), berried broods (`_berry`, `BROOD_DAYS`, hatch tick, `brood_lost`), `tint`
(`_tint`, load-time tinting) and `SHRIMP_DETRITUS_K`. Kept: `SPECIES.shrimp` (`initial` 0, not in
`ACTIVE_SPECIES`) for old saves; `validate()` still accepts every legacy field and event; the generic
`relocated_at` mechanism (now only triggered by a fish found outside its layer). Shrimp in a loaded save
leave once as `departure` events (like the crayfish), an unhatched brood is cancelled. No ecological rate
was changed. Long-run population gate: band 14–22 → **11–16** and `max_population ≤ 16`, same ≥ 80 %
share — this follows the cast change (caps 22 → 16), it is not a looser gate; every other gate unchanged,
predation stays `== 0`.

### Local quick suites (macOS, Godot 4.6.3 headless)

| Check | Result | Evidence |
|---|---|---|
| Core regression suite | 已通過 — 162 checks, 0 failures (was 164: 31 brood/tint checks removed, 29 shrimp-departure/fish checks added or rewritten); 72-hour catch-up 126 ms | `tests/test_world.gd` |
| New world: 12 animals, counts `{threadfin 5, hatchet 5, garden_eel 2}`, caps 6/6/4, `spawn("shrimp")` and `spawn("crayfish")` refused | 已通過 | `tests/test_world.gd` |
| Current-format save with 3 live shrimp (one mid-brood with `brood_until`, all with `tint`, one `Molting`) plus one archived dead shrimp and past `berried`/`molt`/`birth` events: validates; on load 0 shrimp, exactly 3 non-live `departure` events in order, fish/eel ids-names-parents-sex unchanged, archive keeps id/name/parent/sex/tint, young→mother lineage kept, brood cancelled (no `brood_until`, no young over 3 more days), earlier dead shrimp and past events still present, `ledger.out` grows by exactly the shrimp mass, residual < 1e-5, validates; a second load adds no departure; same result through `StreamStore` | 已通過 | `tests/test_world.gd` (`shrimp_departure_checks`) |
| `v2-pre-eel.var` (6 tinted shrimp, 1 mid-brood): all 6 depart once, archived with tints and no brood, no births, 2 eels arrive (non-live), fish untouched, residual < 1e-5 | 已通過 | `shrimp_departure_checks`, `eel_checks` |
| `v1-world.var` (8 shrimp + 1 crayfish): upgrade keeps fish ids/names/lineage, 9 departures archived by id, conserves, validates | 已通過 | `ecosystem_checks` |
| 20 offline days from a new world: fish breed; no `tint`, `brood_until`, `molt` or `berried` appears | 已通過 | `shrimp_departure_checks` |
| Swimmer rig suite (Codex rig, unchanged) | 已通過 — 103 checks | `tests/test_swimmers.gd` |
| Roaming suite | **失敗** — 1 failure: "Individuals follow overly uniform routes: threadfin" (seed 812, day: the five threadfin ten-minute spans are 992.6 / 995.0 / 999.1 / 1001.5 / 1010.9 px, spread 18.3 px < 20 px). Every other roaming gate passes on all three seeds. Fish motion code is unchanged; the metric is saturated (every fish crossed essentially the whole ~1 020 px roaming width). Threshold not widened | `tests/test_roaming.gd` |
| Lifecycle/time-boundary suite | 已通過 — 63 checks; user `stream.world` / `.bak` / `preferences.cfg` hashes unchanged | `tests/test_lifecycle.gd` |
| Persist-QA helper suite | 已通過 — 27 checks | `tests/test_persist_qa.gd` |
| Presentation suite | 已通過 — 24 checks (the 2 shrimp molt checks removed; relocation now tested with a fish snapped back into its layer) | `tests/test_presentation.gd` |
| Frontend suite (Codex, run read-only) | 已通過 — 57 checks | `tests/test_frontend.gd` |

### Live 180-day ecology (GitHub Actions)

未驗證 — not triggered yet: the user is re-choosing the final cast (shrimp stay removed), so the
180-day run waits until the cast is final. Resource pools without the grazer are therefore also
未驗證 with a long run. Analytic bound only: with nothing grazing it, biofilm is capped by its logistic
limit 30 + 0.4 × stem (≤ 78 at the stem maximum 120) and returns 3 %/day to detritus; the ledger stays
exact in every local suite (residual < 1e-5). Baseline for comparison (last passing cloud run with
shrimp, run 35826027646 at 3ffccee, live 180 d): biofilm 5.8–27.4, detritus 6.2–17.1, microfauna
6.9–34.7 across seeds 42/812/240921 at 30-day samples.

Cast sizes live only in `StreamWorld.SPECIES[*].initial` and `StreamWorld.CAP`; the arrival limit is
`StreamWorld.habitat_cap()` and the long-run band is `POPULATION_BAND` in `tests/long_run.gd` (the run
fails if its top differs from `habitat_cap()`). `tests/test_world.gd` pins the cast in one check.


## Threadfin + garden eel cast — unfed pool fails, root cause found (2026-09-24)

Cloud runs on `6c2910d` (live, 180 days): **fed daily** (run 35896803318) passes every gate on seeds 42/812/240921; **unfed** (run 35896796999) fails — starvation 7/0/7, births 5/5/6, `reproduction`, `local_replacement` and `old_age` fail on all seeds, `population` (8–12 share 0.678) on seed 42. Feeding code is not the cause: with no food the world is byte-identical to the pre-feeding commit.

Root cause, by evidence (no parameters changed):
1. **Starvation — the provisional threadfin cap of 8 exceeds what microfauna can feed.** A threadfin breaks even at microfauna ≈ 11.5 (cost 0.3/day = 0.8 × bite 0.7 × m/(m+10)). Offline probe, 3 seeds × 180 days: cap 8/start 6 + eels → 14 starvation deaths, microfauna min 3.5; cap 8/start 6 without eels → 11, min 4.0; **cap 5/start 5 + eels → 0**, min 10.1. The eels are not the driver. Threadfin breed up to the cap while microfauna is high, then draw it below break-even.
2. **Reproduction-type gates were carried by shrimp.** Offline on the shrimp-era commit `3ffccee`, shrimp produced 10–11 of the 15–17 retained births per seed; threadfin and hatchetfish together produced 5–6. The current unfed births (5–6) are the normal fish rate, so "≥20 offspring", local replacement and the old-age gates are cast-dependent and need redesign for a fish-only cast rather than a lower number.
3. **The biofilm food channel is orphaned.** With shrimp, biofilm averaged 18–24; now it sits at its cap (~47–48) because nothing grazes it, while every animal competes for microfauna. A biofilm grazer (e.g. a snail) would reopen that channel and raise carrying capacity.

Status: 失敗（未修）. Parameters and gates are deliberately left unchanged until the final cast is chosen (user decision 2026-09-24).

## Stillwater Reef cast — sizing, gates and local checks (2026-09-24)

Cast: lawnmower blenny (biofilm), firefish, green chromis and spotted garden eel (microfauna); threadfin dropped. Caps 3/3/6/4 = 16, opening 2/2/5/2 = 11, rescue only at one or none. Sizing probe (`tools/cast_probe.gd`, offline, unfed, seeds 42/812/240921) and the derived gates are in [ecology](ecology.md) ("Sizing", "Acceptance gates"); the gates were computed from the configured cast and committed (`4d0675a`) before any live run of this cast was judged.

Offline 180 days on the committed code (identical to probe G): starvation 0/0/0, old age 9/9/10 (first on day 40/44/24), retained births 10/10/11, dispersed 17/13/11 (offspring 27/23/22), arrivals 3/3/2, population 11–16 every day. 365 days offline: starvation 0/0/0, births 19/15/18, arrivals 7/11/7. These are offline numbers, not the live acceptance.

Local suites on `4d0675a` (headless): test_world 309/309, test_swimmers 103/103, test_roaming pass (chromis school: pair separation ≤ 0.111 of the width, turn IQR 0.48–0.75, no edge or band-rim hugging, night slower and more resting), test_lifecycle 63/63, test_persist_qa 27/27, test_presentation 29/29. test_frontend (Codex's, with Codex's uncommitted edits in the tree) fails 2 checks plus index errors: its fixtures pick a `threadfin` that no longer exists and the stage presents only threadfin/hatchet — the reef rigs are Codex's work. Old saves: v1, pre-eel v2 (shrimp + hatchetfish), hatchet-era and threadfin-era fixtures (real saves written by `f4db093` and `fdf54e4`) validate, their removed species depart once, the reef cast arrives once (`live:false`), material balances, and a second load changes nothing.

Cloud (live, 180 days, seeds 42/812/240921, on `4d0675a`): unfed run 35957509294, fed daily run 35957512152 — both **cancelled** after 58 minutes, no result (superseded by the five-species cast below).

## Five-species reef cast: yellow tang, purple firefish — sizing, gates, local checks (2026-09-24)

User decision 2026-09-24 (final): garden eel, lawnmower blenny, **yellow tang** (new, biofilm), green chromis, **purple firefish** (replaces the red firefish; key `firefish` → `purple_firefish`, *Nemateleotris decora*). Commits: `8ed0374` (rename), `5dbc38b` (yellow tang), `801a727` (sizing + gates, derivation in [ecology](ecology.md) committed before the cloud runs were triggered), this docs commit.

Chosen: caps blenny/firefish/chromis/eel/tang **3/3/6/4/2 = 18**, opening **2/2/5/2/2 = 13**, rescue at one, hard cap 24 unchanged. Probe table (offline, unfed, 180 and 365 days × seeds 42/812/240921) in [ecology](ecology.md) "Sizing". Gates re-derived from the configured rates: band **[13, 18]** (was [11, 16]); old age **≥ 6 by day 79** (unchanged: 5 chromis + the older purple firefish; the tang cannot die of old age within 180 days); offspring **≥ 11** (= 6 + (18 − 13), unchanged); all other gates unchanged, the tang's depth band 120–540 is audited like the chromis band.

Red firefish removal: no user save and no fixture held `firefish` (checked: `tests/fixtures/*.var` contain no `firefish`; `app_userdata/Stillwater Reef` holds no world save, only `qa-performance-hidden.json`, listed by name, not opened). So no legacy entry was kept and no fixture needed changing.

### Local quick suites (macOS, Godot 4.6.3 headless, on `801a727`)

| Check | Result | Evidence |
|---|---|---|
| Core regression suite | 已通過 — 333 checks, 0 failures (was 309/310); 72-hour catch-up 257 ms | `tests/test_world.gd` |
| Purple firefish key/label/latin, red `firefish` key gone (`SPECIES`, `HOMES`, `spawn("firefish")` refused) | 已通過 | `firefish_checks` |
| Yellow tang: definition (biofilm, largest body, longer life/slower breeding than chromis, break-even at 10, pair / cap 2, adult openers) | 已通過 | `tang_checks` |
| Yellow tang behaviour, 30 min by day (seed 42): always in band 120–540; only `Cruising`/`Grazing`/`Resting`; grazing only at a `TANG.spots` point with `contact_x/contact_y`, body 22 px out, facing the rock, contact fields absent otherwise; crosses > 400 px; night mostly `Resting`; eats biofilm; chases food; tap → `Startled` away inside band; lure → `Curious`; young born in band / disperse when full; arrivals at the edge in band; non-numeric `contact_x` rejected; conservation and validation | 已通過 | `tang_checks` |
| Old saves (v1, pre-eel v2, hatchet-era, threadfin-era fixtures): removed species depart once, reef cast incl. 2 yellow tangs arrives once (`live:false`), material balances, second load changes nothing | 已通過 | `reef_cast_checks` |
| Roaming (3 seeds, day/night 30 min): chromis school unchanged; yellow tang spans 973–1013 px, pair separation 0.347–0.453, turn IQR 0.72–0.78, edge 0, rim ≤ 0.002, night distance 1 686–2 585 vs day 22 350–26 266 px, night resting 0.95–0.97 | 已通過 | `tests/test_roaming.gd` |
| Swimmer rig suite | 已通過 — 103 checks | `tests/test_swimmers.gd` |
| Lifecycle / time-boundary | 已通過 — 63 checks | `tests/test_lifecycle.gd` |
| Persist-QA helper | 已通過 — 27 checks | `tests/test_persist_qa.gd` |
| Presentation read-only | 已通過 — 29 checks | `tests/test_presentation.gd` |
| Frontend suite (Codex's, uncommitted edits in the tree, run read-only) | **失敗** — 42 checks, 2 failures ("Cruising fish render within 25% of true speed", fixed and jittered frames: 0 frames measured) plus 3 index errors. The same result on the pre-change backend `42c9ff7` with the same frontend files (temporary worktree), so not caused by this change (the cause inside the frontend test/stage was not examined further). Codex's file, not edited | `tests/test_frontend.gd` |
| Offline 180 days on the committed code | 已通過（offline, not the acceptance）— identical to probe P1: starvation 0/0/0, births 9/11/9, dispersed 17/21/15, arrivals 3/2/5, old age 10/9/11 (first day 40/44/24), size 13–18 every day, microfauna min 8.0–10.5, biofilm min 22.7–24.4 | `tools/cast_probe.gd` |
| `long_run.gd` smoke (1 live day, seed 812): depth audit covers the tang, 312 checks, 0 violations | 已通過（smoke only） | `tests/long_run.gd` |

### Live 180-day ecology (GitHub Actions)

未驗證 — triggered on `801a727`: unfed run [35963646036](https://github.com/ianlin0430/stillwater/actions/runs/35963646036), fed daily run [35963649344](https://github.com/ianlin0430/stillwater/actions/runs/35963649344). Both ended within seconds with no job started; GitHub's annotation: "The job was not started because recent account payments have failed or your spending limit needs to be increased." That is an account billing setting for the user; the runs must be re-triggered after it is resolved (same commands). No live result of this cast exists yet.


## Four-species reef: garden eels removed, resize, firefish spacing, `ate` event (2026-09-25)

User decision 2026-09-25 (final): no garden eels. Commits: `f423e9f` (eel removal, sizing, gates — the gate derivation in [ecology](ecology.md) was written and pinned in `tests/test_world.gd` in the same commit, before the acceptance below was run), `54c4fec` (firefish burrow spacing, tang spot exclusion), `a75442c` (`ate` event), this docs commit.

Chosen: caps blenny/firefish/chromis/tang **3/4/8/2 = 17**, opening **2/2/6/2 = 12**, rescue at one, hard cap 24. Probe table (offline, unfed, 180 and 365 days × seeds 42/812/240921, nine configurations) in [ecology](ecology.md) "Sizing". Gates re-derived from the configured cast: band **[12, 17]** (was [13, 18]); old age **≥ 7 by day 76** (was ≥ 6 by 79: the sixth opening chromis adds one certain death and moves the bound); offspring **≥ 12** (= 7 + (17 − 12)); every other gate unchanged; the eels' burrow depth check left with them.

Old saves: the threadfin-era and hatchet-era fixtures hold live garden eels — each departs once (`live:false`, at its burrow, archived with `burrow_x`/`burrow_y`), nothing arrives in their place, a second load changes nothing; the pre-eel and v1 fixtures get the reef cast and no eels. The user's `app_userdata/Stillwater Reef` has no world save (`test_lifecycle` reports `stream.world`, `.bak` and `preferences.cfg` as missing); neither it nor `Stillwater Stream` was opened or changed.

### Local quick suites (macOS, Godot 4.6.3 headless, on `a75442c`)

| Check | Result | Evidence |
|---|---|---|
| Core regression suite | 已通過 — 333 checks, 0 failures; 72-hour catch-up 133 ms | `tests/test_world.gd` |
| Cast pin: 4 species, caps 3/4/8/2 = 17, opening 2/2/6/2, `spawn("garden_eel")` refused, `garden_eel` legacy only (not in `ACTIVE_SPECIES`/`CAP`/`HOMES`/`REEF_CAST`) | 已通過 | `_initialize`, `eel_checks` |
| Save with 2 live eels + past eel events: validates; 2 non-live departures at the burrows, archive keeps id/name/sex/burrow, `ledger.out` grows by exactly their mass, residual < 1e-5, second load no change, 3 offline days + 10 live minutes no eel returns; eel fields (`burrow_x`, `extend`, `eel_colony`) still validated | 已通過 | `eel_checks` |
| Derived gates pinned (7 old age by day 76, 12 offspring, band 12–17) | 已通過 | `_initialize` |
| Firefish burrows 650/540/760/410: pairwise ≥ 91 + 16 px and no overlap of hovering adult art boxes (`ReefRig.LOOK`) at hover 24 or 40; all on the open sand (x 210–440, 505–940 of the approved background, read off `background-v1.png` scaled to 1280×720); > 48 px from every tang spot and hold point; no overlap with any grazing tang body; opening pair at 650 and 540; patch fills to 4, then disperses | 已通過 | `firefish_checks` |
| Tang grazing: 30 min by day, whenever both tangs graze their 122×87 art boxes never intersect (327 overlapping ticks before the fix); with one tang holding each spot, 400 choices of the other never pick an overlapping spot; grazing tang holds within 6 px of its hold point (also checked on seeds 812/240921/7, 0 misses) | 已通過 | `tang_checks` |
| `ate` events: one per pellet eaten live, actor id/x/y, `food_id`, `food_x/food_y` within reach; each pellet once; empty text, not in `recent`, not in `totals`; none for full fish, settled decay or offline; firefish bites at the burrow with the pellet above it; blenny pecks beside the pellet; three fed days keep ≤ 10 `ate` events while older events stay | 已通過 | `feeding_checks`, `firefish_checks`, `blenny_checks` |
| Swimmer rig suite | 已通過 — 103 checks | `tests/test_swimmers.gd` |
| Roaming suite (3 seeds, day/night, chromis school now 6) | 已通過 | `tests/test_roaming.gd` |
| Lifecycle / time-boundary | 已通過 — 63 checks | `tests/test_lifecycle.gd` |
| Persist-QA helper | 已通過 — 27 checks | `tests/test_persist_qa.gd` |
| Presentation read-only | 已通過 — 29 checks | `tests/test_presentation.gd` |
| Frontend suite (Codex's, run read-only; Codex had uncommitted edits in the tree) | 已通過 — 79 checks | `tests/test_frontend.gd` |
| Reef animation suite (Codex's) | 已通過 — 25 checks, with Codex's uncommitted edit that counts `world.state.animals.size()`; on the committed version (`63472e0`'s file) it **failed** 1 check, "shows eleven fish", because the opening is now 12 — not edited by Claude | `tests/test_reef_animation.gd` |

### Offline 180-day acceptance (`tests/long_run.gd --mode=offline --days=180 --seeds=42,812,240921 --year=false`)

已通過 — both modes, `ACCEPTANCE PASS`, every gate on every seed. Run on `f423e9f` and again on `a75442c` with identical results (spacing and `ate` do not touch offline ecology). Offline is not the live acceptance.

| Feed | Seed | Births | Dispersed | Offspring (≥ 12) | Arrivals | Old age (≥ 7) | First old age (≤ 76) | Starvation | Band share [12,17] | Max | Min presence | Max residual | Pinches | Detritus max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 42 | 13 | 20 | 33 | 1 | 10 | 32 | 0 | 1.000 | 17 | 1.00 | 1.8e-09 | 0 | 12.45 |
| none | 812 | 11 | 30 | 41 | 2 | 10 | 34 | 0 | 1.000 | 17 | 1.00 | 1.4e-09 | 0 | 13.27 |
| none | 240921 | 13 | 16 | 29 | 1 | 10 | 41 | 0 | 1.000 | 17 | 1.00 | 2.4e-09 | 0 | 12.36 |
| daily | 42 | 15 | 51 | 66 | 1 | 11 | 32 | 0 | 1.000 | 17 | 1.00 | 3.2e-09 | 720 | 14.04 |
| daily | 812 | 13 | 42 | 55 | 0 | 9 | 34 | 0 | 1.000 | 17 | 1.00 | 3.1e-09 | 720 | 14.25 |
| daily | 240921 | 11 | 34 | 45 | 2 | 11 | 41 | 0 | 1.000 | 17 | 1.00 | 3.7e-09 | 720 | 15.93 |

Depth audit is live-only (0 checked offline). Plants > 5 % on every day of every run.

### Live 180-day ecology (GitHub Actions)

未驗證 — not triggered (GitHub Actions billing is blocked; the main session will run it). No live result of the four-species cast exists yet.

## Tang grazes side-on; chromis rest without bobbing (2026-09-26)

User feedback: the grazing yellow tang looked squashed (body centre only 22 px from the rock contact, so the frontend foreshortened it), and green chromis bobbed up and down while resting at night (about 2.5–5.5 times a minute).

- Tang: `TANG.reach` 22 → 61 px (half the 122 px adult body) × `animal_scale` (juvenile 30.5 px); body centre at `(contact_x + side × reach × scale, contact_y)`, facing the rock. Spots rechecked on `artifacts/reef-review/background-normal.png`: old spot 3 (240, 472) removed (body over the reef ledges; the other ledge tips put a grazing tang over firefish burrows 410/540), right outcrop spot (1080, 486) moved to the rock's left face (1048, 496). Four spots; 3/4 (right) exclusive. A chromis aiming inside a grazing tang's avoid ellipse aims at its rim (the grazing tang now sits in open water; without this, seed 42's worst daytime chromis flip rate in `test_roaming` rose from 1.97 to 3.9/min, over the 3.0 gate).
- Chromis: night `Resting` leader rests where it is; slot breathing is horizontal only; follower Resting/Schooling hysteresis 20/40 px; a resting chromis within `CHROMIS.hold` = 10 px of its spot stops steering to it and keeps its facing; resting spacing is sideways only and does not push the leader; `_avoid` steering eased 0.3 per tick (was 0.5: a 2-tick up/down limit cycle against an approaching cruising tang, 140 flips in 30 min on seed 240921 after the rest changes).
- Old saves: a tang grazing a removed/moved spot stays until its graze ends (checked: seed 42 save grazing at (240, 472) → `Cruising` at 15 s, validates).

### Local suites (macOS, Godot 4.6.3 headless)

| Suite | Result |
|---|---|
| `test_world` | 已通過 — 333 checks (tang hold check now `_tang_hold(spot, scale)`; firefish-vs-tang check uses the real hide rule `FIRE.dx`/`FIRE.dy` at adult and juvenile holds) |
| `test_swimmers` | 已通過 — 103 checks |
| `test_roaming` | 已通過 — day chromis max flips 0.1 / 0.17 / 1.43 per min (seeds 42 / 812 / 240921) |
| `test_lifecycle` | 已通過 — 63 checks |
| `test_persist_qa` | 已通過 — 27 checks |
| `test_presentation` | 已通過 — 29 checks |
| `test_natural_motion` | 已通過 — 38 checks. Tang grazing (3 seeds × 20 min, one juvenile per world): 2738 adult / 2723 juvenile grazing ticks, worst hold error 5.68 px (5 px arrival + coasting; gate 6), min facing cos 0.951. Night rest (3 seeds × 10 min): unprovoked vertical reversals 0.01/min; including giving way to a passing tang, mean 0.24, worst 0.94/min (before: mean 1.92, worst 4.06). Tang overlap max 0.006; chromis through tang max 0.291 |
| `test_frontend` (Codex) | 已通過 — 80 checks |
| `test_reef_animation` (Codex) | 已通過 — 41 checks |

### Offline 180-day acceptance (`--mode=offline --days=180 --seeds=42,812,240921 --year=false`)

已通過 — both modes `ACCEPTANCE PASS`; numbers identical to the four-species table above (offline ecology does not use motion).

| Feed | Seed | Births | Dispersed | Arrivals | Old age | First old age | Starvation | Band | Max | Max residual | Pinches | Detritus max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 42 | 13 | 20 | 1 | 10 | 32 | 0 | 1.000 | 17 | 1.8e-09 | 0 | 12.45 |
| none | 812 | 11 | 30 | 2 | 10 | 34 | 0 | 1.000 | 17 | 1.4e-09 | 0 | 13.27 |
| none | 240921 | 13 | 16 | 1 | 10 | 41 | 0 | 1.000 | 17 | 2.4e-09 | 0 | 12.36 |
| daily | 42 | 15 | 51 | 1 | 11 | 32 | 0 | 1.000 | 17 | 3.2e-09 | 720 | 14.04 |
| daily | 812 | 13 | 42 | 0 | 9 | 34 | 0 | 1.000 | 17 | 3.1e-09 | 720 | 14.25 |
| daily | 240921 | 11 | 34 | 2 | 11 | 41 | 0 | 1.000 | 17 | 3.7e-09 | 720 | 15.93 |

### Live 2-day check (`--mode=live --days=2 --seeds=42,812,240921`, local, 119 s)

Every seed: 0 births/deaths/arrivals, max 12, band 1.000, all species present, depth audit 576 checks / 0 violations, residual 2.3e-13, detritus max 7.38, plants > 5 %. The script prints `ACCEPTANCE FAIL` only for the 180-day gates (reproduction, local replacement, old age, starvation < old age), which two days cannot meet. The three seeds gave identical summaries. The live 180-day run is still 未驗證.
