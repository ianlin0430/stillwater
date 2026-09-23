# Ecology v2: assumptions and boundaries

Stillwater Stream is a curated fictional freshwater habitat, not a real stocking recommendation or a scientific forecast. The active cast is cherry shrimp, threadfin rainbowfish and marbled hatchetfish. The user removed crayfish; earlier stream saves archive their departures while preserving the remaining individuals.

## Life cycles

The opening population is six shrimp and four of each fish. Illustrative maturity ages are 21 days for shrimp and 28 days for fish. Illustrative lifespans are 120 days for shrimp and 180 days for fish, independently varied by ±15% at creation. Opening ages are staggered: shrimp 25–100 days, fish 40–150 days. These deliberately compressed rates let local generations and natural deaths become observable over months.

Breeding requires mature mates, sufficient reserves, a species-specific cooldown and a resource-dependent probability. Space permits up to eight shrimp, five threadfins and five hatchetfish. Excess offspring explicitly disperse downstream. The defensive active-individual limit is 24; ordinary new worlds remain at or below the combined habitat limit of 18. Adults do not randomly depart. Low local species counts allow rescue arrivals; ordinary immigration is much less frequent.

The acceptance measure **offspring produced = retained births + dispersed offspring** counts individual young, not breeding attempts or broods. Both components remain visible in reports. Retained births must independently exceed arrivals, so successful dispersal cannot disguise a population sustained mostly by immigration.

## Food and plants

Six resource-equivalent material pools are modeled: dissolved nutrients, rooted plants, floating plants, biofilm, microfauna and detritus. Light supplies energy rather than material. Plant growth transfers nutrients into plants, limited by light, nutrient concentration and carrying capacity. Floating plants shade the submerged pools; rooted plants increase the surface available to biofilm. Small, explicitly accounted stream seed inputs prevent permanent plant loss.

Shrimp graze biofilm and can use detritus when biofilm is scarce. Fish consume microfauna. Intake and reproduction use saturating food-response curves. Metabolism returns 65% of consumed reserves to nutrients and 35% to detritus. Dead microfauna return half their material to nutrients and half to detritus; detritus also mineralizes. Incoming stream material, outflow, immigration and offspring dispersal are recorded in the boundary ledger. Body mass and energy reserves participate in the same bookkeeping. This is a conservation model, not detailed aquatic chemistry.

Current calibration: daily stream inputs are 0.7 nutrient units and 0.35 microfauna units. Floating-plant growth/mortality coefficients are 1.3/0.025 per day; food half-saturation constants are 6 for shrimp and 10 for fish. These are authored model parameters, not measured species physiology.

Plant amounts currently exist in the simulation and read-only snapshots. The painted pixel background does **not** yet change with plant biomass. No plant art, resource dashboard, fluid solver, oxygen model or management interaction was added in this stage.

## Predation and recovery

Hungry fish can occasionally catch immature shrimp outside the nursery. Nursery position, shelter/molting state and rooted-plant cover provide protection. Live encounters require proximity; offline encounters use a bounded probabilistic approximation.

Live proximity is measured in the water column below the fish (rule change 2026-09-23): the horizontal gap must be at most 220 px (`PREY_RANGE`) and the shrimplet at most 290 px (`PREY_DIVE`) below the fish. With the bed at about y 600, only a threadfin in the lower half of its layer (y ≥ ~310) can reach a shrimplet; hatchetfish keep to their surface band (y 88–208) and never take shrimp in live play. The earlier plain 220 px radius could not reach the bed from the hatchetfish band and only from the bottom edge of the threadfin band, so live predation ran at about a tenth of the offline approximation (1/2/0 against 11–16 per 180 days). The column rule qualifies about 38% of exposed shrimplet-minutes, matching what the offline factors imply (encounter 0.5 × outside-nursery share 0.65, over the ~86% of juvenile time spent outside the nursery). Offline catch-up still credits the catch to a randomly chosen hungry fish, which may be a hatchetfish; this attribution difference only moves the prey's material to that fish's reserve. Presentation and event wording are non-graphic. Starvation, old age and local species absence are possible and are reported, not suppressed. The model has no added predator species.

## Time, determinism and saves

Movement decisions run at 5 Hz; ecological updates use one-minute steps. Ecological time advances the day/night cycle, with local-time correction while the app is visible. The viewing light and inspection do not affect ecology. Seeded repeatability is checked within each mode. Offline ecology is not a promise of identical frame-level encounters.

Reopening or waking advances no more than 72 hours per absence. The evolved state and wall-clock checkpoint commit together. Negative clock changes do not reapply time. v1 stream saves upgrade to v2 by adding the new pools with an explicit ledger entry and assigning individual lifespan values. Identities, names and lineage remain intact. This upgrade does not import the separate old wetland project's saves.

Full rules and acceptance criteria: [v2 plan](plans/2026-09-22-self-sustaining-ecosystem.md). Measured results: [validation](validation.md).

## Visual reference species

- [Cherry shrimp — Neocaridina davidi](https://aquaticarts.ac-page.com/setting-up-your-first-shrimp-tank-2)
- [Threadfin rainbowfish — Iriatherina werneri](https://aquaticarts.com/products/threadfin-rainbowfish)
- [Marbled hatchetfish — Carnegiella strigata](https://www.aquariumcoop.com/blogs/aquarium/hatchetfish)
