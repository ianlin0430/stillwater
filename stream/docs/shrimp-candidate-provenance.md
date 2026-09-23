# Shrimp candidate A — 2026-09-23

> CANCELLED: 使用者已改成只要魚（2026-09-23）。A/B 候選均不再待核可，不整合、不繼續迭代。以下為歷史記錄。

Status: review candidate only. Production `StreamStage` continues using `SwimmerRig`; it does not load the candidate. No user approval recorded. Garden eel art is still pending its own review.

Source: original code-drawn polygons, articulated segments, one-pixel pigment marks and thin appendages in `tools/art_candidates/shrimp_candidate.gd`, inheriting the real movement/feet rig. No generated bitmap, no external photograph copied, no image-generation prompt. Design brief: C / Soft Pixel, unchanged adult scale 0.75 / juvenile 0.48, translucent ventral areas, darker red dorsal pigment, six abdominal segments, five pairs of pleopods, slender planted walking legs, two pairs of antennae (long pair approximately 1.1 body lengths), delayed antenna turn, fuller redder female, paler male and juvenile.

Anatomy reference consulted: [University of Florida IFAS, Cherry Shrimp](https://ask.ifas.ufl.edu/publication/IN1301), description and life-cycle sections, retrieved 2026-09-23. Used for five pairs of walking legs and swimming appendages, egg location under abdomen, fuller females, and miniature adult-like young. It is a stylized rig, not a scientific illustration. The model's five-day brood remains a compressed fictional rate; this art change does not adjust biology.

Review generator: `tools/shrimp_review.gd`. Calls the candidate's `apply_identity` using actual snapshot field names (`sex`, `age`, `tint`, `molting_until`, `brood_until`). Identity examples are deliberate fixtures; this is a rig study, not autonomous ecology evidence. Both current and candidate use the same body scale. Formal production integration awaits approval.

Outputs in `artifacts/shrimp-review/`: nine identities/states (female, male, newborn, juvenile, berried, molting, tint-low/mid/high), each at normal and 1.65x. Left current / right candidate. `tints-close.png` shows three candidate pigment values side by side. `motion.mp4` shows walking, swimming, grazing, and turning at 1.65x, two seconds each. Small pigment/egg details will be subtle at native 640x360; no enlarged body is used to hide that limitation.

Existing production changes in this batch are only event overlays (eggs, pale molt line and empty exuvia) plus replanted feet on relocation. Candidate translucency, anatomy and pigment are NOT integrated.

## Candidate B — more drawable pixels and readable actions

User feedback: 「希望pixel可以多一點 可以真的看出他的動作」. Built a review variant interpreting this as more pixel detail and clearer motion, without increasing body scale. An optional clarification was sent because it could also mean larger animals or coarser pixel blocks; no answer was available while making this candidate.

Files: `tools/art_candidates/shrimp_candidate_b.gd`, `tools/shrimp_motion_review.gd`. Candidate A is preserved unchanged. B adds five-foot alternating support groups with a 5.5-local-unit swing lift; stance feet stay fixed in world space. Swimming appendages sweep sequentially with a continuously integrated phase driven by actual rendered speed. Feeding forelegs alternate between the surface and mouth, replacing the front walking pair while feeding. Dark limb edges and abdominal seams improve contrast. Antennae retain delayed turns. Resting feet stop and pause freezes every phase.

The review alone renders at 1280×720 instead of 640×360: twice the pixel count per axis, unchanged world/body dimensions. Both A and B use the higher resolution in the new comparison to isolate their motion differences. Production resolution and production rig are unchanged; no claim of accepted CPU/GPU cost. A 120-second performance check is still required before adopting the resolution in the actual app.

`artifacts/shrimp-review-b/motion.mp4`: 16 seconds / 480 frames / 30 FPS. First eight seconds normal view, next eight at 1.65×; each covers walking, swimming, feeding, turning. Left A, right B. `motion-detail.mp4` is an explicitly cropped and magnified eight-second detail of the close view, not the app's actual animal size. Identity/sex/tint/state comparisons also regenerated in this directory. This is scripted rig playback, not autonomous behavior evidence.

Short test `tests/test_shrimp_candidate.gd`: 8 checks, 0 failures; 1,065 planted-foot samples, zero stance slipping; peak foot lift 4.102 world pixels at adult scale. Tests include resting completion, pause, alternating support, continuous paddle phase, antenna turn delay and unchanged ecological state/RNG. The first PNG video capture was stopped early because encoding was too costly; the final capture uses JPEG frames and completed without leaving a rendering process. This capture is not a sustained performance benchmark.

Approval remains pending. Do not integrate B or change production resolution until the user confirms the visual direction.
