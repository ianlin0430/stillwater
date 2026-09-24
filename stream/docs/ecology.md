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
- **Yellow tang** (added 2026-09-24) shares the biofilm with the blenny. It swims in its band (120–540 px): `Cruising` trips across the upper midwater (targets y 150–360), `Grazing` with its mouth on one of five rock spots of the approved background (`TANG.spots`, two reef-face groups: left reef x 170–310, right outcrop x 962–1080), `Resting` (mostly at night, when trips are also short). A spot another tang is using or heading to is skipped. It chases drifting food, darts from a tap and is drawn by the lure like the chromis leader. Firefish treat a low-passing tang like a chromis.
- **Purple firefish** live in their own burrow patch on the open sand (`FIRE_BURROWS`, one site per place). They hover `hover_y` (24–40 px, per individual) above the burrow by day and dart inside when a chromis or tang swims just above (`FIRE.dx`/`dy`, the rule the eels had), when a blenny hops past, on a tap and at night. A hovering firefish snatches food drifting past; the lure does not interest them.
- **Green chromis** school in midwater (band 180–430 px). The lowest-id chromis leads and decides trips and rests; the others hold individual slots around it, mirrored with its heading, and hurry back when more than 120 px away, so a tap scatters them and they regroup. They chase drifting food individually; the lure draws the leader and so the school.
- **Garden eel**: removed 2026-09-25 (legacy entry only; see above).

Plant growth, microfauna, detritus, mineralisation, the ocean-current exchange and the boundary ledger are unchanged (daily inputs 0.7 nutrients and 0.35 microfauna). Intake and reproduction use saturating food-response curves; metabolism returns 65% to nutrients and 35% to detritus. Excess offspring disperse explicitly (ledger out). The defensive limit is 24 animals; ordinary arrivals stop at the combined caps (17).

**Rescue** (changed 2026-09-24): a species is rescued from upstream only when one or none is left (`RESCUE_AT`=1), i.e. when it can no longer breed here. It was "two or fewer" when each species had six places; with caps of 3–4, two is half the habitat, and the opening pairs of three species would draw a rescue arrival within days of every opening, so arrivals would fill the places the local young should fill.

## Sizing (offline probe before committing numbers)

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
