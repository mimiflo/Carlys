#!/usr/bin/env python3
"""Détourage et export des PNG ImageGen, après autorisation du traitement logiciel.

Usage: python scripts/prepare_exercise_photos.py /chemin/aux/png --preview /chemin/png
Les entrées portent le slug du catalogue. Nécessite rembg[cpu]==2.0.83 et Pillow.
Les PNG de contrôle restent hors du dépôt ; les WebP RGBA sont livrés au seed
et à la démonstration, sans ajouter de dépendance à l'application.
"""

import argparse
import hashlib
import json
import os
import time
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "2")

import numpy as np
from PIL import Image
from rembg import new_session, remove

ROOT = Path(__file__).resolve().parents[1]
TARGET = np.array([234, 78, 69], dtype=np.float32)
SIZE = 1024


def finish(cutout):
    rgba = np.array(cutout.convert("RGBA"))
    alpha = rgba[:, :, 3]
    # Supprimer les résidus presque invisibles ; rendre le corps opaque.
    alpha[alpha < 8] = 0
    alpha[alpha > 247] = 255
    rgb = rgba[:, :, :3].astype(np.float32)
    r, g, b = rgb.transpose(2, 0, 1)
    red = (alpha > 240) & (r > 100) & (r > 1.3 * g) & (r > 1.3 * b)
    if np.count_nonzero(red) < 100:
        raise ValueError("Zone musculaire rouge absente ou trop petite")
    source_red = np.median(rgb[red], axis=0)
    dominance = (r - np.maximum(g, b)) / np.maximum(r, 1)
    mask = np.clip((dominance - 0.15) / 0.20, 0, 1)
    mask = (mask * mask * (3 - 2 * mask))[:, :, None]
    corrected = np.clip(rgb * TARGET / np.maximum(source_red, 1), 0, 255)
    rgba[:, :, :3] = np.rint(rgb * (1 - mask) + corrected * mask).astype(np.uint8)
    rgba[:, :, 3] = alpha
    rgba[alpha == 0] = 0
    image = Image.fromarray(rgba)
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("Détourage vide")
    figure = image.crop(bounds)
    figure.thumbnail((int(SIZE * 0.90), int(SIZE * 0.90)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE))
    canvas.paste(figure, ((SIZE - figure.width) // 2, (SIZE - figure.height) // 2))
    return canvas, source_red.tolist()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--watch", action="store_true")
    args = parser.parse_args()
    catalog = json.loads((ROOT / "apps/mobile/assets/demo/catalog.json").read_text())
    slugs = {e["slug"] for e in catalog["exercises"]}
    report_path = ROOT / "docs/design/exercise-photo-report.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    session = None
    args.preview.mkdir(parents=True, exist_ok=True)
    while True:
        for path in sorted(args.source.glob("*.png")):
            slug = path.stem
            if slug not in slugs:
                raise ValueError(f"Exercice inconnu : {slug}")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if not args.overwrite and report.get(slug, {}).get("sourceSha256") == digest:
                continue
            image = Image.open(path)
            if image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0:
                cutout = image
            else:
                if session is None:
                    session = new_session("birefnet-general-lite")
                cutout = remove(image, session=session)
            final, source_red = finish(cutout)
            final.save(args.preview / f"{slug}.png")
            api_path = ROOT / "apps/api/prisma/seed-media/exercises" / f"{slug}.webp"
            final.save(api_path, "WEBP", quality=92, method=6)
            data = api_path.read_bytes()
            (ROOT / "apps/mobile/assets/demo/exercises" / api_path.name).write_bytes(data)
            alpha = np.array(Image.open(api_path).getchannel("A"))
            assert alpha.min() == 0 and alpha.max() == 255
            assert np.all(alpha[:40] == 0) and np.all(alpha[-40:] == 0)
            assert np.all(alpha[:, :40] == 0) and np.all(alpha[:, -40:] == 0)
            report[slug] = {
                "sourceSha256": digest,
                "sha256": hashlib.sha256(data).hexdigest(),
                "width": SIZE,
                "height": SIZE,
                "bytes": len(data),
                "sourceRed": source_red,
                "targetRed": "#EA4E45",
                "transparentPixels": int(np.count_nonzero(alpha == 0)),
                "opaquePixels": int(np.count_nonzero(alpha == 255)),
            }
            report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            print(f"{slug}: RGBA, {len(data)} octets ({len(report)}/{len(slugs)})", flush=True)
        if not args.watch:
            break
        time.sleep(2)



if __name__ == "__main__":
    main()
