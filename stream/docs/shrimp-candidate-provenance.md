# Shrimp candidate A — 2026-09-23

Status: review candidate only. Production `StreamStage` continues using `SwimmerRig`; it does not load the candidate. No user approval recorded. Garden eel art is still pending its own review.

Source: original code-drawn polygons, articulated segments, one-pixel pigment marks and thin appendages in `tools/art_candidates/shrimp_candidate.gd`, inheriting the real movement/feet rig. No generated bitmap, no external photograph copied, no image-generation prompt. Design brief: C / Soft Pixel, unchanged adult scale 0.75 / juvenile 0.48, translucent ventral areas, darker red dorsal pigment, six abdominal segments, five pairs of pleopods, slender planted walking legs, two pairs of antennae (long pair approximately 1.1 body lengths), delayed antenna turn, fuller redder female, paler male and juvenile.

Anatomy reference consulted: [University of Florida IFAS, Cherry Shrimp](https://ask.ifas.ufl.edu/publication/IN1301), description and life-cycle sections, retrieved 2026-09-23. Used for five pairs of walking legs and swimming appendages, egg location under abdomen, fuller females, and miniature adult-like young. It is a stylized rig, not a scientific illustration. The model's five-day brood remains a compressed fictional rate; this art change does not adjust biology.

Review generator: `tools/shrimp_review.gd`. Calls the candidate's `apply_identity` using actual snapshot field names (`sex`, `age`, `tint`, `molting_until`, `brood_until`). Identity examples are deliberate fixtures; this is a rig study, not autonomous ecology evidence. Both current and candidate use the same body scale. Formal production integration awaits approval.

Outputs in `artifacts/shrimp-review/`: nine identities/states (female, male, newborn, juvenile, berried, molting, tint-low/mid/high), each at normal and 1.65x. Left current / right candidate. `tints-close.png` shows three candidate pigment values side by side. `motion.mp4` shows walking, swimming, grazing, and turning at 1.65x, two seconds each. Small pigment/egg details will be subtle at native 640x360; no enlarged body is used to hide that limitation.

Existing production changes in this batch are only event overlays (eggs, pale molt line and empty exuvia) plus replanted feet on relocation. Candidate translucency, anatomy and pigment are NOT integrated.
