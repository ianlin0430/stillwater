# Ecology v2: assumptions and boundaries

Stillwater Reef (renamed from Stillwater Stream in 0.6.0, 2026-09-24) is a curated fictional marine habitat, not a real stocking recommendation or a scientific forecast. The active cast (user decision 2026-09-25, final: no garden eels) is the **lawnmower blenny** *Salarias fasciatus*, the **yellow tang** *Zebrasoma flavescens*, the **green chromis** *Chromis viridis* and the **purple firefish** *Nemateleotris decora*. The **spotted garden eel** *Heteroconger hassi* (2026-09-23 to 2026-09-25) is now a legacy entry like the threadfin. The purple firefish replaced the red firefish (*N. magnifica*, species key `firefish`) the same day; the reef world had only existed on development commits and no save or test fixture held a `firefish`, so that key was removed outright rather than kept as a legacy entry. Salinity, reef chemistry and corals are not modeled.

Removed species stay as legacy entries so older saves load: crayfish (2026-09-22), cherry shrimp and marbled hatchetfish (2026-09-23), threadfin rainbowfish (2026-09-24), spotted garden eel (2026-09-25). When an older save is loaded, each of them still alive is recorded once as a `departure` (material leaves through the ledger, the record goes to the archive with name, parent, sex and any `tint`; an eel keeps its `burrow_x`/`burrow_y`, and its departure event is placed at its burrow); a shrimp still carrying eggs (`brood_until`) leaves with them, and no young are created. Past events stay in the journal. Then, once per save (`reef_cast`), the reef opening cast (2 blennies, 2 purple firefish, 6 chromis, 2 yellow tangs) arrives as ordinary `arrival` events with `live:false`, alternating female/male. Saves from before the garden eels (no `eel_colony`) no longer receive an eel pair; the flag is still accepted. Nothing arrives in the departed eels' place, and garden eels never return (no birth, arrival or rescue).

## Resource pools (display names)

The six material pools keep their internal keys; only the words shown to people changed with the reef: `stem` is shown as **seagrass**, `floating` as **drifting algae**, and the stream exchange (`STREAM_IN`/`STREAM_OUT`) as the **ocean current**. `nutrients`, `biofilm`, `microfauna` and `detritus` keep their names. No save-schema change.

## Cast, food and behaviour

| Species | Pool | Opening / cap | Mature / lifespan (days) | Cost, bite (per day) | Breed (per day), cooldown |
|---|---|---|---|---|---|
| Lawnmower blenny | biofilm | 2 / 3 | 45 / 240 | 0.24, 0.6 | 0.07, 12 d |
| Yellow tang | biofilm | 2 / 2 | 120 / 540 | 0.32, 0.8 | 0.03, 30 d |
| Purple firefish | microfauna | 2 / 4 | 35 / 200 | 0.18, 0.45 | 0.08, 10 d |
| Green chromis | microfauna | 6 / 8 | 30 / 180 | 0.20, 0.5 | 0.10, 8 d |
| (legacy) Spotted garden eel | microfauna | 0 / — | 90 / 365 | 0.22, 0.55 | 0.04, 20 d |

All values are authored, compressed rates (food half-saturation 10 for every species), not measured physiology. Lifespans vary ±15% per individual. The yellow tang is the largest animal (body 1.4, reserve 7.0; the others 0.5–0.8 and 3.5–4.5), lives longest and breeds slowest; its openers are adults (opening age 130–260 days, maturity 120). Each species breaks even at food 10 (cost = 0.8 × bite × f/(f+10)). With `energy ≤ reserve`, a breeding female can afford only one young per breeding event, so the configured brood of 2 only happens when an energy top-up (feeding) pushes her above her reserve (tests set that directly).

- **Blenny** perches, grazes and hops 20–90 px along the bed (its `y` is always the bed), sleeps where it is at night. It pecks up food that has settled on the bed. A tap sends it scooting away along the bed; it ignores the cursor lure. It reopens the biofilm channel that had no grazer since the shrimp left.
- **Yellow tang** (added 2026-09-24) shares the biofilm with the blenny. It swims in its band (120–540 px): `Cruising` trips across the upper midwater (targets y 150–360), `Grazing` with its mouth on one of four rock spots of the approved background (`TANG.spots`, two reef-face groups: left reef x 170–310, right outcrop x 962–1048), body side-on half a body length out (2026-09-26), `Resting` (mostly at night, when trips are also short). A spot another tang is using or heading to is skipped. It chases drifting food, darts from a tap and is drawn by the lure like the chromis leader. Firefish treat a low-passing tang like a chromis.
- **Purple firefish** live in their own burrow patch on the open sand (`FIRE_BURROWS`, one site per place). They hover `hover_y` (24–40 px, per individual) above the burrow by day and dart inside when a chromis or tang swims just above (`FIRE.dx`/`dy`, the rule the eels had), when a blenny hops past, on a tap and at night. A hovering firefish snatches food drifting past; the lure does not interest them.
- **Green chromis** school in midwater (band 180–430 px). The lowest-id chromis leads and decides trips and rests; the others hold individual slots around it, mirrored with its heading, and hurry back when more than 120 px away, so a tap scatters them and they regroup. They chase drifting food individually; the lure draws the leader and so the school.
- **Garden eel**: removed 2026-09-25 (legacy entry only; see above).

Plant growth, microfauna, detritus, mineralisation, the ocean-current exchange and the boundary ledger are unchanged (daily inputs 0.7 nutrients and 0.35 microfauna). Intake and reproduction use saturating food-response curves; metabolism returns 65% to nutrients and 35% to detritus. Excess offspring disperse explicitly (ledger out). The defensive limit is 24 animals; ordinary arrivals stop at the combined caps (17).

**Rescue** (changed 2026-09-24): a species is rescued from upstream only when one or none is left (`RESCUE_AT`=1), i.e. when it can no longer breed here. It was "two or fewer" when each species had six places; with caps of 3–4, two is half the habitat, and the opening pairs of three species would draw a rescue arrival within days of every opening, so arrivals would fill the places the local young should fill.

