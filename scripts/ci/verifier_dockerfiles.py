#!/usr/bin/env python3
"""Les Dockerfile de l'API et de l'admin installent AVANT de copier les sources,
et toute image de base externe du dépôt est épinglée par empreinte.

    python3 scripts/ci/verifier_dockerfiles.py [racine du dépôt]

POURQUOI. L'installation (`pnpm install`) ne dépend que du lockfile et des
package.json. Copiée APRÈS les sources, elle se rejouait à chaque commit ; et
`COPY packages ./packages` la rejouait pour des paquets que l'application
n'utilise pas (design-tokens, ui) — un commit de tokens.json reconstruisait
l'image de l'API de zéro (audit du 25/09). Les Dockerfile copient donc les
manifestes des SEULS paquets utiles, installent, puis copient les sources.

Le revers : la liste des paquets est écrite à la main dans chaque Dockerfile.
Ce script la confronte à la vérité — la fermeture des dépendances
`workspace:` de l'application, lue dans les package.json — et vérifie l'ordre.
Il échoue si :
  - un paquet de workspace utilisé n'a pas son manifeste copié avant
    l'installation (l'installation échouerait), ou ses sources après ;
  - une source est copiée AVANT l'installation (le cache serait perdu) ;
  - `packages` est copié en entier ;
  - pour l'admin, un argument de build est posé avant l'installation.

ÉPINGLAGE. Un `FROM` qui ne désigne pas un étage du même fichier doit porter
`@sha256:<64 hex>` : une étiquette (`node:22-alpine`) se déplace, une
empreinte non — un build ne tire alors jamais une image qu'on n'a pas relue.
Vaut pour CHAQUE Dockerfile versionné (API, admin, MinIO…), pas seulement
les deux ci-dessus. Dependabot (écosystème docker) monte celles de Node ;
MinIO les monte à la main, avec versions.env.

Rend 0 si tout va bien, 1 sinon, en nommant chaque écart.
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2])
APPLICATIONS = {"api": "@carlys/api", "admin": "@carlys/admin"}
ARGUMENTS_TARDIFS = {"admin": ["NEXT_PUBLIC_API_BASE_URL", "LEGAL_PLACEHOLDERS"]}


def paquets_du_workspace() -> dict[str, str]:
    """nom npm → dossier relatif, pour chaque paquet du workspace."""
    trouves = {}
    for manifeste in list(RACINE.glob("packages/*/package.json")) + list(RACINE.glob("apps/*/package.json")):
        nom = json.loads(manifeste.read_text(encoding="utf-8")).get("name")
        if nom:
            trouves[nom] = manifeste.parent.relative_to(RACINE).as_posix()
    return trouves


def fermeture(nom: str, tous: dict[str, str]) -> set[str]:
    """Les dossiers des paquets de workspace dont `nom` dépend, lui compris."""
    vus, a_voir = set(), [nom]
    while a_voir:
        courant = a_voir.pop()
        if courant in vus:
            continue
        vus.add(courant)
        donnees = json.loads((RACINE / tous[courant] / "package.json").read_text(encoding="utf-8"))
        for champ in ("dependencies", "devDependencies"):
            for dep, version in donnees.get(champ, {}).items():
                if str(version).startswith("workspace:") and dep in tous:
                    a_voir.append(dep)
    return {tous[n] for n in vus}


def etage_build(texte: str) -> list[str]:
    """Les instructions de l'étage `build`, lignes de continuation jointes."""
    lignes, courant, dans_build = [], "", False
    for brute in texte.splitlines():
        ligne = brute.strip()
        if not ligne or ligne.startswith("#"):
            continue
        courant = f"{courant} {ligne[:-1]}" if ligne.endswith("\\") else f"{courant} {ligne}"
        if ligne.endswith("\\"):
            continue
        instruction, courant = courant.strip(), ""
        if instruction.upper().startswith("FROM "):
            dans_build = bool(re.search(r"\bAS\s+build\b", instruction, re.I))
            continue
        if dans_build:
            lignes.append(instruction)
    return lignes


