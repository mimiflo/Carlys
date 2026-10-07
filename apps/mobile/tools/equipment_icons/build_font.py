"""Construit assets/fonts/CarlysEquipment.ttf depuis tools/equipment_icons/svg/*.svg.

Les glyphes du matériel : Material n'a ni kettlebell, ni poulie, ni banc, et
ses approximations (des points pour une barre, une balance pour un
kettlebell) se lisaient mal. Cinq viennent de Tabler Icons (MIT, licence
dans assets/fonts/MIT-Tabler.txt) ; les dix autres sont dessinés dans le MÊME
style (grille de 24, trait de 2, bouts arrondis) — cinq par Codex, retenus
contre les miens à la comparaison (machine, barre de traction, rouleau,
tapis, élastique), cinq à la main.

Chaque SVG à traits est converti en contours pleins (picosvg), ses formes
fusionnées (skia-pathops), puis posé dans une police d'icônes : le widget
`Icon` le dessine alors comme un glyphe Material, couleur et taille
comprises.

Outils de développement seulement (rien n'entre dans l'application) :

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install picosvg==0.23.0 skia-pathops==0.9.2 fonttools==4.66.1
    /tmp/venv/bin/python apps/mobile/tools/equipment_icons/build_font.py

Les points de code sont FIXES : un glyphe s'ajoute en fin de liste, jamais
au milieu — `AppIcons` les nomme en dur.
"""

from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from pathops import Path as SkPath
from pathops import union
from picosvg.svg import SVG

HERE = Path(__file__).resolve().parent
SOURCES = HERE / "svg"
OUTPUT = HERE.parent.parent / "assets" / "fonts" / "CarlysEquipment.ttf"

FAMILY = "CarlysEquipment"
UPM = 960  # 40 unités par pixel de la grille de 24
FIRST_CODEPOINT = 0xE000

# Ordre = points de code (U+E000, U+E001…). Ajouter en FIN de liste.
GLYPHS = [
    "barre",
    "barre-ez",
    "halteres",
    "kettlebell",
    "disque",
    "medecine-ball",
    "machine",
    "poulie",
    "poids-du-corps",
    "barre-de-traction",
    "rouleau",
    "tapis",
    "banc",
    "elastique",
    "ballon",
]


def glyph_outline(svg_file: Path):
    """Le SVG à traits, en un contour plein dans le repère de la police."""
    pico = SVG.parse(str(svg_file)).topicosvg()
    shapes = []
    for shape in pico.shapes():
        path = SkPath()
        parse_path(shape.d, path.getPen())
        shapes.append(path)
    scale = UPM / 24
    pen = TTGlyphPen(None)
    # Le SVG descend, la police monte : y retourné sur la grille de 24.
    union(shapes, TransformPen(Cu2QuPen(pen, max_err=1), (scale, 0, 0, -scale, 0, UPM)))
    return pen.glyph()


def main() -> None:
    names = [".notdef", *GLYPHS]
    empty = TTGlyphPen(None)
    glyphs = {".notdef": empty.glyph()}
    for name in GLYPHS:
        glyphs[name] = glyph_outline(SOURCES / f"{name}.svg")

    builder = FontBuilder(UPM, isTTF=True)
    builder.setupGlyphOrder(names)
    builder.setupCharacterMap(
        {FIRST_CODEPOINT + index: name for index, name in enumerate(GLYPHS)}
    )
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics({name: (UPM, 0) for name in names})
    builder.setupHorizontalHeader(ascent=UPM, descent=0)
    builder.setupOS2(sTypoAscender=UPM, sTypoDescender=0, usWinAscent=UPM, usWinDescent=0)
    builder.setupNameTable({"familyName": FAMILY, "styleName": "Regular"})
    builder.setupPost()
    builder.save(str(OUTPUT))

    for index, name in enumerate(GLYPHS):
        print(f"U+{FIRST_CODEPOINT + index:04X}  {name}")
    print(f"{OUTPUT.relative_to(HERE.parent.parent)} : {OUTPUT.stat().st_size} octets")


if __name__ == "__main__":
    main()