## Reef v3 cast sizing (S2 of the 2026-09-28 redesign)

Plan: [2026-09-28-redesign-backend.md](plans/2026-09-28-redesign-backend.md) §4.2 and slice S2. The new cast is **green chromis**, **clownfish**, **seahorse** and **royal gramma**, and all four eat `microfauna`. Nothing in `scripts/stream_world.gd` changes in this slice: the numbers below are measured with `tools/cast_probe.gd` on the current world source with the cast constants replaced in memory; S4 puts them into the world.

### Criteria (written and committed 2026-09-28 before any S2 probe was run)

**Fixed before probing (user decisions and design numbers, not results).**

- Opening cast 6/2/2/2 = 12 (chromis/clownfish/seahorse/gramma; user-agreed). Cap sum 15–18 (user-agreed), clownfish cap ≤ 3.
- Habitat limits from the S1 scene data (placeholder coordinates, capacities as committed in `edc79de`): clownfish cap ≤ anemone `capacity` (3 for both anemone styles); seahorse cap ≤ hitches of the smallest required-hitch style (4); gramma cap ≤ `rock_spots` (3 in both scenes). If Codex's alignment changes these capacities, the caps chosen here must still fit them.
- New species (authored design numbers, the same guesses as the plan's pre-probe; every species breaks even at food 10, cost = 0.4 × bite; brood 2, `k_food` 10, pool `microfauna`):

  | Species | Mature / lifespan (days) | Body, reserve | Cost, bite (per day) | Breed (per day), cooldown |
  |---|---|---|---|---|
  | Green chromis (unchanged) | 30 / 180 | 0.5, 3.5 | 0.20, 0.5 | 0.10, 8 d |
  | Clownfish *Amphiprion ocellaris* | 45 / 300 | 0.6, 4.0 | 0.20, 0.5 | 0.06, 12 d |
  | Seahorse *Hippocampus kuda* | 60 / 300 | 0.5, 3.5 | 0.16, 0.4 | 0.05, 14 d |
  | Royal gramma *Gramma loreto* | 40 / 240 | 0.4, 3.0 | 0.16, 0.4 | 0.07, 10 d |

- `OPENING_AGE` = `{"fish":[40,150]}` for all four (the tang entry goes). `RESCUE_AT` = 1, `RESCUE_RATE`, `ARRIVAL_RATE`, plants, `MICRO`, `STREAM_OUT` and `STREAM_IN.nutrients` = 0.7 unchanged. Only `STREAM_IN.microfauna` and the caps are swept. Breeding rates change only if no configuration passes C4/C6 because too few young are produced; then that species' `breed` is raised in steps of ×1.5 and the whole sweep for it is repeated (recorded here, criteria unchanged).

**Measures** (offline, no feeding; `tools/cast_probe.gd`):

- `floor_hits`: animal-minutes in which, after that minute's metabolism, intake and growth, an animal's energy is below 0.1 × its reserve — the floor at which the S4 "never starves" mechanism (plan §4.3) will stop paying metabolism and stop breeding. It is counted on today's ecology, which has no such floor: until the first hit, a world with the mechanism runs the identical trajectory, so `floor_hits` = 0 means the mechanism never engages in that run and the food alone kept every animal off the floor. It also implies no starvation.
- Microfauna minimum over hourly samples; population size and per-species counts over daily samples (after each simulated day).

**Pass criteria, per seed, 180 days** — a configuration passes only if **every one of the 32 `WIDE` seeds** (`tests/seed_lists.gd`) passes all of them:

- **C1** `floor_hits` = 0 (hence starvation 0).
- **C2** microfauna minimum ≥ 10 (the break-even food of every species).
- **C3** population never above the cap sum, and inside [12, cap sum] on ≥ 80% of days.
- **C4** retained births > arrivals.
- **C5** every species present on ≥ 95% of daily samples, no absence longer than 30 days. (This is the pre-redesign presence gate, measured *without* the S4 "never dies out" mechanism; with the mechanism S4 raises it to 100%.)
- **C6** the derived gates of `tests/ecology_acceptance.gd` applied to the candidate constants: old-age deaths ≥ the certain number, the first by its bound, offspring produced ≥ offspring needed. For the fixed opening above (180 days): certain old age = 6 (all six chromis openers: youngest possible ages 40…131.7, + 180 > 207; clownfish/seahorse 40, 95 + 180 < 345; gramma 95 + 180 = 275 < 276), first by day 76 (207 − 131.7), offspring needed = 6 + (cap sum − 12).

**365 days** (chosen configuration only, all 32 seeds): C1, C2, C4 over the whole year, and every species present on day 365.

**Sweep.** Coarse: `STREAM_IN.microfauna` ∈ {0.7, 0.85, 1.0, 1.2} × caps chromis 6–8, clownfish 2–3, seahorse 2–4, gramma 2–3 restricted to cap sum 15–18 (23 combinations), seeds 42/812/240921, 180 days. To save CPU the coarse grid is walked from the edges: every input is first run on the heaviest (8/3/4/3 = 18) and a lightest (sum 15) combination; the remaining combinations are run only where they could still become the choice (an input at which the heaviest passes all coarse seeds leaves the lighter ones as fallbacks only). Fine: the best 3–5 coarse candidates (ranked: all coarse seeds pass, then larger cap sum, then higher worst-seed microfauna minimum) × all 32 seeds × 180 days.

**Choice rule.** Among configurations passing on all 32 seeds: the largest cap sum; among inputs for it, the smallest `STREAM_IN.microfauna` on the grid (the least change to the tuned material budget). The next grid input up is also run on all 32 seeds and recorded as the fallback, because S4 changes the world's RNG draw order and must re-run the 32 seeds itself. No criterion above is loosened after results are seen; if nothing passes, the closest configuration and its failing criteria are reported instead.

### Results (2026-09-28)

Commands (from `stream/`; `s2_sweep.py run` writes the config, runs `godot --headless --path <stream> --script tools/cast_probe.gd -- --config=… --seeds=… --days=… [--mid=180]` and appends one JSON line per seed; `judge` applies C1–C6):

```
python3 tools/probes/s2_sweep.py run --mf=<input> --caps=<chromis,clown,seahorse,gramma> --seeds=<list> --days=180 --log=<file.jsonl>
python3 tools/probes/s2_sweep.py judge <file.jsonl> [--year]
```

The 32 seeds ran as four processes of eight (`WIDE` in order); 180 days take about 12 s per seed, 365 days about 25 s. The chosen configuration is saved as `tools/probes/2026-09-28-s2-chosen.json` (`s2_sweep.py config --mf=1.2 --caps=8,3,4,3`).

**Coarse** (seeds 42/812/240921, 180 days), walked from the edges as written above: the heaviest caps 8/3/4/3 = 18 and the lightest-eating sum-15 caps 6/2/4/3 at every input. Columns: seeds passing all criteria; the seed with the lowest microfauna minimum; the range of minima; the lowest energy/reserve any animal ended a minute with; population range (range of means); retained births / arrivals on the seed where they are closest; failures as `seed(value)`.

| Config (input – caps c/cl/sh/gr) | Seeds | Pass | Worst seed (mf min) | Mf min range | Min energy/reserve | Size range (mean) | Births/arrivals (tightest) | Failures |
|---|---|---|---|---|---|---|---|---|
| mf0.7 – 8/3/4/3 | 3 | 0 | 42 (6.02) | 6.02–8.28 | 0.031 | 12–18 (15.5–16.4) | 9/5 (42) | C1: 42 (52503 floor hits), 812 (58505); C2: all three |
| mf0.85 – 8/3/4/3 | 3 | 1 | 240921 (6.07) | 6.07–10.07 | 0.066 | 12–18 (14.8–16.4) | 10/4 (812) | C1: 240921 (34353); C2: 42 (7.82), 240921 (6.07) |
| mf1.0 – 8/3/4/3 | 3 | 2 | 42 (9.00) | 9.00–11.41 | 0.301 | 12–18 (15.7–16.7) | 12/1 (42) | C2: 42 (9.00) |
| mf1.2 – 8/3/4/3 | 3 | 3 | 42 (12.93) | 12.93–14.22 | 0.326 | 12–18 (16.9) | 8/5 (240921) | — |
| mf0.7 – 6/2/4/3 | 3 | 3 | 42 (11.03) | 11.03–13.30 | 0.326 | 11–15 (13.0–13.9) | 7/1 (240921) | — |
| mf0.85 – 6/2/4/3 | 3 | 3 | 812 (12.93) | 12.93–16.37 | 0.350 | 10–15 (12.9–14.3) | 7/4 (812) | — |
| mf1.0 – 6/2/4/3 | 3 | 3 | 240921 (15.23) | 15.23–18.19 | 0.338 | 11–15 (13.1–14.0) | 7/3 (42) | — |
| mf1.2 – 6/2/4/3 | 3 | 3 | 240921 (17.38) | 17.38–18.94 | 0.337 | 12–15 (14.0–14.4) | 9/2 (42) | — |

The heaviest caps passed all coarse seeds at 1.2, so by the sweep rule the other 21 cap combinations could only be fallbacks and were not run; the sum-15 caps pass at every input but cannot be the choice (smaller cap sum). The input 1.0 is already out for 8/3/4/3 (seed 42: microfauna minimum 9.00), so the smallest grid input for the largest cap sum is 1.2.

**Fine** (all 32 `WIDE` seeds, 180 days):

| Config | Seeds | Pass | Worst seed (mf min) | Mf min range | Min energy/reserve | Size range (mean) | Births/arrivals (tightest) | Failures |
|---|---|---|---|---|---|---|---|---|
| **mf1.2 – 8/3/4/3 (chosen)** | 32 | **32** | 13 (10.89) | 10.89–17.65 | 0.325 | 12–18 (15.5–17.0) | 7/6 (202) | — |
| mf1.35 – 8/3/4/3 (next input up, off the grid) | 32 | 31 | 13 (13.06) | 13.06–20.60 | 0.326 | 10–18 (13.4–17.2) | 10/6 (37) | C3: seed 23, in band on 61% of days (fewest alive 10) |

The grid ends at 1.2, so the "next input up" of the choice rule is 1.35, run off the grid and labelled so. It **fails** C3 on seed 23: more food did not make that seed safer. On that seed the six chromis openers die of old age (all within 207 days, as C6 requires) while only two chromis young were kept and three dispersed, so the chromis fall to 1 and the population to 10–11 for most of the second half. It is a chromis cohort effect, not food (floor hits 0, microfauna minimum 13.1). The same seed at 1.2 passes with chromis never below 4. So 1.35 is **not** a safe fallback, and raising the input is not a fix if S4's own run fails.

Chosen configuration, 180 days, per seed (fewest alive = lowest daily count; `c/cl/sh/gr` = chromis/clownfish/seahorse/gramma):

| seed | floor_hits | min energy/reserve | microfauna min (mean) | size range (mean) | days in [12,18] | retained births / arrivals | dispersed | old age (first day) | fewest alive per species (c/cl/sh/gr) |
|---|---|---|---|---|---|---|---|---|---|
| 42 | 0 | 0.327 | 12.93 (24.3) | 12–18 (16.9) | 100% | 12 / 2 | 40 | 10 (40) | 6/2/2/2 |
| 812 | 0 | 0.326 | 14.22 (23.0) | 12–18 (16.9) | 100% | 12 / 1 | 40 | 8 (34) | 6/2/2/2 |
| 240921 | 0 | 0.327 | 13.86 (27.9) | 12–18 (16.9) | 100% | 8 / 5 | 30 | 8 (35) | 6/2/2/2 |
| 1 | 0 | 0.342 | 15.09 (24.0) | 12–18 (16.9) | 100% | 10 / 2 | 38 | 7 (36) | 6/2/2/2 |
| 2 | 0 | 0.335 | 15.18 (26.2) | 12–18 (16.8) | 100% | 12 / 2 | 30 | 8 (41) | 6/2/2/2 |
| 3 | 0 | 0.334 | 14.93 (26.0) | 12–18 (16.7) | 100% | 13 / 4 | 30 | 12 (49) | 6/2/2/1 |
| 5 | 0 | 0.339 | 16.34 (27.2) | 12–18 (16.4) | 100% | 12 / 4 | 37 | 11 (37) | 6/2/2/1 |
| 7 | 0 | 0.350 | 15.98 (26.1) | 12–18 (16.3) | 100% | 12 / 4 | 36 | 12 (24) | 6/2/2/2 |
| 11 | 0 | 0.327 | 12.79 (26.7) | 12–18 (16.4) | 100% | 10 / 5 | 28 | 10 (66) | 5/2/2/2 |
| 13 | 0 | 0.350 | 10.89 (25.1) | 12–18 (17.0) | 100% | 11 / 3 | 31 | 10 (31) | 6/2/2/2 |
| 17 | 0 | 0.332 | 15.13 (25.7) | 12–18 (16.5) | 100% | 11 / 3 | 35 | 8 (49) | 6/2/2/2 |
| 19 | 0 | 0.329 | 14.81 (24.0) | 12–18 (16.8) | 100% | 10 / 3 | 46 | 8 (14) | 6/2/2/2 |
| 23 | 0 | 0.330 | 11.91 (30.8) | 12–18 (15.8) | 100% | 10 / 3 | 15 | 8 (44) | 4/2/2/2 |
| 29 | 0 | 0.329 | 13.24 (26.3) | 12–18 (16.6) | 100% | 14 / 2 | 28 | 10 (33) | 6/2/2/1 |
| 31 | 0 | 0.329 | 12.95 (27.2) | 12–18 (16.7) | 100% | 11 / 5 | 31 | 10 (37) | 6/2/2/2 |
| 37 | 0 | 0.350 | 16.64 (32.3) | 12–17 (15.5) | 100% | 10 / 6 | 17 | 12 (39) | 6/2/2/2 |
| 101 | 0 | 0.348 | 17.65 (26.7) | 12–18 (16.9) | 100% | 11 / 2 | 31 | 8 (24) | 6/2/2/2 |
| 202 | 0 | 0.328 | 13.23 (27.6) | 12–18 (16.7) | 100% | 7 / 6 | 29 | 7 (39) | 6/2/2/2 |
| 303 | 0 | 0.328 | 13.62 (25.5) | 12–18 (16.9) | 100% | 12 / 3 | 33 | 9 (22) | 6/2/2/2 |
| 404 | 0 | 0.335 | 15.04 (26.7) | 12–18 (16.6) | 100% | 12 / 2 | 29 | 9 (10) | 6/2/2/2 |
| 505 | 0 | 0.325 | 14.30 (26.2) | 12–18 (16.5) | 100% | 12 / 3 | 36 | 10 (23) | 6/2/2/2 |
| 606 | 0 | 0.328 | 15.34 (32.6) | 12–17 (15.9) | 100% | 11 / 5 | 12 | 11 (59) | 6/2/2/2 |
| 707 | 0 | 0.327 | 12.22 (26.6) | 12–18 (16.7) | 100% | 11 / 4 | 25 | 11 (35) | 6/2/2/2 |
| 808 | 0 | 0.326 | 14.26 (26.7) | 12–18 (16.2) | 100% | 12 / 2 | 33 | 12 (44) | 6/2/2/1 |
| 909 | 0 | 0.329 | 14.38 (25.1) | 12–18 (16.7) | 100% | 11 / 2 | 28 | 10 (29) | 6/2/2/1 |
| 1234 | 0 | 0.338 | 12.71 (25.2) | 13–18 (17.0) | 100% | 12 / 3 | 29 | 10 (18) | 6/2/3/1 |
| 4321 | 0 | 0.334 | 16.63 (30.0) | 12–18 (16.2) | 100% | 11 / 4 | 17 | 10 (38) | 6/2/2/2 |
| 9999 | 0 | 0.350 | 14.83 (25.6) | 12–18 (16.9) | 100% | 11 / 3 | 34 | 9 (47) | 6/2/2/2 |
| 31337 | 0 | 0.340 | 15.45 (26.6) | 12–18 (16.7) | 100% | 10 / 3 | 33 | 9 (29) | 6/2/2/2 |
| 65537 | 0 | 0.337 | 15.21 (30.6) | 12–18 (16.0) | 100% | 11 / 3 | 20 | 8 (42) | 5/2/2/2 |
| 123456 | 0 | 0.350 | 11.86 (28.1) | 12–18 (16.8) | 100% | 8 / 6 | 20 | 10 (45) | 5/2/2/2 |
| 999983 | 0 | 0.350 | 14.15 (26.9) | 12–18 (16.7) | 100% | 11 / 2 | 27 | 10 (56) | 6/2/2/2 |

Across the 32 seeds (180 days): births chromis 244 / clownfish 27 / seahorse 38 / gramma 42; dispersed 512 / 142 / 138 / 156; no species was ever absent from a daily sample. The lowest energy of any animal is 0.325 × reserve, the energy a newborn starts with (0.35) less its first minutes. No adult came near the 0.1 floor.

**365 days**, chosen configuration, all 32 seeds (the `at_180` checkpoint of each run equals the 180-day run above exactly): **32/32 pass** (C1 floor hits 0, C2 microfauna minimum ≥ 10, the same worst seed 13 at 10.89, reached within the first 180 days, C4 retained births > arrivals, tightest 18/12 on seed 240921, and every species alive on day 365).

| seed | floor_hits | microfauna min (mean) | size range (mean) | retained births / arrivals | old age | alive on day 365 (c/cl/sh/gr) | fewest alive (c/cl/sh/gr) |
|---|---|---|---|---|---|---|---|
| 42 | 0 | 12.93 (36.1) | 12–18 (16.7) | 22 / 8 | 27 | 8/3/2/2 | 6/1/2/2 |
| 812 | 0 | 14.22 (35.4) | 12–18 (16.5) | 24 / 4 | 24 | 8/3/3/2 | 5/2/2/2 |
| 240921 | 0 | 13.86 (39.1) | 12–18 (16.4) | 18 / 12 | 27 | 7/3/3/2 | 6/2/1/2 |
| 1 | 0 | 15.09 (35.7) | 12–18 (16.6) | 19 / 10 | 24 | 8/2/4/3 | 5/1/2/1 |
| 2 | 0 | 15.18 (37.1) | 12–18 (16.5) | 26 / 4 | 25 | 8/3/3/3 | 6/2/2/2 |
| 3 | 0 | 14.93 (36.9) | 12–18 (16.6) | 21 / 8 | 26 | 7/3/2/3 | 6/1/2/1 |
| 5 | 0 | 16.34 (37.4) | 12–18 (16.5) | 23 / 9 | 26 | 8/3/4/3 | 6/2/2/1 |
| 7 | 0 | 15.98 (37.0) | 12–18 (16.5) | 21 / 10 | 27 | 7/2/4/3 | 6/2/2/2 |
| 11 | 0 | 12.79 (37.0) | 12–18 (16.2) | 17 / 10 | 27 | 5/2/2/3 | 5/2/2/2 |
| 13 | 0 | 10.89 (37.5) | 12–18 (16.8) | 22 / 8 | 25 | 8/3/4/2 | 6/1/2/2 |
| 17 | 0 | 15.13 (38.1) | 12–18 (15.8) | 19 / 7 | 25 | 8/2/1/2 | 6/1/1/1 |
| 19 | 0 | 14.81 (34.9) | 12–18 (16.3) | 22 / 6 | 25 | 8/2/2/3 | 6/2/1/2 |
| 23 | 0 | 11.91 (40.8) | 12–18 (15.7) | 19 / 9 | 24 | 8/3/2/3 | 4/2/1/2 |
| 29 | 0 | 13.24 (37.5) | 12–18 (16.6) | 26 / 6 | 26 | 8/3/4/3 | 5/2/2/1 |
| 31 | 0 | 12.95 (38.5) | 12–18 (16.7) | 19 / 10 | 27 | 8/2/3/1 | 6/1/2/1 |
| 37 | 0 | 16.64 (40.8) | 12–18 (16.1) | 21 / 8 | 25 | 8/2/3/3 | 6/2/2/2 |
| 101 | 0 | 17.65 (37.0) | 12–18 (16.5) | 24 / 3 | 24 | 8/2/3/2 | 5/2/2/2 |
| 202 | 0 | 13.23 (38.8) | 12–18 (16.2) | 20 / 10 | 26 | 8/3/2/3 | 6/1/1/1 |
| 303 | 0 | 13.62 (35.1) | 12–18 (17.0) | 25 / 7 | 27 | 8/3/4/2 | 6/1/2/2 |
| 404 | 0 | 15.04 (39.9) | 12–18 (15.9) | 20 / 8 | 25 | 7/3/2/3 | 5/1/2/1 |
| 505 | 0 | 14.30 (37.0) | 12–18 (16.4) | 22 / 8 | 26 | 7/3/4/2 | 6/1/2/2 |
| 606 | 0 | 15.34 (42.1) | 12–18 (16.1) | 19 / 12 | 26 | 8/3/4/2 | 6/1/2/1 |
| 707 | 0 | 12.22 (38.0) | 12–18 (16.4) | 22 / 8 | 26 | 8/3/2/3 | 6/2/2/2 |
| 808 | 0 | 14.26 (38.7) | 12–18 (15.8) | 21 / 8 | 24 | 8/3/4/2 | 6/2/2/1 |
| 909 | 0 | 14.38 (37.8) | 12–18 (16.4) | 24 / 6 | 24 | 8/3/4/3 | 6/1/2/1 |
| 1234 | 0 | 12.71 (36.7) | 13–18 (16.8) | 23 / 9 | 27 | 8/3/4/2 | 6/2/2/1 |
| 4321 | 0 | 16.63 (44.5) | 9–18 (14.4) | 16 / 8 | 25 | 2/3/3/3 | 1/2/2/2 |
| 9999 | 0 | 14.83 (37.6) | 12–18 (16.5) | 23 / 7 | 26 | 8/3/3/2 | 6/2/1/2 |
| 31337 | 0 | 15.45 (37.7) | 12–18 (16.3) | 23 / 6 | 24 | 8/2/4/3 | 6/2/2/1 |
| 65537 | 0 | 15.21 (40.5) | 12–18 (15.9) | 22 / 8 | 24 | 8/3/4/3 | 5/1/2/2 |
| 123456 | 0 | 11.86 (40.2) | 12–18 (16.4) | 20 / 10 | 24 | 8/3/4/3 | 5/2/1/2 |
| 999983 | 0 | 14.15 (41.3) | 12–18 (15.3) | 17 / 10 | 26 | 4/3/3/3 | 3/1/1/2 |

Not a criterion, but reported: in the second half-year seeds 4321 and 999983 lose most of their chromis (4321: chromis down to 1, population 9–11 for weeks; in band on 85% of days; only five chromis births all year). Seahorse or gramma fall to one on several seeds (fewest alive = 1) and recover. The S4 "never dies out" mechanism covers the last one; the chromis dip is the same cohort effect as seed 23 above.

### Reading and choice

- **Food.** With all four species on microfauna and the old input 0.35 (pre-probe: starvation) the pool cannot carry 18 fish. At caps 8/3/4/3 the pool minimum rises with the input: 0.7 → 6.0–8.3 (animals hit the floor), 0.85 → 6.1–10.1 (floor hits on one seed), 1.0 → 9.0–11.4, 1.2 → 12.9–14.2 on the coarse seeds and 10.89–17.65 over all 32. Before the floor or starvation matters, the pool minimum is the binding criterion (C2): at 1.0 nobody touches the floor on the coarse seeds, but seed 42 dips to 9.00.
- **Chosen: `STREAM_IN.microfauna` = 1.2; caps chromis 8, clownfish 3, seahorse 4, royal gramma 3 = 18; opening 6/2/2/2 = 12; breeding values as authored (unchanged).** It is the largest cap sum allowed (18, and every habitat limit is met: 3 ≤ anemone capacity 3, 4 ≤ 4 hitches, 3 ≤ 3 rock spots) and the smallest grid input at which it passes all 32 seeds, at 180 and at 365 days.
- **Margins, honestly.** The worst microfauna minimum is 10.89 (seed 13), only 0.89 above the break-even, and the closest local-replacement margin is 7 births against 6 arrivals (seed 202). Both are thin. Energy is not thin: no adult got near the floor.
- **No working fallback was found above 1.2** (1.35 fails C3 on seed 23). If S4's own 32-seed run (with the new RNG draw order) fails, the next step is to change a design number for the chromis cohort (for example fewer chromis openers dying together: a wider chromis opening-age span, or a lower chromis cap so fewer young disperse), probe again, and not loosen a gate.
- **Numbers for S4:** `STREAM_IN = {"nutrients":0.7,"microfauna":1.2}`; `CAP = {"green_chromis":8,"clownfish":3,"seahorse":4,"royal_gramma":3}`; `SPECIES` entries for the three new fish exactly as in the criteria table (`initial` 2 each, chromis `initial` 6 and values unchanged); `OPENING_AGE = {"fish":[40.0,150.0]}`; `RESCUE_AT` 1; everything else unchanged. Derived 180-day gates (`tests/ecology_acceptance.gd` will compute them): band [12, 18], at least 6 old-age deaths, the first by day 76, offspring produced ≥ 12 (6 + 18 − 12), retained births > arrivals.
- **Caveats.** These runs use today's `stream_world.gd` with the constants replaced; S4 removes code, adds the two guarantee mechanisms and places animals differently, which changes the RNG draw order, so S4 must re-run the 32 seeds (plan S4 "done" line). `floor_hits` = 0 here means the S4 floor mechanism would not engage on these trajectories. Seahorse and gramma at 4 and 3 depend on the S1 placeholder capacities; if Codex's coordinates reduce them, the caps must drop and be re-probed.
- **Old probe tables and the broken `rescue_at` option (plan risk 9).** The option matched a `<=2` line that the same commit (`edec34c`, 2026-09-24) replaced with `RESCUE_AT`, so it did nothing from then until S0. The 2026-09-24/25 tables (P and Q rows) did not set it (they used the world's `RESCUE_AT` = 1) and are unaffected. The A–C rows of the pre-tang table compare "rescue ≤ 2" with "≤ 1"; whether they were run before that commit cannot be told from the repository, so their rescue column is unverified.

## Sizing (offline probe before committing numbers)

Superseded for the reef v3 cast by the section above; kept as the record of the earlier casts.


`tools/cast_probe.gd` runs the real `stream_world.gd` offline with the cast constants replaced from a JSON file; 180 days × seeds 42/812/240921, no feeding. Totals are over the three seeds unless shown per seed (`a/b/c`). Pools are the minimum over the run (biofilm also the mean).

### Four-species cast without garden eels (2026-09-25, chosen)

The eels' microfauna (cost 0.22/day each) is free for the chromis and firefish. Caps and openings are listed blenny/firefish/chromis/tang. Targets: starvation near zero with no feeding, a lively pool of about 12–18 animals, well under the defensive 24, and pool minima at or above the break-even food 10. Columns are per seed (42/812/240921) except the ranges.

| Configuration | Starvation | Retained births | Dispersed | Arrivals | Old age | First old age (day) | Size range (mean) | Microfauna min | Biofilm min (mean) |
|---|---|---|---|---|---|---|---|---|---|
| Q0: 3/3/6/2 = 14, opening 2/2/5/2 = 11 (eels just removed) | 0/0/0 | 9/9/9 | 25/24/31 | 2/2/3 | 8/9/10 | 40/44/24 | 11–14 (13.3–13.4) | 21.0–22.8 | 14.5–18.4 (18–21) |
| Q1: 3/4/8/2 = 17, opening 2/2/5/2 = 11 | 0/0/0 | 14/11/12 | 26/31/24 | 0/3/3 | 8/11/10 | 40/44/24 | 11–17 (15.8–16.1) | 9.7–10.8 | 18.4–21.8 (24–25) |
| **Q2: 3/4/8/2 = 17, opening 2/2/6/2 = 12 (chosen)** | 0/0/0 | 13/11/13 | 20/30/16 | 1/2/1 | 10/10/10 | 32/34/41 | 12–17 (15.3–15.9) | 12.5–15.5 | 20.0–22.1 (25–26) |
| Q3: 3/4/9/2 = 18, opening 2/2/6/2 | 0/0/0 | 15/11/12 | 18/17/13 | 0/3/3 | 10/9/10 | 32/34/41 | 12–18 (16.4–16.7) | 8.3–9.2 | 21.2–24.3 (26–30) |
| Q4: 3/5/8/2 = 18, opening 2/3/6/2 = 13 | 0/0/0 | 11/12/15 | 27/27/14 | 1/3/2 | 10/12/12 | 31/27/45 | 13–18 (16.1–16.9) | 9.9–10.1 | 21.8–23.2 (25–28) |
| Q5: 3/4/10/2 = 19, opening 2/2/6/2 | 0/0/0 | 15/10/14 | 10/17/10 | 1/4/1 | 10/9/10 | 32/34/41 | 12–19 (16.4–17.4) | 7.8–8.5 | 22.7–24.3 (28–31) |
| Q6: 3/5/10/2 = 20, opening 2/3/7/2 = 14 | 3/0/3 (firefish, chromis) | 14/15/12 | 17/11/5 | 4/1/5 | 12/11/12 | 58/25/45 | 12–20 (15.2–17.2) | 5.1–8.9 | 24.2–25.2 (29–31) |
| Q7: 4/4/9/2 = 19, opening 2/2/6/2 | 0/0/0 | 14/15/13 | 21/21/17 | 2/1/1 | 10/9/10 | 32/34/41 | 12–19 (16.8–17.7) | 8.7–9.4 | 13.7–19.4 (19–23) |
| Q8: 3/4/9/3 = 19, opening 2/2/6/2 | 0/0/0 | 16/11/13 | 18/18/18 | 0/4/4 | 10/9/11 | 32/34/41 | 12–19 (16.8–17.4) | 8.4–12.3 | 13.3–17.1 (20–24) |
| Q2 for 365 days | 0/0/0 | 22/22/25 | 38/51/43 | 7/7/3 | 27/26/25 | 32/34/41 | 12–17 (15.5–15.7) | 12.5–15.5 | 20.0–22.1 (27) |
| Q3 for 365 days | 0/0/0 | 26/21/27 | 42/51/35 | 5/11/5 | 28/26/26 | 32/34/41 | 12–18 (16.3–16.8) | 8.3–9.2 | 21.2–24.3 (29–30) |

Reading: simply dropping the eels (Q0) leaves a quiet pool of 11–14 with microfauna idling above 20. Two more chromis places and one more firefish place (Q1, Q2) use it; Q2 differs from Q1 only by a sixth opening chromis; on these seeds its microfauna minimum is 12.5 instead of 9.7 (observed, not explained further here). Q2 is the largest configuration whose microfauna minimum stays above the break-even 10 on every seed; one more chromis (Q3, Q5), firefish (Q4) or blenny place (Q7) still starves nobody within 180 days but takes a pool below 10, and Q6 starves firefish and chromis. A third tang place (Q8) takes biofilm to 13.3 without starving anyone, but the tang pair stays a pair, as the user asked. Retained births exceed arrivals on every seed (13/11/13 against 1/2/1).

Chosen: **caps 3/4/8/2 = 17, opening 2/2/6/2 = 12, rescue at one** (unchanged `RESCUE_AT`). The sixth opening chromis is named Pearl.

### Five-species cast with the yellow tang (2026-09-24, superseded)

Two grazers now share biofilm (blenny, tang) and three species share microfauna (purple firefish, chromis, eel). Caps are listed blenny/firefish/chromis/eel/tang; the opening is 2/2/5/2/2 = 13 unless shown.

| Configuration | Starvation | Retained births | Dispersed | Arrivals | Size range (mean) | Microfauna min | Biofilm min (mean) |
|---|---|---|---|---|---|---|---|
| P0: 3/3/6/4/3 = 19 | 0/0/0 | 10/10/11 | 12/26/13 | 4/3/4 | 13–19 (16.6–17.2) | 9.7–11.2 | 9.2–16.8 (16–25) |
| **P1: 3/3/6/4/2 = 18 (chosen)** | 0/0/0 | 9/11/9 | 17/21/15 | 3/2/5 | 13–18 (15.9–16.0) | 8.0–10.5 | 22.7–24.4 (28–30) |
| P2: 3/3/5/4/3 = 18, opening 2/2/4/2/2 | 0/0/0 | 9/8/12 | 16/18/18 | 3/5/1 | 12–18 (15.3–16.4) | 11.0–16.8 | 9.6–13.8 (17–20) |
| P3: 2/3/6/4/3 = 18 | 0/0/0 | 10/6/8 | 14/24/14 | 2/5/4 | 13–18 (15.5–16.0) | 7.6–9.7 | 19.8–21.9 (25–27) |
| P4: 3/3/7/4/3 = 20 | 0/0/0 | 12/10/10 | 7/17/10 | 3/5/5 | 13–20 (17.4–17.9) | 6.7–7.6 | 17.7–23.0 (23–28) |
| P5: 4/3/6/4/3 = 20 | 0/2/0 (blenny) | 10/13/11 | 12/24/11 | 5/3/4 | 13–20 (16.9–17.9) | 10.4–11.5 | 5.9–15.9 (14–24) |
| P6: P1 + blenny 4 = 19 | 0/0/0 | 11/10/8 | 14/24/14 | 1/4/2 | 12–19 (15.6–16.9) | 9.9–12.2 | 18.7–21.0 (25–26) |
| P7: P1 + chromis 7 = 19 | 0/1/0 (chromis) | 10/9/8 | 9/22/12 | 2/6/5 | 13–19 (16.5–17.1) | 5.9–7.9 | 23.6–24.6 (28–31) |
| P8: P1 + firefish 4 = 19 | 0/0/0 | 8/11/12 | 13/20/12 | 4/2/2 | 13–19 (16.1–16.6) | 6.3–8.9 | 22.7–24.2 (27–32) |
| P0 for 365 days | 0/0/0 | 17/16/20 | 26/52/27 | 11/11/9 | 12–19 (16.6–16.9) | 9.5–11.2 | 9.2–16.8 (20–27) |
| P1 for 365 days | 0/0/0 | 14/20/19 | 48/41/37 | 12/6/10 | 13–18 (15.6–16.2) | 8.0–10.5 | 22.7–24.4 (29–33) |

Reading: biofilm is the pool the tang puts under pressure. A third tang place (P0) takes the biofilm minimum to 9.2, below the grazers' break-even of 10, and the pool above the 18 target; one more blenny place on top (P5) starves blennies. With two tang places (P1) the biofilm minimum stays at 22.7 and the pool at 13–18. Headroom: one more blenny or firefish place (P6, P8) still starves nobody, one more chromis place (P7) does, so microfauna is the next limit at 19. A pair of tangs cannot retain young while both openers live (they cannot die of old age within a year: the youngest possible opener is 130 days old and lives at least 459), so their young disperse (1–4 per seed in 180 days); that keeps them the "small group" the user asked for. The committed code reproduces P1 exactly (offline 180 days, same three seeds; first old-age death on day 40/44/24).

Chosen: **caps 3/3/6/4/2 = 18, opening 2/2/5/2/2 = 13, rescue at one** (unchanged `RESCUE_AT`).

### Four-species cast before the yellow tang (2026-09-24, superseded)

| Configuration (caps blenny/firefish/chromis/eel; opening 2/2/5/2) | Starvation | Retained births | Arrivals | Size range | Microfauna min |
|---|---|---|---|---|---|
| Previous cast (threadfin 8 + eel 4), for reference | 7/0/7 | 5/5/6 | 7/5/8 | 5–12 | 3.5–4.6 |
| A: 3/4/6/4 = 17, rescue ≤2 | 1/0/0 | 6/7/7 | 9/7/9 | 11–17 | 5.2–7.7 |
| B: 3/3/6/4 = 16, rescue ≤2 | 0/0/0 | 5/7/3 | 9/8/12 | 11–16 | 6.8–7.2 |
| C: 3/3/6/4 = 16, rescue ≤1 | 0/0/0 | 12/6/6 | 2/3/3 | 9–16 | 6.4–7.9 |
| G: C with the breeding rates above (chosen then) | 0/0/0 | 10/10/11 | 3/3/2 | 11–16 | 9.1–9.3 |
| H: G with caps 3/4/7/4 = 18 (headroom check) | 0/1/0 | 9/11/7 | 6/6/6 | 11–18 | 5.7–7.7 |

Rescue at two made arrivals outnumber retained births (B); rescue at one (C) fixed that, and is kept.

## Acceptance gates (re-derived 2026-09-25 for the four-species cast, before any acceptance run of it was looked at)

Computed in `tests/ecology_acceptance.gd` from the configured cast, so they follow the constants rather than any result; `tests/test_world.gd` pins the derived numbers. This derivation was written down (and the pins changed) before the offline acceptance of this cast was run; no gate was changed after. For 180-day runs:

- **Population band [12, 17]** (≥ 80% of days, never above 17): from the opening cast (Σ initial = 2+2+6+2 = 12) to the combined caps (3+4+8+2 = 17), the same rule as before (opening cast to caps). Was [13, 18].
- **Old age ≥ 7, the first by day 76.** Openers get one age per stratum of [40, 150] days (yellow tangs [130, 260]); the youngest possible age in stratum *i* of *n* is `lo + (hi−lo)·i/n`, and no lifespan exceeds 1.15 × the species lifespan. An opener whose youngest possible age + 180 exceeds that maximum must die of old age within the run (unless it starves, which the starvation gate catches):
  - green chromis (now 6 openers), max 207: youngest possible ages 40, 58.3, 76.7, 95, 113.3, 131.7, all + 180 ≥ 220 > 207 → **6**;
  - purple firefish, max 230: 40 (220, no) and 95 (275 > 230) → **1**;
  - lawnmower blenny, max 276: 40 (220) and 95 (275 < 276) → 0, misses by one day;
  - yellow tang, max 621: 130 (310), 195 (375) → 0.

  That is **7** (was 6: the sixth chromis adds one; the eels never added any). The first old-age death is bounded by the smallest `max − oldest youngest-possible age`: chromis 207 − 131.7 = 75.3 → **76**, firefish 135, blenny 181, tang 426 → by day 76 (was 79).
- **Offspring produced (retained births + dispersed young) ≥ 12** = the 7 certain old-age deaths + the 5 places open at the start (17 − 12). Was 11 (6 + 5).
- **Local replacement: retained births > arrivals** (unchanged).
- **Starvation < old age** (unchanged).
- Unchanged and as strict as before: conservation (residual < 1e-5), depth bands (chromis inside 180–430, yellow tang inside 120–540, blennies exactly on the bed, purple firefish exactly at their burrow mouth), predation 0, presence (every active species, now four, ≥ 95% of days, no absence > 30 days), no departures, valid saves, plants > 5% on ≥ 95% of days. The eels' own depth check left with them (they were checked like the firefish).

### Previous gates (2026-09-24, five species with the garden eels, superseded)

Band [13, 18]; old age ≥ 6 by day 79 (5 chromis + the older firefish; blenny missed by one day, eel and tang none); offspring ≥ 11 (6 + 18 − 13); the other gates as above.

## Life cycles, time, determinism and saves

Breeding requires mature mates, sufficient reserves, a species-specific cooldown and a resource-dependent probability; young are born on the spot (blennies on the bed beside the mother, chromis and tangs in their band beside her, purple firefish in a new burrow of their own patch nearest the parent's). Adults do not randomly depart. Low local counts allow rescue arrivals; ordinary immigration is much rarer (1/504 per hour).

The acceptance measure **offspring produced = retained births + dispersed offspring** counts individual young, not breeding attempts. Retained births must independently exceed arrivals, so successful dispersal cannot disguise a population sustained mostly by immigration.

Movement decisions run at 5 Hz; ecological updates use one-minute steps. Ecological time advances the day/night cycle, with local-time correction while the app is visible. The viewing light and inspection do not affect ecology. Seeded repeatability is checked within each mode. Offline ecology is not a promise of identical frame-level encounters.

Reopening or waking advances no more than 72 hours per absence. The evolved state and wall-clock checkpoint commit together. v1 saves upgrade to v2 by adding the new pools (ledger entry) and assigning lifespans; removed species then depart and the reef cast arrives as above. This upgrade does not import the separate old wetland project's saves. The renamed app keeps its saves in a new folder (`app_userdata/Stillwater Reef`), so it starts a fresh world; the old `Stillwater Stream` folder is untouched.

## No predation

Predation was removed by user decision on 2026-09-23: no animal eats another, live or offline. Saves made before keep their `predation` totals, causes, archived deaths and `feeding` events; the total never grows. Starvation, old age and local species absence are possible and are reported, not suppressed.

## Feeding, tapping the glass, the lure (user decision 2026-09-23)

Feeding is never required: without it no food fields appear and no RNG is drawn. A pinch (5 × 0.05 units) enters through `ledger.in`; eaters gain 80% as energy, 20% goes to detritus. Uneaten food settles and becomes detritus after 900 s; four pinches a day is the cap. Chromis and yellow tangs chase drifting food, purple firefish snatch food drifting past their burrow, blennies peck up food that has settled. Tapping the glass and the cursor lure change only short-lived movement, never energy, breeding or resources, and are not saved. Per-species responses are listed in [BACKEND_SNAPSHOT_EVENTS.md](BACKEND_SNAPSHOT_EVENTS.md).

Full rules: [v2 plan](plans/2026-09-22-self-sustaining-ecosystem.md). Measured results: [validation](validation.md).