def verifier(app: str, nom: str, tous: dict[str, str]) -> list[str]:
    ecarts = []
    fichier = RACINE / "apps" / app / "Dockerfile"
    instructions = etage_build(fichier.read_text(encoding="utf-8"))
    rang_install = next((i for i, l in enumerate(instructions) if "pnpm install" in l), None)
    if rang_install is None:
        return [f"{fichier} : aucun `pnpm install` dans l'étage build"]
    avant, apres = instructions[:rang_install], instructions[rang_install + 1:]
    copies_avant = [l.split()[1] for l in avant if l.upper().startswith("COPY ")]
    copies_apres = [l.split()[1] for l in apres if l.upper().startswith("COPY ")]

    for dossier in sorted(fermeture(nom, tous)):
        if f"{dossier}/package.json" not in copies_avant:
            ecarts.append(f"{fichier} : {dossier}/package.json n'est pas copié AVANT `pnpm install` "
                          f"(dépendance de workspace de {nom}) — l'installation échouerait")
        if dossier not in copies_apres:
            ecarts.append(f"{fichier} : les sources de {dossier} ne sont pas copiées APRÈS `pnpm install`")
    for source in copies_avant:
        if not (source.endswith("package.json") or source in {"pnpm-workspace.yaml", "pnpm-lock.yaml", ".npmrc"}):
            ecarts.append(f"{fichier} : `COPY {source}` AVANT `pnpm install` — l'installation se rejouerait "
                          "à chaque changement de ces fichiers")
    if any(re.match(r"COPY\s+packages\s", l) for l in instructions):
        ecarts.append(f"{fichier} : `COPY packages` entier — un commit de design-tokens ou de ui "
                      "invaliderait l'installation")
    for argument in ARGUMENTS_TARDIFS.get(app, []):
        if any(re.match(rf"(ARG|ENV)\s+{argument}\b", l) for l in avant):
            ecarts.append(f"{fichier} : {argument} posé AVANT `pnpm install` — changer sa valeur "
                          "rejouerait l'installation")
    return ecarts


def images_non_epinglees(fichier: Path) -> list[str]:
    """Les `FROM` d'image externe sans empreinte (un étage déjà nommé n'en est pas une)."""
    ecarts, etages = [], set()
    for ligne in fichier.read_text(encoding="utf-8").splitlines():
        mots = ligne.split()
        if not mots or mots[0].upper() != "FROM":
            continue
        mots = [m for m in mots[1:] if not m.startswith("--")]  # --platform=…
        image = mots[0] if mots else ""
        externe = image.lower() not in etages and image != "scratch"
        if len(mots) >= 3 and mots[1].upper() == "AS":
            etages.add(mots[2].lower())
        if externe and not re.search(r"@sha256:[0-9a-f]{64}$", image):
            ecarts.append(f"{fichier.relative_to(RACINE)} : `FROM {image}` n'est pas épinglé par empreinte "
                          "(attendu image:version@sha256:<index multi-architecture>)")
    return ecarts


def dockerfiles() -> list[Path]:
    return sorted(f for f in RACINE.rglob("Dockerfile")
                  if not {"node_modules", ".git", "graphify-out"} & set(f.relative_to(RACINE).parts))


def main() -> int:
    tous = paquets_du_workspace()
    ecarts = []
    for app, nom in APPLICATIONS.items():
        ecarts += verifier(app, nom, tous)
    for fichier in dockerfiles():
        ecarts += images_non_epinglees(fichier)
    for ecart in ecarts:
        print(f"ÉCART  {ecart}", file=sys.stderr)
    if not ecarts:
        print("ok  les Dockerfile de l'API et de l'admin installent avant de copier leurs sources, "
              "et copient exactement les paquets de workspace qu'ils utilisent ; "
              f"les images de base des {len(dockerfiles())} Dockerfile sont épinglées par empreinte")
    return 1 if ecarts else 0


if __name__ == "__main__":
    sys.exit(main())
