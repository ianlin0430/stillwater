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
