# Stillwater Reef backend contract

Updated 2026-10-06. This document describes the current four-species v3 implementation. Earlier contracts are preserved in [BACKEND_SNAPSHOT_EVENTS_HISTORY.md](BACKEND_SNAPSHOT_EVENTS_HISTORY.md). Implementation and validation remain authoritative: `scripts/stream_world.gd`, `scripts/stream_store.gd`, and `scripts/reef_scene.gd`.

## World and storage

`ACTIVE_SPECIES` is `green_chromis`, `clownfish`, `seahorse`, `royal_gramma`. Initial populations are 6/2/2/2; ecological caps are 8/3/4/3 (18 total). Neglect does not cause starvation or permanent species loss: energy floors and rescue arrivals maintain the ecosystem. Old age remains part of the lifecycle. Scene and decor choices affect geometry and homes, not ecological rates or ecology RNG.

World schema is 3; the store envelope is `stillwater-reef-3`. Normal storage defaults to `user://reef.world`, with SHA-256 integrity checking, backup recovery and atomic writes. Preference `reef/path` selects its location. Earlier `stream.world` files and `world/path` preferences are not migrated into the reef world. Unsupported species are rejected rather than silently converted. Memory QA uses `--qa`; persistence QA uses an isolated `--persist-qa` run directory. Neither may use the user's real saves.

`export_state()` includes both RNG states as strings. `snapshot()` returns a deep copy without modifying world or either RNG. Current-layout restore preserves the saved world and continuation; changed authored homes are repaired without changing ecology, RNG or fish positions. Derived route geometry and daylight/night bounds are rebuilt, not serialized as caches.

## Snapshot fields

World coordinates are 1280×720. Rendering uses a 640×360 viewport and maps world positions at half scale.

| Field | Meaning |
|---|---|
| `elapsed`, `light_hour` | Simulation seconds and lighting phase. |
| `scene`, `decor` | `reef` or `shipwreck`, and scene-specific fixed-slot styles. |
| `animals` | Living ecological individuals; stable numeric IDs, species, position, age, sex, energy, activity and motion state. |
| `resources`, `ledger`, `totals`, `history`, `rescue` | Ecological state and accounting. Presentation does not mutate these. |
| `food` | Pellets with ID, position, mass and settled state. |
| `events`, `next_event` | Recent 160 events, ordered by sequence; next sequence counter. |
| `archive` | Recent 96 departed individual records. |
| `departing` | Live old-age exit visuals, excluded from living counts and material accounting. |

Per-animal `vx/vy` describe integrated velocity. `heading` is continuous in [0, π]; `direction` is ±1 and follows its cosine with hysteresis near the crossing. `pitch`, `speed`, `thrust`, `turn` describe motion for the rig; missing motion values default to zero, and missing heading defaults from direction. The approved frontend mirrors sides immediately at the hysteresis crossing. It does not squeeze body width into a paper flip. `relocated_at` marks a deliberate relocation so presentation can suppress a long interpolation or wake.

Home-bound actors carry `home`, `home_x/y`; the home identity includes kind, slot and index. Saved home/trip intentions and navigation waypoints support exact continuation. They are backend state, not frontend movement instructions to modify.

## Species behavior

- **Chromis:** stable school in its daylight layer. At night an eligible shelter within 300 world pixels supplies a reachable resting target 40–60 pixels away. Otherwise it rests in place. Paired finite `night_roost_x/y` identify that target. Optional boolean `night_returning` keeps the extended swimming bounds during a legitimate dawn return; an arbitrary out-of-band fish does not acquire those bounds. Targets remain stable while resting.
- **Clownfish:** shared anemone residence, nestling and nearby foraging. Shelter and return state belong to the backend. Required anemone slots cannot be empty.
- **Seahorse:** upright slow excursions between unique hitch homes, with actual tail contact from `hitch_x/y`. `lean` supplies posture; saved `hitch_path`, `hitch_departed_at` and `hitch_rest_until` preserve route and cadence. Activities include Hitched, Drifting, Returning, Feeding and Startled. A held horse intercepts nearby falling food. Required hitch plants cannot be empty. Excursion routes clear both obstacles and other fish bodies.
- **Royal gramma:** hovering within its 50-pixel home radius; cave shelter on tapping or at night. `den_x/y`, `den_side` and `extend` control the physical retreat. `extend` transitions over approximately 0.8 seconds. Cave homes clip the retreat; fallback rock homes keep the body visible. With no caves, at least three reachable unique rock homes remain available.

## Events and departures

Events carry `seq`, `kind`, `time`, `live` and applicable actor ID/location/detail fields. The frontend consumes only unseen live sequences. First snapshot, a changed world or a rewound cursor establishes a baseline and does not replay history. `ate` identifies the eater and pellet/location for a short bite animation; disappearance alone does not identify an eater.

A live old-age death removes the animal from ecology and creates a peaceful `departing` exit with position, appearance, route, opacity and an expiry no later than 120 simulation seconds. The frontend uses this backend exit, without corpses or sinking. Offline advancement and scene switches clear exit visuals. Offline events do not replay on return.

`set_scene()` preserves living identity and ecosystem, then deterministically relocates actors into the destination geometry and adapts homes. The frontend covers this with a 0.75-second black fade. `set_decor(slot, style)` validates fixed slots and required habitat, then adapts homes and obstacles. These operations do not consume ecological RNG.

## Verification

Scene/save/home gates cover geometry, restore, identity and deterministic continuation. Species gates cover S6–S9. Natural-motion and obstacle suites retain their kinematic, separation and navigation limits. Long-run chunk tests compare exact whole/split state and reject checkpoint habitat mismatches. Full app acceptance additionally requires the 32-seed offline and 24-case live 180-day results, native package lifecycle checks, visual review and measured performance; short headless passes do not establish those results. Current evidence is tracked in [APP_COMPLETION.md](APP_COMPLETION.md).
