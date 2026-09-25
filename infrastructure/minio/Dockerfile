# MinIO et mc, construits DEPUIS LEURS SOURCES — aucune image MinIO tierce.
#
# Contexte de build : CE DOSSIER (infrastructure/minio), pas la racine du dépôt.
#   docker build --target minio -t carlys-minio infrastructure/minio
#   docker build --target mc    -t carlys-mc    infrastructure/minio
#
# Pourquoi : README.md de ce dossier (les images officielles ont disparu de
# Docker Hub, puis de quay.io). Les versions ne s'écrivent PAS ici mais dans
# versions.env ; la recette de construction non plus, mais dans construire.sh,
# que api-ci exécute à l'identique. Les deux images publiées (images-publish)
# sont étiquetées par l'empreinte de ces trois fichiers.
#
# Deux cibles :
#   mc     le client seul, avec /bin/sh : minio-init (création des buckets) et
#          la sauvegarde nocturne (scripts/server/backup.sh) l'appellent par
#          `/bin/sh -c`.
#   minio  le serveur, AVEC mc : la sonde de santé des deux fichiers compose
#          est `mc ready local`, exécutée DANS le conteneur du serveur — comme
#          l'image officielle, qui embarquait mc pour la même raison.
# `minio` est la dernière cible : c'est elle qu'un build sans --target produit.
#
# UTILISATEUR : root, comme l'image quay.io que celle-ci remplace, et c'est
# délibéré. Le volume minio-data des serveurs en service a été rempli par
# cette image-là, donc par root : un utilisateur non privilégié n'y pourrait
# plus écrire, et MinIO refuserait de démarrer sur des médias bien réels. Et
# backup.sh fait écrire `mc mirror` dans un répertoire de l'hôte en mode 700,
# propriété de root. Passer en non-root reste possible, mais c'est un chantier
# à part (chown du volume sur chaque serveur, répertoire de sauvegarde
# accessible) — pas l'effet de bord d'un changement de registre.

# ── Construction ─────────────────────────────────────────────────────────────
# Toute image de ce fichier est ÉPINGLÉE PAR EMPREINTE : un tag Docker se
# déplace, une empreinte non. La version de Go DOIT égaler
# CARLYS_MINIO_GO_VERSION (versions.env) : construire.sh le vérifie et refuse
# de construire sinon.
#
# CE QUE LA CONSTRUCTION TIRE, au complet : les deux images de base de ce
# fichier (golang et alpine — images OFFICIELLES de Docker Hub, épinglées par
# empreinte), les sources depuis github.com et les modules Go depuis
# proxy.golang.org. Aucune image MinIO, d'aucun registre ; mais un poste sans
# accès à Docker Hub ne construit pas ce fichier.
#
# La variante Debian de l'image golang, et non l'Alpine : elle embarque déjà
# git (et les certificats racine). Aucun miroir de paquets — ni apk, ni apt —
# ne s'ajoute donc à la liste ci-dessus. Un service tiers de moins sur le
# chemin, dans un fichier qui existe parce que deux services tiers sont
# tombés. Les binaires étant statiques, la distribution de cet étage ne
# se retrouve pas dans l'image finale.
FROM golang:1.24.13-trixie@sha256:5835f052b784aa39f2fe9070def3568605c8bc3fcd810f10402066348b61e716 AS construction
WORKDIR /recette
COPY versions.env construire.sh ./
RUN sh construire.sh minio /sortie
RUN sh construire.sh mc /sortie

# ── Client mc ────────────────────────────────────────────────────────────────
# Les binaires sont statiques : l'image finale n'a besoin que d'un /bin/sh et
# des certificats racine, qu'Alpine fournit.
FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS mc
COPY --from=construction /sortie/mc /usr/bin/mc
# LICENSE, CREDITS et SOURCE (dépôt, tag, commit, Go) : l'AGPLv3 veut que la
# source correspondante reste désignable depuis ce qu'on exécute.
COPY --from=construction /sortie/licences/mc /licenses/mc
ENTRYPOINT ["mc"]

# ── Serveur minio (+ mc) ─────────────────────────────────────────────────────
FROM mc AS minio
COPY --from=construction /sortie/minio /usr/bin/minio
COPY --from=construction /sortie/licences/minio /licenses/minio
EXPOSE 9000 9001
VOLUME ["/data"]
# Les deux compose passent `server /data --console-address :9001` ; l'image
# officielle préfixait déjà ses arguments de `minio`, celle-ci aussi.
ENTRYPOINT ["minio"]
CMD ["server", "/data"]
