# Frontal cast draft v1 — superseded by lower-resolution style direction

Generated with imagegen using the approved `assets/reef/fish-atlas-v1.png` as reference. Source: `exec-818e0ff7-ebfe-46de-b51c-30dd89a8c9a9.png`, generated 2026-09-26/27. Copied unchanged to `reef-front-v1.png`; no raster postprocessing. The review renderer uses the same alpha cutoff as the production fish shader to remove generated edge halos.

Prompt intent: four exact existing fish, orthographic frontal, transparent 2×2 atlas (tang, firefish, blenny, chromis), restrained soft pixel treatment, separate lateral eyes and central mouth, each species' distinctive fins. Preserve identity and colors rather than redesigning side profiles. No props, text, shadows or additional animals.

`tools/frontal_pose_review.gd` renders approved profiles beside draft fronts at 1× and 1.65×. Source-region bounding boxes use alpha >220. Overall dorsal-to-ventral height matches the current species sprite height; this is a first visual comparison, not final anatomical registration for animation.

Findings: front views preserve distinct colors/fins and separate the eyes, unlike the failed single-texture ray projection. The frontal expressions read more frowning than the profiles and need user judgement. Blenny frontal head and eye prominence must also be reviewed. Overall equal height does not establish corresponding mouth, eye or fin-root positions: those landmarks need registration before interpolation. A direct cross-fade remains unacceptable because it duplicates features.

Status: user has been asked to choose whether this direction is acceptable, eyes should be smaller, or fronts should be redrawn. No answer recorded yet. No production script or packaged app uses this atlas. `tools/*` is excluded from export. Do not treat this board as approved or the animation goal as complete.

2026-09-27: User says current art is too realistic and asks for lower pixel density. The pending frontal-v1 approval question is superseded. Review `reef-low-pixel-v1.png` first; do not integrate the detailed frontal atlas.
