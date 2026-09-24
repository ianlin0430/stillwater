# Ecology v2: assumptions and boundaries

Stillwater Reef (renamed from Stillwater Stream in 0.6.0, 2026-09-24) is a curated fictional marine habitat, not a real stocking recommendation or a scientific forecast. The active cast (user decision 2026-09-24, final) is the **spotted garden eel** *Heteroconger hassi*, the **lawnmower blenny** *Salarias fasciatus*, the **yellow tang** *Zebrasoma flavescens*, the **green chromis** *Chromis viridis* and the **purple firefish** *Nemateleotris decora*. The purple firefish replaced the red firefish (*N. magnifica*, species key `firefish`) the same day; the reef world had only existed on development commits and no save or test fixture held a `firefish`, so that key was removed outright rather than kept as a legacy entry. Salinity, reef chemistry and corals are not modeled.

Removed species stay as legacy entries so older saves load: crayfish (2026-09-22), cherry shrimp and marbled hatchetfish (2026-09-23), threadfin rainbowfish (2026-09-24). When an older save is loaded, each of them still alive is recorded once as a `departure` (material leaves through the ledger, the record goes to the archive with name, parent, sex and any `tint`); a shrimp still carrying eggs (`brood_until`) leaves with them, and no young are created. Past events stay in the journal. Then, once per save (`reef_cast`), the reef opening cast of the four new species (2 blennies, 2 purple firefish, 5 chromis, 2 yellow tangs) arrives as ordinary `arrival` events with `live:false`, alternating female/male; saves from before the garden eels also receive their eel pair first, as before. Resident garden eels keep their identity and burrow.

## Resource pools (display names)

The six material pools keep their internal keys; only the words shown to people changed with the reef: `stem` is shown as **seagrass**, `floating` as **drifting algae**, and the stream exchange (`STREAM_IN`/`STREAM_OUT`) as the **ocean current**. `nutrients`, `biofilm`, `microfauna` and `detritus` keep their names. No save-schema change.

## Cast, food and behaviour

| Species | Pool | Opening / cap | Mature / lifespan (days) | Cost, bite (per day) | Breed (per day), cooldown |
|---|---|---|---|---|---|
| Lawnmower blenny | biofilm | 2 / 3 | 45 / 240 | 0.24, 0.6 | 0.07, 12 d |
| Yellow tang | biofilm | 2 / 2 | 120 / 540 | 0.32, 0.8 | 0.03, 30 d |
| Purple firefish | microfauna | 2 / 3 | 35 / 200 | 0.18, 0.45 | 0.08, 10 d |
| Green chromis | microfauna | 5 / 6 | 30 / 180 | 0.20, 0.5 | 0.10, 8 d |
| Spotted garden eel | microfauna | 2 / 4 | 90 / 365 | 0.22, 0.55 | 0.04, 20 d |

All values are authored, compressed rates (food half-saturation 10 for every species), not measured physiology. Lifespans vary ±15% per individual. The yellow tang is the largest animal (body 1.4, reserve 7.0; the others 0.5–0.9 and 3.5–5.0), lives longest and breeds slowest; its openers are adults (opening age 130–260 days, maturity 120). Each species breaks even at food 10 (cost = 0.8 × bite × f/(f+10)). With `energy ≤ reserve`, a breeding female can afford only one young per breeding event, so the configured brood of 2 only happens when an energy top-up (feeding) pushes her above her reserve (tests set that directly).

- **Blenny** perches, grazes and hops 20–90 px along the bed (its `y` is always the bed), sleeps where it is at night. It pecks up food that has settled on the bed. A tap sends it scooting away along the bed; it ignores the cursor lure. It reopens the biofilm channel that had no grazer since the shrimp left.
- **Yellow tang** (added 2026-09-24) shares the biofilm with the blenny. It swims in its band (120–540 px): `Cruising` trips across the upper midwater (targets y 150–360), `Grazing` with its mouth on one of five rock spots of the approved background (`TANG.spots`, two reef-face groups: left reef x 170–310, right outcrop x 962–1080), `Resting` (mostly at night, when trips are also short). A spot another tang is using or heading to is skipped. It chases drifting food, darts from a tap and is drawn by the lure like the chromis leader. Eels and firefish treat a low-passing tang like a chromis.
- **Purple firefish** live in their own burrow patch (x 388–484) left of the eel colony (x 548–786, at least 60 px from every eel site). They hover `hover_y` (24–40 px, per individual) above the burrow by day and dart inside when a chromis swims just above (the eel rule), when a blenny hops past, on a tap and at night. A hovering firefish snatches food drifting past; the lure does not interest them.
- **Green chromis** school in midwater (band 180–430 px). The lowest-id chromis leads and decides trips and rests; the others hold individual slots around it, mirrored with its heading, and hurry back when more than 120 px away, so a tap scatters them and they regroup. They chase drifting food individually; the lure draws the leader and so the school.
- **Garden eel** unchanged: fixed burrows, `Swaying`/`Retracted`/`Sleeping`, retract when a chromis passes just above.

Plant growth, microfauna, detritus, mineralisation, the ocean-current exchange and the boundary ledger are unchanged (daily inputs 0.7 nutrients and 0.35 microfauna). Intake and reproduction use saturating food-response curves; metabolism returns 65% to nutrients and 35% to detritus. Excess offspring disperse explicitly (ledger out). The defensive limit is 24 animals; ordinary arrivals stop at the combined caps (18).

