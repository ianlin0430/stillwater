# Biological basis and model boundaries

Recorded before calibration, 2026-09-21. This is an illustrative ecosystem, not a population forecast or a recreation of a surveyed site.

## Sources adopted
- EPA, How do Wetlands Function and Why are they Valuable? https://www.epa.gov/wetlands/how-do-wetlands-function-and-why-are-they-valuable — habitat, detritus-based food webs and migration link aquatic and terrestrial communities.
- USGS, Dissolved Oxygen and Water https://www.usgs.gov/water-science-school/science/dissolved-oxygen-and-water — atmospheric exchange and photosynthesis supply oxygen; warmer water holds less oxygen; respiration/decomposition consume oxygen and oxygen depletion harms aquatic life.

## Implementation defaults, not measured facts
Animal names identify representative functional archetypes. A minnow is omnivorous, midge larvae consume detritus/algae, adult frogs eat insects, tadpoles graze, voles eat ground vegetation, herons prey locally on fish/frogs/voles. Rates, lifespans, sensing distances, initial abundance, migration intensity and brood sizes in data/species.json are illustrative, deliberately small effective cohorts; they are not species estimates. Reproduction uses a local mate and transfers parental reserves into offspring; sex ratios/genetics/eggs are abstracted. Aquatic midge larvae emerge as flying adults; tadpoles become shoreline frogs.

Cells contain a conserved resource-equivalent material pool: fertility, producer biomass, detritus and animals' body/reserves. Photosynthesis transfers fertility to producers, feeding transfers material into reserves with a waste fraction, maintenance returns material to fertility/detritus, growth transfers reserve to body, and death recycles the whole remaining animal. This is a bookkeeping surrogate combining several nutrient cycles, not a literal carbon, nitrogen or energy budget. Sunlight supplies untracked energy. All external material enters/leaves an explicit boundary ledger. Trees use a slow producer pool; no individual tree life histories. Decomposer activity is temperature/moisture dependent, not a separately animated species.

Weather is seasonal seeded noise, not a meteorological forecast. Lake level responds to rain and evaporation; exposed peripheral cells cease being aquatic. Ground moisture and oxygen are cell-based. Hydrodynamics, vertical mixing, disease, genetics, territory ownership and detailed chemistry are omitted. Water appearance includes an authored base image; changing shore/vegetation overlays convey live conditions rather than regenerating the artwork.

Immigration attempts occur at fixed calendar intervals and draw from fixed species-specific probabilities, independent of current abundance. Arrivals require suitable habitat; they are never triggered by extinction. Voles enter at outer land boundaries; herons fly to shore; fish have no immigration because this lake has no stream; amphibians and flying midges connect to the surrounding watershed. Herons can leave in winter or when hungry. Every arrival/departure adds/subtracts material and produces an event.

One step is 0.25 ecological days. 1460 steps represent a 365-day year; 1× runs a year in 7200 seconds. Screen movement interpolates causal step positions and adds cosmetic swimming/wing motion. It is not physical distance per biological second. Higher speed executes identical steps, subject to a per-frame work budget; no steps are skipped. No elapsed-time catchup after closing or computer sleep.

## Calibration revision 1
The initial four-year exploratory run (artifacts/initial-calibration.log) lost midges early. Inspection found fish could target emerged flying insects and initial adult frogs could start in deep water. Corrected initial habitat placement and constrained fish to aquatic insect stages. Reduced minnow capture success to an illustrative 0.07 per close encounter, increased effective midge reproduction to 0.25/day with four potential offspring, extended breeding into late summer, and made cold larval dormancy delay aging. These are visible versioned model changes, not hidden runtime rescue. No claim that these values are empirically calibrated.
