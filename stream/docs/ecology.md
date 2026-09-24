# Ecology v2: assumptions and boundaries

Stillwater Reef (renamed from Stillwater Stream in 0.6.0, 2026-09-24) is a curated fictional marine habitat, not a real stocking recommendation or a scientific forecast. The active cast (user decision 2026-09-24) is the **lawnmower blenny** *Salarias fasciatus*, the **firefish** *Nemateleotris magnifica*, the **green chromis** *Chromis viridis* and the **spotted garden eel** *Heteroconger hassi*. Salinity, reef chemistry and corals are not modeled.

Removed species stay as legacy entries so older saves load: crayfish (2026-09-22), cherry shrimp and marbled hatchetfish (2026-09-23), threadfin rainbowfish (2026-09-24). When an older save is loaded, each of them still alive is recorded once as a `departure` (material leaves through the ledger, the record goes to the archive with name, parent, sex and any `tint`); a shrimp still carrying eggs (`brood_until`) leaves with them, and no young are created. Past events stay in the journal. Then, once per save (`reef_cast`), the reef opening cast of the three new species (2 blennies, 2 firefish, 5 chromis) arrives as ordinary `arrival` events with `live:false`, alternating female/male; saves from before the garden eels also receive their eel pair first, as before. Resident garden eels keep their identity and burrow.

## Resource pools (display names)

The six material pools keep their internal keys; only the words shown to people changed with the reef: `stem` is shown as **seagrass**, `floating` as **drifting algae**, and the stream exchange (`STREAM_IN`/`STREAM_OUT`) as the **ocean current**. `nutrients`, `biofilm`, `microfauna` and `detritus` keep their names. No save-schema change.

## Cast, food and behaviour

| Species | Pool | Opening / cap | Mature / lifespan (days) | Cost, bite (per day) | Breed (per day), cooldown |
|---|---|---|---|---|---|
| Lawnmower blenny | biofilm | 2 / 3 | 45 / 240 | 0.24, 0.6 | 0.07, 12 d |
| Firefish | microfauna | 2 / 3 | 35 / 200 | 0.18, 0.45 | 0.08, 10 d |
| Green chromis | microfauna | 5 / 6 | 30 / 180 | 0.20, 0.5 | 0.10, 8 d |
| Spotted garden eel | microfauna | 2 / 4 | 90 / 365 | 0.22, 0.55 | 0.04, 20 d |

All values are authored, compressed rates (food half-saturation 10 for every species), not measured physiology. Lifespans vary ±15% per individual. Each species breaks even at food 10 (cost = 0.8 × bite × f/(f+10)). With `energy ≤ reserve`, a breeding female can afford only one young per breeding event, so the configured brood of 2 only happens when an energy top-up (feeding) pushes her above her reserve (tests set that directly).

- **Blenny** perches, grazes and hops 20–90 px along the bed (its `y` is always the bed), sleeps where it is at night. It pecks up food that has settled on the bed. A tap sends it scooting away along the bed; it ignores the cursor lure. It reopens the biofilm channel that had no grazer since the shrimp left.
- **Firefish** live in their own burrow patch (x 388–484) left of the eel colony (x 548–786, at least 60 px from every eel site). They hover `hover_y` (24–40 px, per individual) above the burrow by day and dart inside when a chromis swims just above (the eel rule), when a blenny hops past, on a tap and at night. A hovering firefish snatches food drifting past; the lure does not interest them.
- **Green chromis** school in midwater (band 180–430 px). The lowest-id chromis leads and decides trips and rests; the others hold individual slots around it, mirrored with its heading, and hurry back when more than 120 px away, so a tap scatters them and they regroup. They chase drifting food individually; the lure draws the leader and so the school.
- **Garden eel** unchanged: fixed burrows, `Swaying`/`Retracted`/`Sleeping`, retract when a chromis passes just above.

Plant growth, microfauna, detritus, mineralisation, the ocean-current exchange and the boundary ledger are unchanged (daily inputs 0.7 nutrients and 0.35 microfauna). Intake and reproduction use saturating food-response curves; metabolism returns 65% to nutrients and 35% to detritus. Excess offspring disperse explicitly (ledger out). The defensive limit is 24 animals; ordinary arrivals stop at the combined caps (16).

**Rescue** (changed 2026-09-24): a species is rescued from upstream only when one or none is left (`RESCUE_AT`=1), i.e. when it can no longer breed here. It was "two or fewer" when each species had six places; with caps of 3–4, two is half the habitat, and the opening pairs of three species would draw a rescue arrival within days of every opening, so arrivals would fill the places the local young should fill.

## Sizing (offline probe before committing numbers)

`tools/cast_probe.gd` runs the real `stream_world.gd` offline with the cast constants replaced from a JSON file; 180 days × seeds 42/812/240921, no feeding. Totals are over the three seeds unless shown per seed (`a/b/c`). Microfauna is the minimum/mean over the run.

