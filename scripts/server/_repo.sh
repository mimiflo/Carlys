# shellcheck shell=bash
# Le dépôt cloné sur le serveur, et lui seul.
#
# Séparé de _update.sh volontairement : celui-là déploie des IMAGES, celui-ci
# met à jour un CHECKOUT GIT. Deux sujets, deux modes de panne (un registre
# injoignable contre une branche divergée), et _update.sh passait déjà les
# 300 lignes.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# `update_run` déploie des IMAGES ; il n'a jamais touché au dépôt cloné dans
# /srv/carlys/repo. La conséquence se voyait mal et coûtait cher : les scripts,
# le compose et les fichiers d'exemple restaient figés au dernier `git pull`
# tapé à la main. Une variable ajoutée à un exemple n'arrivait donc jamais sur
# la machine, et `env-sync` — qui compare à cet exemple — n'avait rien de neuf
# à comparer. « Automatique » s'arrêtait à la porte du serveur.
#
# REMPLACER UN SCRIPT PENDANT QU'IL S'EXÉCUTE : mesuré avant d'être écrit.
# `git checkout` ne réécrit pas le fichier en place, il en crée un nouveau et
# le renomme par-dessus — l'inode change (2228650 → 2228655 dans l'essai). Le
# bash qui tourne garde son descripteur ouvert sur l'ANCIEN inode et termine sa
# passe sur l'ancien contenu, sans corruption. C'est la passe SUIVANTE qui
# utilise le nouveau code.
#
# `--ff-only`, et rien d'autre : un clone qui a divergé, ou qui porte des
# modifications locales, n'est pas rattrapé de force. On le signale et on n'y
# touche pas — écraser le travail de quelqu'un pour tenir une promesse
# d'automatisme serait le pire des deux mondes.
repo_pull() {
  local branche avant apres etat
  [ -d "$CARLYS_REPO_DIR/.git" ] || return 0

  branche="$(git -C "$CARLYS_REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$branche" ] || [ "$branche" = HEAD ]; then
    info "clone sur un commit détaché — laissé tel quel"
    return 0
  fi

  etat="$(git -C "$CARLYS_REPO_DIR" status --porcelain 2>/dev/null || true)"
  if [ -n "$etat" ]; then
    warn "le clone $CARLYS_REPO_DIR porte des modifications locales — PAS mis à jour"
    warn "  les voir : git -C $CARLYS_REPO_DIR status"
    return 0
  fi

  avant="$(git -C "$CARLYS_REPO_DIR" rev-parse HEAD 2>/dev/null || true)"
  if ! git -C "$CARLYS_REPO_DIR" pull --ff-only --quiet 2>/dev/null; then
    warn "git pull --ff-only a échoué sur $CARLYS_REPO_DIR (branche $branche)"
    warn "  soit le réseau, soit la branche a divergé — à regarder à la main"
    return 1
  fi

  apres="$(git -C "$CARLYS_REPO_DIR" rev-parse HEAD 2>/dev/null || true)"
  if [ "$avant" != "$apres" ]; then
    ok "clone mis à jour : ${avant:0:12} → ${apres:0:12} ($branche)"
    info "  la passe EN COURS finit sur les anciens scripts ; la suivante prendra ceux-ci"
  fi
  return 0
}

# La branche sur laquelle le clone est posé, ou rien s'il est détaché.
repo_branche() {
  local b
  b="$(git -C "$CARLYS_REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ "$b" = HEAD ] && b=''
  printf '%s' "$b"
}

# `repo_avertir_branches <.env>` — l'incohérence qui a produit le recul
# du 10 septembre 2026, signalée AVANT qu'elle ne coûte quelque chose.
#
# Deux branches entrent en jeu et personne ne les rapproche : celle dont
# `update_run` tire les IMAGES (CARLYS_UPDATE_BRANCH, `main` par défaut) et
# celle sur laquelle le clone est posé, d'où viennent les SCRIPTS et les
# fichiers d'exemple. Tant qu'elles diffèrent, le serveur exécute le code d'une
# branche contre les images d'une autre — et si la branche suivie est en
# retard, la mise à jour automatique fait reculer la pile.
#
# Ne dit rien tant que la mise à jour automatique est éteinte : sans elle, la
# branche suivie ne sert à rien et l'avertissement ne serait que du bruit.
repo_avertir_branches() {
  local file="$1" suivie clone
  [ "$(update_actif "$file")" = oui ] || return 0
  clone="$(repo_branche)"
  [ -n "$clone" ] || return 0
  suivie="$(update_branche "$file")"
  [ "$suivie" != "$clone" ] || return 0
  warn "  mise à jour auto ACTIVE, et les deux branches DIVERGENT :"
  warn "        images suivies  : $suivie"
  warn "        scripts du clone : $clone"
  warn "  Le serveur exécuterait les scripts d'une branche contre les images"
  warn "  d'une autre. Si « $suivie » est en retard, la pile RECULE."
  warn "  Aligner l'une sur l'autre :"
  warn "    echo 'CARLYS_UPDATE_BRANCH=$clone' | sudo tee -a $file"
  return 1
}
