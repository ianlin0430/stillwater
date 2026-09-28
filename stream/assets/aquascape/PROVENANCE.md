# Shipwreck algae garden — preview v1

User chose concept C and requested 16:9, a richer landscaped aquarium, quiet bubbles, ribbon algae/red macroalgae/seagrass, gently varying water flow, local plant response to passing fish, and foreground occlusion. This is an independently runnable visual preview; the production main scene is not replaced.

`shipwreck-background-v1.png` was generated with the built-in imagegen tool and copied unchanged from `exec-9c5652ed-8ab4-44f1-9b6d-4e62fd97b782.png`. Reference: the selected 16:9 C concept `exec-b1a08383-9423-43f7-ab12-41b812c91f0c.png`. Native output is fitted to the exact 1280×720 runtime viewport. Plants, bubbles, foreground masks, water shading and fish are separate Godot geometry/shaders/rigs, not baked fish or video.

Final prompt:

> Edit this approved 16:9 aquarium concept into a production game BACKGROUND plate. Preserve EXACT composition: wooden shipwreck lower left, rock swim-through arch lower right, open blue central midwater, clear warm sandy bottom center, waterline and dark glass edges and corner equipment. REMOVE EVERY fish completely, including tiny mint fish; no animals, no bubbles, no text. Fill their old positions seamlessly with the water behind. Keep hard corals on rocks, but don't add seaweed or seagrass: animated algae will be separate game layers. Simplify the entire background to COARSER pixel clusters, reduced rock/sand texture noise and fewer shades; match 320x180 conceptual chunky pixel art enlarged sharply, with coherent square pixel size across all objects. Do not add fine details. No blur or photorealism. Keep central sand plain enough for fish burrows and leave arch hole unobstructed. Full image EXACT 16:9. No layout redesign, no crop.

## B — 2026-09-28

`shipwreck-background-v2.png` uses the built-in imagegen tool, copied unchanged from `exec-dc19913e-0d19-453a-9c72-2cd80c98342c.png`. Inputs: v1 as layout target and `exec-9e3be4a1-c0ef-4349-8e3c-abc8a7d78fb8.png` middle B panel as style reference. The source plate is fitted to 1280×720. Existing masks remain registered to the ship and arch. Native moving plants use broader muted leaves.

Final prompt:

> Use case: style-transfer. Edit image 1, the fishless aquarium background. Image 2 is a style board: apply ONLY its MIDDLE B panel's soft low-pixel visual style. Output a SINGLE 16:9 background, no labels or comparison panels. Preserve image 1's exact camera, shipwreck silhouette and position on left, rock arch silhouette and opening on right, central open sand, object boundaries and layout. Harmonize with simple soft pixel fish: muted teal water rather than saturated blue; broad clean slate-blue rock color blocks; sandy cream seabed with far fewer tiny speckles; pastel restrained coral accents. Reduce internal rock and wood texture contrast and detail density substantially. Coarse deliberate pixel edges, no fine linework, no dithering, no photographic gradients. Keep static low coral and groundcover but DO NOT add tall plants: moving plants are rendered separately in engine. No fish, animals, bubbles, words, borders, UI, or moving-light streaks. Match the quiet rich aquarium feeling of middle panel B, retaining exactly the original structural geometry.