**Rescue** (changed 2026-09-24): a species is rescued from upstream only when one or none is left (`RESCUE_AT`=1), i.e. when it can no longer breed here. It was "two or fewer" when each species had six places; with caps of 3–4, two is half the habitat, and the opening pairs of three species would draw a rescue arrival within days of every opening, so arrivals would fill the places the local young should fill.

## Sizing (offline probe before committing numbers)

`tools/cast_probe.gd` runs the real `stream_world.gd` offline with the cast constants replaced from a JSON file; 180 days × seeds 42/812/240921, no feeding. Totals are over the three seeds unless shown per seed (`a/b/c`). Pools are the minimum over the run (biofilm also the mean).

### Five-species cast with the yellow tang (2026-09-24)

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

## Acceptance gates (re-derived 2026-09-24 for the five-species cast, before any live run of it was judged)

Computed in `tests/ecology_acceptance.gd` from the configured cast, so they follow the constants rather than any result; `tests/test_world.gd` pins the derived numbers. The derivation below was written down and committed before the cloud runs of this cast were triggered. For 180-day runs:

- **Population band [13, 18]** (≥ 80% of days, never above 18): from the opening cast (Σ initial = 2+2+5+2+2 = 13) to the combined caps (3+3+6+4+2 = 18), the same rule as before (opening cast to caps). Was [11, 16].
- **Old age ≥ 6, the first by day 79.** Openers get one age per stratum of [40, 150] days (garden eels [100, 220], yellow tangs [130, 260]); the youngest possible age in stratum *i* of *n* is `lo + (hi−lo)·i/n`, and no lifespan exceeds 1.15 × the species lifespan. An opener whose youngest possible age + 180 exceeds that maximum must die of old age within the run (unless it starves, which the starvation gate catches):
  - green chromis, max 207: youngest possible ages 40/62/84/106/128, all + 180 ≥ 220 > 207 → **5**;
  - purple firefish, max 230: 40 (220, no) and 95 (275 > 230) → **1**;
  - lawnmower blenny, max 276: 40 (220) and 95 (275 < 276) → 0, misses by one day;
  - garden eel, max 419.75: 100 (280), 160 (340) → 0;
  - yellow tang, max 621: 130 (310), 195 (375) → 0.

  That is **6**, unchanged: the tang adds no certain death. The first old-age death is bounded by the smallest `max − oldest youngest-possible age`: chromis 207 − 128 = **79**, firefish 135, blenny 181, eel 259.75, tang 426 → by day 79, unchanged.
- **Offspring produced (retained births + dispersed young) ≥ 11** = the 6 certain old-age deaths + the 5 places open at the start (18 − 13). Unchanged in value (was 6 + (16 − 11)).
- **Local replacement: retained births > arrivals** (unchanged).
- **Starvation < old age** (unchanged).
- Unchanged and as strict as before: conservation (residual < 1e-5), depth bands (chromis inside 180–430, yellow tang inside 120–540, blennies exactly on the bed, eels and purple firefish exactly at their burrow mouth), predation 0, presence (every species, now five, ≥ 95% of days, no absence > 30 days), no departures, valid saves, plants > 5% on ≥ 95% of days. The tang's band is a new check of the same kind (it comes from `StreamWorld.DEPTH`), not a looser one.

## Life cycles, time, determinism and saves

Breeding requires mature mates, sufficient reserves, a species-specific cooldown and a resource-dependent probability; young are born on the spot (blennies on the bed beside the mother, chromis and tangs in their band beside her, eels and purple firefish in a new burrow of their own patch nearest the parent's). Adults do not randomly depart. Low local counts allow rescue arrivals; ordinary immigration is much rarer (1/504 per hour).

The acceptance measure **offspring produced = retained births + dispersed offspring** counts individual young, not breeding attempts. Retained births must independently exceed arrivals, so successful dispersal cannot disguise a population sustained mostly by immigration.

Movement decisions run at 5 Hz; ecological updates use one-minute steps. Ecological time advances the day/night cycle, with local-time correction while the app is visible. The viewing light and inspection do not affect ecology. Seeded repeatability is checked within each mode. Offline ecology is not a promise of identical frame-level encounters.

Reopening or waking advances no more than 72 hours per absence. The evolved state and wall-clock checkpoint commit together. v1 saves upgrade to v2 by adding the new pools (ledger entry) and assigning lifespans; removed species then depart and the eel pair and reef cast arrive as above. This upgrade does not import the separate old wetland project's saves. The renamed app keeps its saves in a new folder (`app_userdata/Stillwater Reef`), so it starts a fresh world; the old `Stillwater Stream` folder is untouched.

## No predation

Predation was removed by user decision on 2026-09-23: no animal eats another, live or offline. Saves made before keep their `predation` totals, causes, archived deaths and `feeding` events; the total never grows. Starvation, old age and local species absence are possible and are reported, not suppressed.

## Feeding, tapping the glass, the lure (user decision 2026-09-23)

Feeding is never required: without it no food fields appear and no RNG is drawn. A pinch (5 × 0.05 units) enters through `ledger.in`; eaters gain 80% as energy, 20% goes to detritus. Uneaten food settles and becomes detritus after 900 s; four pinches a day is the cap. Chromis and yellow tangs chase drifting food, garden eels and purple firefish snatch food drifting past their burrow, blennies peck up food that has settled. Tapping the glass and the cursor lure change only short-lived movement, never energy, breeding or resources, and are not saved. Per-species responses are listed in [BACKEND_SNAPSHOT_EVENTS.md](BACKEND_SNAPSHOT_EVENTS.md).

Full rules: [v2 plan](plans/2026-09-22-self-sustaining-ecosystem.md). Measured results: [validation](validation.md).
