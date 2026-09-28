"""Read-only raster check of paper_turn_review.gd's actual 60 FPS output."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parents[1] / "artifacts/paper-turn-review"
paths = sorted((folder / "frames").glob("frame-*.png"))
assert len(paths) == 480, f"Expected 480 captured frames, got {len(paths)}"
minimum = [999999] * 4
blank = []
for path in paths:
    im = np.array(Image.open(path).convert("RGB"), dtype=np.int16)
    background = im[359, 639]
    for row in range(4):
        center = 71 + row * 82
        # Excludes text, the old pose column and every other fish.
        crop = im[center - 32 : center + 39, 425:548]
        pixels = int((abs(crop - background).max(axis=2) > 12).sum())
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
}
(folder / "visibility-check.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
assert not blank, "A fish disappeared during the edge-on flip"
