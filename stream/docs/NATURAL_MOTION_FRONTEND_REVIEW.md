# Natural motion frontend candidate — 2026-09-26

Latest instruction in CODEX_START_HERE governs this pass: smooth, comfortable animation, not extra biological realism. Existing fish textures are unchanged. Garden eel remains out of scope.

## Implemented, awaiting user visual acceptance

- Consume optional heading/pitch/speed/thrust/turn/roll/flick; interpolate each 0.2-second snapshot across rendered frames. Legacy heading comes from direction, other fields default to zero.
- Heading's cosine continuously narrows and reverses the body; removed the old abrupt minimum-width sign switch. Tail follows the head with delay and turn-based bend. No simulation positions are changed.
- Thrust rises with a 0.14-second smoothing constant and settles with 0.24 seconds. Stroke phase integrates this softened effort, so coasting eases out. A tiny, slow breath remains without a fixed idle swimming cycle.
- Free swimmers have a bounded visual follow-through offset (at most 1.8 px horizontally / 1.2 vertically), eased back toward the backend position. Grazing contact does not receive this offset.
- Chromis pectoral strokes follow effort; tail amplitude also reads speed. Tang uses backend pitch/roll and continuous turns before grazing. Firefish balances with pitch, has a damped dorsal flick return and faster withdrawal with thrust. Blenny's thrust pulse triggers one eased hop arc; it no longer loops jumps throughout travel. Planted fins remain still on the substrate.
- No extra scale/fin-ray artwork, muscle details, eye darting or decorative jitter was added.

## Evidence

`artifacts/natural-motion-review/`: one 12-second top/bottom BEFORE/AFTER clip per species, all at 1.65×, plus exact backend traces and README. A bounded deterministic search selects windows containing each characteristic action; both versions use identical real backend data and camera. Before source comes from `1b12e4a`. Purple firefish receives a real tap eight seconds into the clip; all other actions are autonomous. Review tool: `tools/natural_motion_review.gd`.

Observed ranges: chromis heading 0–π, thrust 0–1; tang heading 0–3.10, roll 0–0.35; blenny thrust 0–1; firefish flick 0–1 and withdrawal. Still frames were checked for attachment, contact, readable silhouette and matching scale. User must judge the motion itself before §3.8 is accepted. The new renderer is in source; no new normal-mode application launch or user-save operation was performed in this pass.

## Validation status

- Passed `test_frontend`: 80 checks, 0 failures.
- Passed `test_reef_animation`: 38 checks, 0 failures. Added snapshot-sequence turn continuity, relaxed stroke shutdown, legacy defaults and dorsal-flick return; updated old tests to supply backend thrust/heading instead of assuming activity names alone drive motion.
- Passed `test_natural_motion`: 30 checks, 0 failures (Claude-owned test unchanged).
- Passed `test_presentation`: 29 checks, 0 failures; simulation remains read-only.
- Backend files, saves and main lifecycle code unchanged.
- Formal packaged foreground/hidden/thermal acceptance is not established by these tests. Only a bounded rendering cost sample is performed here, after recording completes. §3.8 visual approval is pending; do not call the entire plan complete.

Short cost sample: Apple M5, 960×540, 12 fish, 30 ps samples, mean CPU **13.26% of one core**, peak RSS **252.77 MiB**. Explicit draw calls with `--disable-render-loop` produced **1,138 frames / 38.346 seconds** (~29.7 FPS), without recording or simultaneous tests/export. This is a source-preview rendering benchmark, not packaged foreground/hidden or thermal acceptance. Evidence: `artifacts/natural-motion-review/process.json`, `render-benchmark.json`, `benchmark.log`.
