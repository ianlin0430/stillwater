"""Read-only raster check of mirror_turn_review.gd's actual 60 FPS output."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parents[1] / "artifacts/mirror-turn-review"
paths = sorted((folder / "frames").glob("frame-*.png"))
assert len(paths) == 480, f"Expected 480 captured frames, got {len(paths)}"
minimum = [999999] * 4
widths = [[] for _ in range(4)]
blank = []
for path in paths:
    im = np.array(Image.open(path).convert("RGB"), dtype=np.int16)
    background = im[359, 639]
    for row in range(4):
        center = 71 + row * 82
        # Excludes text, the jitter column and every other fish.
        crop = im[center - 25 : center + 29, 100:230]
        mask = abs(crop - background).max(axis=2) > 12
        pixels = int(mask.sum())
        columns = np.flatnonzero(mask.any(axis=0))
        widths[row].append(int(columns[-1] - columns[0] + 1) if len(columns) else 0)
        minimum[row] = min(minimum[row], pixels)
        if pixels == 0:
            blank.append([path.name, row])
report = {
    "frames": len(paths),
    "fps": 60,
    "minimum_visible_pixels_by_species": dict(
        zip(["green_chromis", "yellow_tang", "purple_firefish", "lawnmower_blenny"], minimum)
    ),
    "blank_frames": blank,
    "width_ranges": [[min(w), max(w)] for w in widths],
}
(folder / "visibility-check.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
assert all(min(w) >= max(w) * .85 for w in widths), "A direct mirror narrowed the body"
assert not blank, "A fish disappeared during the direct mirror"
flips = json.loads((folder / "flips.json").read_text())
for species in report["minimum_visible_pixels_by_species"]:
    assert len(flips[species + "_turn"]) == 2, "Each deliberate turn must flip exactly once"
    assert len(flips[species + "_jitter"]) == 1, "Jitter must not add any flips"
