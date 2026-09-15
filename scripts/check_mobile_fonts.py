#!/usr/bin/env python3
"""Les polices embarquées couvrent-elles ce que l'application affiche ?

Les neuf TTF de `apps/mobile/assets/fonts/` sont SOUS-ENSEMBLÉES
(`apps/mobile/tools/subset_fonts.py`) : Flutter ne le fait pas lui-même pour
les polices de texte, et les versions complètes emportaient 2,99 Mo dans
l'APK, dont du cyrillique, du grec et du vietnamien pour une application
déclarée monolingue française.

Un sous-ensemble se dégrade en silence : un glyphe absent ne donne pas un
carré vide, Flutter retombe sur la police système, et le changement de dessin
passe inaperçu à la relecture. Ce script est donc la garde — il lit la table
`cmap` de chaque police, sans aucune dépendance (ni fontTools, ni pip), et
refuse :

1. qu'un caractère du socle — latin de base, lettres accentuées, œ — manque
   à une police de TEXTE, parce que l'application affiche aussi ce que les
   gens saisissent (noms d'exercices, de repas, d'amis), pas seulement ses
   propres libellés ;
2. que le sous-ensemble ait PERDU un caractère que l'original portait et que
   le code emploie.

La seconde règle se compare à `tools/fonts-source/`, et c'est ce qui la rend
juste : demander à une police de couvrir ce qu'elle n'a jamais eu ferait
échouer le contrôle pour un défaut qui n'existe pas. Oswald, police
d'affichage des citations, n'a jamais porté de flèches ; le « ⋈ » du code ne
vit que dans un commentaire de `workout_mappers.dart`, et Inter ne l'a jamais
eu non plus.

Usage : `python3 scripts/check_mobile_fonts.py` depuis la racine du dépôt.
"""

from __future__ import annotations

import pathlib
import struct
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
POLICES = RACINE / "apps" / "mobile" / "assets" / "fonts"
ORIGINALES = RACINE / "apps" / "mobile" / "tools" / "fonts-source"
SOURCES = RACINE / "apps" / "mobile" / "lib"
DONNEES = RACINE / "apps" / "mobile" / "assets"

# Le socle : ce qu'une police de TEXTE doit couvrir quoi qu'il arrive, pour
# que le contenu saisi par les gens s'affiche dans la bonne fonte.
SOCLE: list[tuple[int, int, str]] = [
    (0x0020, 0x007E, "latin de base"),
    (0x00C0, 0x00FF, "lettres accentuées du supplément latin-1"),
    (0x0152, 0x0153, "œ et Œ"),
]

# JetBrains Mono ne sert qu'aux CHIFFRES et aux majuscules d'étiquette
# (`AppTypography.labelMono`) : lui demander la couverture d'une police de
# texte n'aurait pas de sens. Oswald ne sert qu'aux citations.
MONOSPACE = "JetBrainsMono"


def lire_cmap(chemin: pathlib.Path) -> set[int]:
    """Les points de code d'une police TrueType, lus à la main.

    Ne gère que les formats de sous-table 4 et 12, les seuls qu'emploient les
    polices de ce dépôt (BMP et hors-BMP en Unicode). Une police dont aucune
    sous-table n'est lisible lève : mieux vaut un échec bruyant qu'une
    couverture supposée vide.
    """
    octets = chemin.read_bytes()
    (nb_tables,) = struct.unpack_from(">H", octets, 4)
    debut_cmap = None
    for i in range(nb_tables):
        offset = 12 + i * 16
        balise = octets[offset : offset + 4]
        if balise == b"cmap":
            (debut_cmap,) = struct.unpack_from(">I", octets, offset + 8)
            break
    if debut_cmap is None:
        raise ValueError(f"{chemin.name} : aucune table cmap")

    (nb_sous,) = struct.unpack_from(">H", octets, debut_cmap + 2)
    points: set[int] = set()
    lues = 0
    for i in range(nb_sous):
        base = debut_cmap + 4 + i * 8
        plateforme, encodage, decalage = struct.unpack_from(">HHI", octets, base)
        # Unicode (3,1) et (3,10), ou la plateforme Unicode (0,*).
        if not (plateforme == 0 or (plateforme == 3 and encodage in (1, 10))):
            continue
        table = debut_cmap + decalage
        (format_,) = struct.unpack_from(">H", octets, table)
        if format_ == 4:
            points |= _format4(octets, table)
            lues += 1
        elif format_ == 12:
            points |= _format12(octets, table)
            lues += 1
    if lues == 0:
        raise ValueError(f"{chemin.name} : aucune sous-table cmap exploitable")
    return points


