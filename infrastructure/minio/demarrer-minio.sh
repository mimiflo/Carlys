#!/bin/sh
# Point d'entrée de l'image `minio` : le serveur S3 ne tourne PAS en root.
#
# POURQUOI. Le serveur MinIO détient toutes les photos, dont le bucket privé
# des repas, et son préfixe public est exposé sur internet (media.DOMAIN).
# Les images API et admin posent `USER node` ; celle-ci tournait en uid 0 :
# une faille d'exécution dans MinIO donnait root dans le conteneur, volume de
# données monté (audit du 25/09). Le serveur tourne désormais sous l'utilisateur
# `minio` (uid et gid 10001, hors de la plage des comptes humains de l'hôte).
#
# POURQUOI UN SCRIPT, ET PAS SEULEMENT `USER minio`. Les volumes minio-data des
# serveurs en service — et ceux des postes de développement — ont été remplis
# par l'image précédente, donc par ROOT. Un serveur lancé directement en
# `minio` n'y pourrait plus rien écrire, et refuserait de démarrer sur des
# médias bien réels : la mise à jour de l'image serait une panne. Le conteneur
# démarre donc en root le temps de RENDRE le volume à `minio`, une seule fois,
# puis abandonne ses droits avant de lancer le serveur. Aucune étape manuelle,
# sur aucun serveur ni aucun poste.
#
# « UNE SEULE FOIS » se juge au propriétaire du DOSSIER RACINE de /data, et il
# change EN DERNIER : un `chown` interrompu (conteneur tué, disque plein) est
# repris au démarrage suivant au lieu d'être cru terminé. Une fois migré, le
# démarrage ne coûte qu'un `stat`.
#
# Lancé autrement qu'en root (`user:` d'un compose, `--user`), il ne touche à
# rien et lance le serveur tel quel.
set -eu

DONNEES=/data
UTILISATEUR=minio

if [ "$(id -u)" = 0 ]; then
  if [ -d "$DONNEES" ] && [ "$(stat -c %U "$DONNEES")" != "$UTILISATEUR" ]; then
    echo "demarrer-minio : $DONNEES appartient à $(stat -c %U "$DONNEES"), rendu à $UTILISATEUR (une seule fois)"
    find "$DONNEES" -mindepth 1 \! -user "$UTILISATEUR" -exec chown "$UTILISATEUR:$UTILISATEUR" {} +
    chown "$UTILISATEUR:$UTILISATEUR" "$DONNEES"
  fi
  # `su` de busybox : l'environnement (MINIO_ROOT_USER…) est conservé, et le
  # shell qu'il lance se remplace par minio (`exec`) — minio reste le
  # processus 1 du conteneur et reçoit les signaux d'arrêt.
  exec su -s /bin/sh "$UTILISATEUR" -c 'exec minio "$@"' -- minio "$@"
fi
exec minio "$@"
