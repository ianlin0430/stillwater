# Ecology v2: assumptions and boundaries

Stillwater Stream is a curated fictional freshwater habitat, not a real stocking recommendation or a scientific forecast. The active cast is threadfin rainbowfish, marbled hatchetfish and spotted garden eels (a marine fish, kept in this freshwater stream on purpose; salinity is not modeled). The user removed crayfish (2026-09-22) and cherry shrimp (2026-09-23): when an earlier stream save is loaded, each crayfish or shrimp in it is recorded once as a departure (its material leaves through the ledger, its record goes to the archive with name, parent, sex and any `tint`), and the remaining individuals are preserved. A shrimp still carrying eggs (`brood_until`) leaves with them: the brood is cancelled, no young are created, and since its cost was never taken no extra material moves. Past shrimp events (`berried`, `molt`, births, deaths) stay in the journal.

## Life cycles

The opening population is five threadfins, five hatchetfish and a mature pair of garden eels (12). Illustrative maturity ages are 28 days for the two swimming fish and 90 days for garden eels. Illustrative lifespans are 180 days for the swimming fish and 365 days for garden eels, independently varied by ±15% at creation. Opening ages are staggered: fish 40–150 days, eels 100–220 days. These deliberately compressed rates let local generations and natural deaths become observable over months.

Breeding requires mature mates, sufficient reserves, a species-specific cooldown and a resource-dependent probability; young are born on the spot. Nothing broods, molts or carries a `tint` any more (those were shrimp-only). Space permits up to six threadfins, six hatchetfish and four garden eels (user decision 2026-09-23, after the shrimp left; previously eight shrimp, five of each fish and four eels). Excess offspring explicitly disperse downstream. The defensive active-individual limit is 24; ordinary worlds remain at or below the combined habitat limit of 16, and ordinary arrivals stop at 16. Adults do not randomly depart. Low local species counts allow rescue arrivals; ordinary immigration is much less frequent.

The acceptance measure **offspring produced = retained births + dispersed offspring** counts individual young, not breeding attempts or broods. Both components remain visible in reports. Retained births must independently exceed arrivals, so successful dispersal cannot disguise a population sustained mostly by immigration.

## Food and plants

Six resource-equivalent material pools are modeled: dissolved nutrients, rooted plants, floating plants, biofilm, microfauna and detritus. Light supplies energy rather than material. Plant growth transfers nutrients into plants, limited by light, nutrient concentration and carrying capacity. Floating plants shade the submerged pools; rooted plants increase the surface available to biofilm. Small, explicitly accounted stream seed inputs prevent permanent plant loss.

All three species consume microfauna. Since the shrimp left nothing grazes biofilm: it is bounded by its own carrying capacity (30 + 0.4 × rooted plants) and returns material to detritus through its 3%/day mortality. Detritus is consumed by microfauna and mineralizes; see [validation](validation.md) for the measured pools without the grazer. Intake and reproduction use saturating food-response curves. Metabolism returns 65% of consumed reserves to nutrients and 35% to detritus. Dead microfauna return half their material to nutrients and half to detritus; detritus also mineralizes. Incoming stream material, outflow, immigration and offspring dispersal are recorded in the boundary ledger. Body mass and energy reserves participate in the same bookkeeping. This is a conservation model, not detailed aquatic chemistry.

Current calibration: daily stream inputs are 0.7 nutrient units and 0.35 microfauna units. Floating-plant growth/mortality coefficients are 1.3/0.025 per day; the food half-saturation constant is 10 for every species (it was 6 for shrimp). These are authored model parameters, not measured species physiology.

Plant amounts currently exist in the simulation and read-only snapshots. The painted pixel background does **not** yet change with plant biomass. No plant art, resource dashboard, fluid solver, oxygen model or management interaction was added in this stage.

## No predation; recovery

Predation was removed by user decision on 2026-09-23: no animal eats another, live or offline. Every species only eats microfauna. The nursery, the stem-cover exposure rule and the live column rule (`PREY_RANGE`/`PREY_DIVE`) went with it.

Juveniles die only of starvation or old age, so more of them reach maturity; the habitat caps (six of each swimming fish, four garden eels, hard limit 24) and downstream dispersal absorb the surplus. Saves made before the change keep their `predation` totals, causes, archived deaths and `feeding` events; the total never grows. Starvation, old age and local species absence are possible and are reported, not suppressed.

## Time, determinism and saves

Movement decisions run at 5 Hz; ecological updates use one-minute steps. Ecological time advances the day/night cycle, with local-time correction while the app is visible. The viewing light and inspection do not affect ecology. Seeded repeatability is checked within each mode. Offline ecology is not a promise of identical frame-level encounters.

Reopening or waking advances no more than 72 hours per absence. The evolved state and wall-clock checkpoint commit together. Negative clock changes do not reapply time. v1 stream saves upgrade to v2 by adding the new pools with an explicit ledger entry and assigning individual lifespan values; their crayfish and shrimp then depart as above, and saves from before the garden eels receive one pair as ordinary (non-live) arrivals. Identities, names and lineage of the remaining animals remain intact. This upgrade does not import the separate old wetland project's saves.

Full rules and acceptance criteria: [v2 plan](plans/2026-09-22-self-sustaining-ecosystem.md). Measured results: [validation](validation.md).

## Visual reference species

- [Threadfin rainbowfish — Iriatherina werneri](https://aquaticarts.com/products/threadfin-rainbowfish)
- [Marbled hatchetfish — Carnegiella strigata](https://www.aquariumcoop.com/blogs/aquarium/hatchetfish)