| Configuration (caps blenny/firefish/chromis/eel; opening 2/2/5/2) | Starvation | Retained births | Arrivals | Size range | Microfauna min |
|---|---|---|---|---|---|
| Previous cast (threadfin 8 + eel 4), for reference | 7/0/7 | 5/5/6 | 7/5/8 | 5–12 | 3.5–4.6 |
| A: 3/4/6/4 = 17, rescue ≤2 | 1/0/0 | 6/7/7 | 9/7/9 | 11–17 | 5.2–7.7 |
| B: 3/3/6/4 = 16, rescue ≤2 | 0/0/0 | 5/7/3 | 9/8/12 | 11–16 | 6.8–7.2 |
| C: 3/3/6/4 = 16, rescue ≤1 | 0/0/0 | 12/6/6 | 2/3/3 | 9–16 | 6.4–7.9 |
| G: C with the breeding rates above (chosen) | 0/0/0 | 10/10/11 | 3/3/2 | 11–16 | 9.1–9.3 |
| G for 365 days | 0/0/0 | 19/15/18 | 7/11/7 | 11–16 | 8.8–9.3 |
| H: G with caps 3/4/7/4 = 18 (headroom check) | 0/1/0 | 9/11/7 | 6/6/6 | 11–18 | 5.7–7.7 |

Reading: the previous failure was the cap, not the eels (reproduced here: starvation 7/0/7, the cloud unfed result). With the reef cast, 16 places feed without starvation on every seed, and starvation first appears at 18, so the chosen caps keep two animals of headroom. Rescue at two made arrivals outnumber retained births (B); rescue at one (C) fixed that. The chosen breeding rates (G) keep births ahead of arrivals and keep microfauna near break-even at its lowest. Biofilm, now grazed, averages about 37–39 (min 31) instead of sitting at its cap.

Chosen: **caps 3/3/6/4 = 16, opening 2/2/5/2 = 11, rescue at one.**

## Acceptance gates (derived 2026-09-24, before any live run of this cast was judged)

Computed in `tests/ecology_acceptance.gd` from the configured cast, so they follow the constants rather than any result. For 180-day runs:

- **Population band [11, 16]** (≥ 80% of days, never above 16): from the opening cast (Σ initial = 11) to the combined caps (16), the same rule as before (opening cast to caps).
- **Old age ≥ 6, the first by day 79.** Openers get one age per stratum of [40, 150] days (eels [100, 220]); the youngest possible age in stratum *i* of *n* is `lo + (hi−lo)·i/n`, and no lifespan exceeds 1.15 × the species lifespan. An opener whose youngest possible age + 180 exceeds that maximum must die of old age within the run (unless it starves, which the starvation gate catches): all 5 chromis (40 + 180 = 220 > 207) and the older firefish (95 + 180 = 275 > 230); the older blenny misses by one day (275 vs 276) and the eels cannot. That is 6. The oldest chromis opener is at least 128 days old and lives at most 207, so the first old-age death comes by day 79 at the latest. (Was ≥ 5 by day 60 for the threadfin cast.)
- **Offspring produced (retained births + dispersed young) ≥ 11** = the 6 certain old-age deaths + the 5 places open at the start (16 − 11): local young must be able to fill the pool and replace every opener that has to die. (Was ≥ 20 when shrimp produced most of the young.)
- **Local replacement: retained births > arrivals** (unchanged).
- **Starvation < old age** (unchanged).
- Unchanged and as strict as before: conservation (residual < 1e-5), depth bands (chromis inside 180–430, blennies exactly on the bed, eels and firefish exactly at their burrow mouth), predation 0, presence (every species ≥ 95% of days, no absence > 30 days), no departures, valid saves, plants > 5% on ≥ 95% of days.

## Life cycles, time, determinism and saves

Breeding requires mature mates, sufficient reserves, a species-specific cooldown and a resource-dependent probability; young are born on the spot (blennies on the bed beside the mother, eels and firefish in a new burrow of their own patch nearest the parent's). Adults do not randomly depart. Low local counts allow rescue arrivals; ordinary immigration is much rarer (1/504 per hour).

The acceptance measure **offspring produced = retained births + dispersed offspring** counts individual young, not breeding attempts. Retained births must independently exceed arrivals, so successful dispersal cannot disguise a population sustained mostly by immigration.

Movement decisions run at 5 Hz; ecological updates use one-minute steps. Ecological time advances the day/night cycle, with local-time correction while the app is visible. The viewing light and inspection do not affect ecology. Seeded repeatability is checked within each mode. Offline ecology is not a promise of identical frame-level encounters.

Reopening or waking advances no more than 72 hours per absence. The evolved state and wall-clock checkpoint commit together. v1 saves upgrade to v2 by adding the new pools (ledger entry) and assigning lifespans; removed species then depart and the eel pair and reef cast arrive as above. This upgrade does not import the separate old wetland project's saves. The renamed app keeps its saves in a new folder (`app_userdata/Stillwater Reef`), so it starts a fresh world; the old `Stillwater Stream` folder is untouched.

## No predation

Predation was removed by user decision on 2026-09-23: no animal eats another, live or offline. Saves made before keep their `predation` totals, causes, archived deaths and `feeding` events; the total never grows. Starvation, old age and local species absence are possible and are reported, not suppressed.

## Feeding, tapping the glass, the lure (user decision 2026-09-23)

Feeding is never required: without it no food fields appear and no RNG is drawn. A pinch (5 × 0.05 units) enters through `ledger.in`; eaters gain 80% as energy, 20% goes to detritus. Uneaten food settles and becomes detritus after 900 s; four pinches a day is the cap. Chromis chase drifting food, garden eels and firefish snatch food drifting past their burrow, blennies peck up food that has settled. Tapping the glass and the cursor lure change only short-lived movement, never energy, breeding or resources, and are not saved. Per-species responses are listed in [BACKEND_SNAPSHOT_EVENTS.md](BACKEND_SNAPSHOT_EVENTS.md).

Full rules: [v2 plan](plans/2026-09-22-self-sustaining-ecosystem.md). Measured results: [validation](validation.md).
