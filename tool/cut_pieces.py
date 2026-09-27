"""Cut chess piece sprites from the two sheet JPGs the user provided.

Outputs transparent PNGs to assets/images/chess/:
  white_<type>.png  (from the pink cartoon sheet)
  black_<type>.png  (from the dark set sheet)

Run:  python tool/cut_pieces.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images" / "chess"
OUT.mkdir(parents=True, exist_ok=True)

SHEETS = {
    # (source jpg, bg color sample point, side tag, piece order left->right)
    "pink": (ROOT / "tool/tmp_pieces/pink.jpg", "white",
             ["pawn", "rook", "knight", "bishop", "queen", "king"]),
    "black": (ROOT / "tool/tmp_pieces/black.jpg", "black",
              ["king", "queen", "bishop", "knight", "rook", "pawn"]),
}


def bg_distance_mask(img: np.ndarray, bg: np.ndarray, thresh: float):
    dist = np.abs(img.astype(np.int32) - bg.astype(np.int32)).sum(-1)
    # alpha ramp: dist<thresh -> 0, dist>thresh*2 -> 255
    alpha = np.clip((dist - thresh) / thresh, 0, 1) * 255
    return alpha.astype(np.uint8)


def cut_sheet(src: Path, side: str, order):
    im = Image.open(src).convert("RGB")
    arr = np.asarray(im)
    bg = np.median(
        np.concatenate([
            arr[:20].reshape(-1, 3), arr[-20:].reshape(-1, 3),
            arr[:, :20].reshape(-1, 3), arr[:, -20:].reshape(-1, 3),
        ]), axis=0)
    print(f"{src.name}: bg={bg}")
    alpha = bg_distance_mask(arr, bg, thresh=28)

    # find content columns (valleys of alpha)
    colsum = alpha.sum(0)
    active = colsum > colsum.max() * 0.01
    # merge into clusters with small gap tolerance
    cols = np.where(active)[0]
    clusters, start, prev = [], cols[0], cols[0]
    for c in cols[1:]:
        if c - prev > 60:  # gap -> new piece
            clusters.append((start, prev))
            start = c
        prev = c
    clusters.append((start, prev))
    print(f"  {len(clusters)} clusters: {clusters}")
    assert len(clusters) == len(order), "piece count mismatch"

    for (x0, x1), ptype in zip(clusters, order):
        sub_alpha = alpha[:, x0:x1 + 1]
        rowsum = sub_alpha.sum(1)
        rows = np.where(rowsum > rowsum.max() * 0.01)[0]
        y0, y1 = rows[0], rows[-1]
        piece_rgb = arr[y0:y1 + 1, x0:x1 + 1]
        piece_a = alpha[y0:y1 + 1, x0:x1 + 1]
        rgba = np.dstack([piece_rgb, piece_a])
        out = Image.fromarray(rgba, "RGBA")
        # pad to square-ish, trim outer 2px to kill halo
        out.save(OUT / f"{side}_{ptype}.png")
        print(f"  {side}_{ptype}.png {out.size}")


def main():
    for tag, (src, side, order) in SHEETS.items():
        cut_sheet(src, side, order)


if __name__ == "__main__":
    main()
