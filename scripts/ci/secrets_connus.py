#!/usr/bin/env python3
"""Verdict de TruffleHog, moins les faux positifs déjà relus.

    secrets_connus.py <résultats.jsonl> <liste.txt>

Lit la sortie `--json` de TruffleHog (une découverte par ligne) et sort en
erreur si une découverte n'est PAS dans la liste des faux positifs relus.

Pourquoi une liste, et pas `--exclude-paths` : le scan du lundi relit TOUT
l'historique, et un commit publié ne se réécrit pas. Les fausses adresses
d'exemple des tests (`https://nom:…@gpu.exemple/v1`), et l'une d'elles dans
un MESSAGE de commit, que `--exclude-paths` ne peut pas désigner,
y reviennent donc chaque semaine. Exclure un chemin laisserait aussi passer
tout vrai secret ajouté plus tard au même fichier. Une entrée de la liste
désigne UNE découverte (commit, détecteur, fichier, ligne) : la même valeur
recopiée ailleurs, ou dans un autre commit, fait échouer la porte.
"""

import json
import sys


def cle(decouverte: dict) -> str:
    git = decouverte["SourceMetadata"]["Data"]["Git"]
    fichier = git.get("file") or "<message>"
    return f'{git["commit"]} {decouverte["DetectorName"]} {fichier}:{git.get("line", 0)}'


def relus(chemin: str) -> set[str]:
    with open(chemin, encoding="utf-8") as liste:
        lignes = (ligne.split("#", 1)[0].strip() for ligne in liste)
        return {" ".join(ligne.split()) for ligne in lignes if ligne}


def main(resultats: str, liste: str) -> int:
    connus = relus(liste)
    inconnues = []
    with open(resultats, encoding="utf-8") as sortie:
        for ligne in sortie:
            ligne = ligne.strip()
            # TruffleHog écrit aussi ses journaux : seules les lignes JSON qui
            # portent un détecteur sont des découvertes.
            if not ligne.startswith("{"):
                continue
            decouverte = json.loads(ligne)
            if "DetectorName" in decouverte and cle(decouverte) not in connus:
                inconnues.append(decouverte)
    for d in inconnues:
        print(f"SECRET : {cle(d)} — {d.get('Redacted') or 'valeur masquée'}")
    if inconnues:
        print(
            f"{len(inconnues)} découverte(s) hors de {liste}. Un vrai secret se "
            "révoque puis se retire de l'historique ; un faux positif relu "
            "s'ajoute à la liste, avec sa raison."
        )
        return 1
    print(f"Aucun secret hors des {len(connus)} faux positifs relus.")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
