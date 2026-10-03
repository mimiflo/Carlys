#!/usr/bin/env python3
"""Carte du code Carlys : une page HTML qui montre les modules du dépôt et
qui dépend de qui, construite sur le graphe de graphify.

    python3 scripts/carte_du_code.py [sortie.html]   # défaut : graphify-out/carte.html

Un nœud = un module : `apps/api/src/modules/<m>`, `apps/mobile/lib/features/<f>`,
une route de l'admin, un paquet ; les dossiers transverses (common, core,
design_system, lib…) sont des modules à part. Une arête = des imports d'un
module vers un autre, pondérés par leur nombre. Les tests sont exclus : la
carte montre l'application, pas ce qui la vérifie.

Les imports TypeScript viennent de `graphify-out/graph.json`, qui les résout.
Les imports Dart sont relus dans les sources : graphify les garde sous leur
chaîne brute, sans le fichier visé (CLAUDE.md, section Graphify).
"""
import json
import posixpath
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
GABARIT = Path(__file__).with_name("carte_du_code.html")
IMPORT_DART = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
TS_RELATIONS = {"imports", "imports_from"}


def est_test(chemin: str) -> bool:
    return bool(
        re.search(r"(\.spec\.ts|\.test\.tsx?|\.e2e-spec\.ts|_test\.dart)$", chemin)
        or re.match(r"apps/(api|mobile)/test/", chemin)
        or "/testing/" in chemin
    )


def module_de(chemin: str) -> tuple[str, str] | None:
    """(appli, module) du fichier, ou None s'il n'est pas du code applicatif."""
    if est_test(chemin) or not re.search(r"\.(ts|tsx|dart)$", chemin):
        return None
    for prefixe, appli in (
        ("apps/api/src/modules/", "api"),
        ("apps/mobile/lib/features/", "mobile"),
        ("apps/admin/src/app/", "admin"),
    ):
        if chemin.startswith(prefixe):
            reste = chemin[len(prefixe):]
            return (appli, reste.split("/")[0] if "/" in reste else "accueil")
    for prefixe, appli in (
        ("apps/api/src/", "api"),
        ("apps/mobile/lib/", "mobile"),
        ("apps/admin/src/", "admin"),
    ):
        if chemin.startswith(prefixe):
            reste = chemin[len(prefixe):]
            return (appli, reste.split("/")[0] if "/" in reste else "démarrage")
    m = re.match(r"packages/([^/]+)/src/", chemin)
    return ("paquets", m.group(1)) if m else None


def imports_dart(fichier: str) -> list[str]:
    """Fichiers de lib/ importés par un fichier Dart, chemins résolus."""
    texte = (RACINE / fichier).read_text(encoding="utf-8")
    cibles = []
    for brut in IMPORT_DART.findall(texte):
        if brut.startswith("package:carlys_mobile/"):
            cibles.append("apps/mobile/lib/" + brut.removeprefix("package:carlys_mobile/"))
        elif not re.match(r"^(package|dart):", brut):
            cibles.append(posixpath.normpath(posixpath.join(posixpath.dirname(fichier), brut)))
    return cibles


def construire() -> dict:
    graphe = json.loads((RACINE / "graphify-out/graph.json").read_text(encoding="utf-8"))
    par_id = {n["id"]: n for n in graphe["nodes"]}
    fichiers = sorted({n["source_file"] for n in graphe["nodes"] if n.get("source_file")})
    fichiers += sorted(
        str(p.relative_to(RACINE)) for p in (RACINE / "apps/mobile/lib").rglob("*.dart")
    )
    fichiers = sorted(set(fichiers))

    contenu: dict[tuple, list[str]] = defaultdict(list)
    lignes: Counter = Counter()
    for f in fichiers:
        mod = module_de(f)
        if mod and (RACINE / f).is_file():
            contenu[mod].append(f)
            lignes[mod] += sum(1 for _ in (RACINE / f).open(encoding="utf-8"))

    liens: Counter = Counter()
    vus = set()
    for lien in graphe["links"]:
        if lien.get("relation") not in TS_RELATIONS:
            continue
        cible = (par_id.get(lien["target"]) or {}).get("source_file")
        source = lien.get("source_file")
        if source and cible and (source, cible) not in vus:
            vus.add((source, cible))
    for f in (f for mod in contenu for f in contenu[mod] if f.endswith(".dart")):
        for cible in imports_dart(f):
            vus.add((f, cible))
    for source, cible in vus:
        a, b = module_de(source), module_de(cible)
        if a and b and a != b and a in contenu and b in contenu:
            liens[(a, b)] += 1

    ident = {mod: f"{mod[0]}:{mod[1]}" for mod in contenu}
    commit = subprocess.run(
        ["git", "-C", str(RACINE), "rev-parse", "--short", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return {
        "commit": commit,
        "graphe_commit": str(graphe.get("built_at_commit", ""))[:7],
        "genere_le": datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC"),
        "modules": [
            {
                "id": ident[mod],
                "appli": mod[0],
                "nom": mod[1],
                "fichiers": sorted(contenu[mod]),
                "lignes": lignes[mod],
            }
            for mod in sorted(contenu)
        ],
        "liens": [
            {"de": ident[a], "vers": ident[b], "imports": n}
            for (a, b), n in sorted(liens.items())
        ],
    }


def main() -> None:
    sortie = Path(sys.argv[1]) if len(sys.argv) > 1 else RACINE / "graphify-out/carte.html"
    donnees = json.dumps(construire(), ensure_ascii=False, separators=(",", ":"))
    # `</` fermerait la balise <script> qui porte les données.
    page = GABARIT.read_text(encoding="utf-8").replace(
        "/*DONNEES*/null", donnees.replace("</", "<\\/")
    )
    sortie.write_text(page, encoding="utf-8")
    print(f"Carte écrite : {sortie}")


if __name__ == "__main__":
    main()