def _format4(octets: bytes, table: int) -> set[int]:
    (seg_x2,) = struct.unpack_from(">H", octets, table + 6)
    segments = seg_x2 // 2
    fins = struct.unpack_from(f">{segments}H", octets, table + 14)
    debuts = struct.unpack_from(f">{segments}H", octets, table + 16 + seg_x2)
    points: set[int] = set()
    for debut, fin in zip(debuts, fins):
        if debut == 0xFFFF:
            continue
        points.update(range(debut, fin + 1))
    return points


def _format12(octets: bytes, table: int) -> set[int]:
    (nb_groupes,) = struct.unpack_from(">I", octets, table + 12)
    points: set[int] = set()
    for i in range(nb_groupes):
        debut, fin, _ = struct.unpack_from(">III", octets, table + 16 + i * 12)
        points.update(range(debut, fin + 1))
    return points


def caracteres_du_code() -> set[int]:
    """Tout caractère non-ASCII écrit dans le code ou les données livrées."""
    trouves: set[int] = set()
    fichiers = list(SOURCES.rglob("*.dart")) + list(DONNEES.rglob("*.json"))
    for fichier in fichiers:
        try:
            texte = fichier.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        trouves.update(ord(c) for c in texte if ord(c) > 0x7F)
    return trouves


def main() -> int:
    if not POLICES.is_dir():
        print(f"Dossier de polices introuvable : {POLICES}", file=sys.stderr)
        return 1

    socle = {cp for debut, fin, _ in SOCLE for cp in range(debut, fin + 1)}
    # Les caractères de dessin de boîte (les séparateurs ─ des commentaires)
    # et les emoji ne sont pas rendus par ces polices : le premier n'apparaît
    # que dans du commentaire, le second passe par la fonte d'emoji du
    # système, déclarée en repli dans `AppTypography`.
    du_code = {
        cp
        for cp in caracteres_du_code()
        if not (0x2500 <= cp <= 0x257F) and cp < 0x1F000
    }

    erreurs: list[str] = []
    for police in sorted(POLICES.glob("*.ttf")):
        couverts = lire_cmap(police)
        original = ORIGINALES / police.name
        if not original.is_file():
            erreurs.append(f"  {police.name} : original absent de {ORIGINALES}")
            continue
        avant = lire_cmap(original)

        # Le socle est EXIGÉ des polices de texte, quoi qu'il arrive.
        exige = set() if MONOSPACE in police.name else set(socle)
        # Le reste se mesure par rapport à l'original : on ne reproche à un
        # sous-ensemble que ce qu'il a fait DISPARAÎTRE.
        exige |= (socle | du_code) & avant

        manquants = sorted(exige - couverts)
        if manquants:
            apercu = ", ".join(f"U+{cp:04X} {chr(cp)!r}" for cp in manquants[:12])
            reste = "" if len(manquants) <= 12 else f" (+{len(manquants) - 12})"
            erreurs.append(f"  {police.name} : {len(manquants)} perdu(s) — {apercu}{reste}")
        else:
            gain = original.stat().st_size - police.stat().st_size
            print(
                f"  {police.name:26s} {len(couverts):>5d} points de code "
                f"(sur {len(avant)}), {gain:>7d} octets de moins"
            )

    if erreurs:
        print("\nPolices INCOMPLÈTES :", file=sys.stderr)
        print("\n".join(erreurs), file=sys.stderr)
        print(
            "\nÉlargir les plages de apps/mobile/tools/subset_fonts.py, puis\n"
            "relancer `python3 tools/subset_fonts.py` depuis apps/mobile.",
            file=sys.stderr,
        )
        return 1

    print("\nToutes les polices couvrent ce que l'application affiche.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
