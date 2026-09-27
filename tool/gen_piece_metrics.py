"""Compute per-piece geometry metrics (opaque bbox + base-center pivot)
for the chess PNGs and emit lib/games/chess/chess_piece_metrics.dart."""
import os

import numpy as np
from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "chess")
OUT = os.path.join(os.path.dirname(__file__), "..", "lib", "games",
                   "chess", "chess_piece_metrics.dart")

PIECES = ["pawn", "rook", "knight", "bishop", "queen", "king"]
COLORS = ["white", "black"]

rows = []
for c in COLORS:
    for p in PIECES:
        path = os.path.join(SRC, f"{c}_{p}.png")
        im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64)
        a = im[..., 3]
        mask = a > 16
        ys, xs = np.nonzero(mask)
        y0, y1 = ys.min(), ys.max()
        x0, x1 = xs.min(), xs.max()
        h, w = mask.shape

        # مركز قاعدة القطعة: متوسط x للبكسلات المعتمة في أدنى 12% من
        # الحدود المرئية — يعطي مركز القاعدة الهندسي حتى لو الجسم غير متماثل
        base_rows = mask[int(y1 - (y1 - y0) * 0.12): y1 + 1]
        bx, bn = 0.0, 0
        for r_i, row in enumerate(base_rows):
            idx = np.nonzero(row)[0]
            if len(idx):
                bx += idx.mean()
                bn += 1
        base_cx = (bx / max(bn, 1)) / w

        rows.append(
            (f"{c}_{p}",
             w / h,                      # aspect
             x0 / w, y0 / h,             # visL, visT
             (x1 + 1) / w, (y1 + 1) / h,  # visR, visB
             base_cx))
        print(f"{c}_{p}: {w}x{h} bbox=({x0},{y0})-({x1},{y1}) "
              f"baseCX={base_cx:.3f}")

lines = [
    "/// قياسات هندسية لأحجار الشطرنج — مولّدة بـ tool/gen_piece_metrics.py",
    "/// baseX: مركز قاعدة القطعة (نسبة من عرض الصورة)",
    "/// visT/visB/visL/visR: حدود البكسلات المعتمة (نسبة من أبعاد الصورة)",
    "class ChessPieceMetric {",
    "  final double aspect;",
    "  final double visL, visT, visR, visB;",
    "  final double baseX;",
    "  const ChessPieceMetric(this.aspect, this.visL, this.visT,",
    "      this.visR, this.visB, this.baseX);",
    "  double get visW => visR - visL;",
    "  double get visH => visB - visT;",
    "}",
    "",
    "const Map<String, ChessPieceMetric> chessPieceMetrics = {",
]
for key, ar, l, t, r, b, cx in rows:
    lines.append(
        f"  '{key}': ChessPieceMetric({ar:.5f}, {l:.5f}, {t:.5f},"
        f" {r:.5f}, {b:.5f}, {cx:.5f}),")
lines.append("};")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("written ->", os.path.abspath(OUT))
