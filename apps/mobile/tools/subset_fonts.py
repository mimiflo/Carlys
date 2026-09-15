#!/usr/bin/env python3
"""Sous-ensemble les polices embarquées, depuis `tools/fonts-source/`.

POURQUOI. Flutter ne sous-ensemble PAS les polices de texte : seul
`--tree-shake-icons` agit, et uniquement sur les polices d'icônes. Les neuf
TTF complets partaient donc tels quels dans l'APK et l'IPA — 2 993 988 octets,
soit 47 % des assets, pour une application dont `app.dart` déclare
`supportedLocales: [Locale('fr')]`. Inter-Regular seul portait 2 852 points de
code, dont 249 cyrilliques, 105 grecs et 96 vietnamiens ; JetBrains Mono, que
le design system réserve aux CHIFFRES, en portait 1 363.

CE QUI EST GARDÉ, et pourquoi si large. L'application n'affiche pas que ses
propres libellés : noms d'exercices servis par l'API, noms de repas saisis à
la main, réponses du coach, noms d'affichage des amis. Un glyphe manquant ne
donne pas un carré vide — Flutter retombe sur la police système — mais le
changement de dessin se voit. Le jeu retenu couvre donc tout le latin étendu
et la ponctuation courante, bien au-delà des 49 caractères non-ASCII que le
code source emploie réellement.

LICENCE. Les trois familles sont sous SIL OFL 1.1 SANS nom réservé (aucun
« with Reserved Font Name » dans leurs en-têtes de copyright) : le
sous-ensemblage est permis, et le nom de famille peut être conservé. Les
textes de licence restent livrés à côté des polices.

REFAIRE : `python3 tools/subset_fonts.py` depuis `apps/mobile`. Les originaux
NE SONT PAS supprimés — ils vivent dans `tools/fonts-source/`, hors de la
liste d'assets, donc hors de l'application. Élargir le jeu ci-dessous et
relancer suffit.
"""

from __future__ import annotations

import pathlib
import sys

SOURCE = pathlib.Path(__file__).parent / "fonts-source"
CIBLE = pathlib.Path(__file__).parent.parent / "assets" / "fonts"

# Intervalles Unicode conservés, bornes incluses.
PLAGES: list[tuple[int, int, str]] = [
    (0x0020, 0x007E, "latin de base"),
    (0x00A0, 0x00FF, "supplément latin-1 — accents français, « », °, ×, ÷"),
    (0x0100, 0x017F, "latin étendu A — œ, Œ, Ÿ, et les noms d'Europe centrale"),
    (0x0180, 0x024F, "latin étendu B"),
    (0x0370, 0x03FF, "grec — π des formules, et rien de plus cher"),
    (0x2000, 0x206F, "ponctuation générale — ’, —, …, •"),
    (0x20A0, 0x20BF, "monnaies — €"),
    (0x2100, 0x214F, "symboles de lettres — ™, №"),
    (0x2190, 0x21FF, "flèches — →, ↗, ↔"),
    (0x2200, 0x22FF, "opérateurs mathématiques — −, √, ≈, ≥"),
    (0x25A0, 0x25FF, "formes géométriques"),
]

UNICODES = sorted({cp for debut, fin, _ in PLAGES for cp in range(debut, fin + 1)})


def main() -> int:
    try:
        from fontTools import subset
    except ImportError:
        print("fontTools est requis : pip install fonttools", file=sys.stderr)
        return 1

    sources = sorted(SOURCE.glob("*.ttf"))
    if not sources:
        print(f"Aucune police source dans {SOURCE}", file=sys.stderr)
        return 1

    avant = apres = 0
    for src in sources:
        dst = CIBLE / src.name
        options = subset.Options()
        # Les fonctionnalités OpenType sont GARDÉES : `tnum` (chiffres
        # tabulaires) et `kern` en font partie, et le design system s'appuie
        # sur les premiers pour aligner les colonnes de chiffres.
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.recalc_bounds = True
        options.drop_tables = []
        font = subset.load_font(str(src), options)
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        subset.save_font(font, str(dst), options)
        font.close()
        avant += src.stat().st_size
        apres += dst.stat().st_size
        print(f"{src.name:26s} {src.stat().st_size:>9d} → {dst.stat().st_size:>8d} octets")

    gagne = avant - apres
    print(f"\nTOTAL {avant} → {apres} octets ({gagne} récupérés, {100 * gagne / avant:.1f} %)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
