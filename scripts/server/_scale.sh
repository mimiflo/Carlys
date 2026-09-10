# shellcheck shell=bash
# Décider — et appliquer — le nombre d'exemplaires de l'API.
#
# CE QUI REND CETTE DÉCISION DIFFICILE, ce n'est pas la formule, c'est
# l'oscillation. Un superviseur qui suit la charge à la lettre ajoute un
# exemplaire au premier pic, le retire au premier creux, et recommence : la
# pile passe son temps à démarrer et arrêter des processus, chaque
# redémarrage coûte un cache froid, et le service est PLUS lent qu'avec un
# nombre fixe. Les trois garde-fous ci-dessous n'existent que pour ça :
#
#   - un DÉLAI DE GARDE après chaque changement, dans les deux sens ;
#   - de la PATIENCE avant de réduire : il faut plusieurs passages d'accord
#     pour retirer un exemplaire, alors qu'un seul suffit pour en ajouter.
#     L'asymétrie est voulue — se tromper en ajoutant coûte de la mémoire,
#     se tromper en retirant coûte des erreurs servies à des utilisateurs ;
#   - un PLAFOND qui ne dépend pas de la charge : la machine a un nombre de
#     cœurs, la plage de ports une taille, et aucune mesure ne doit faire
#     dépasser ces deux-là.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# ── Réglages, lus dans le .env de l'environnement ───────────────────────────
scale_min()      { env_value CARLYS_SCALE_MIN "$1" 1; }
scale_users_par_exemplaire() { env_value CARLYS_SCALE_USERS_PER_REPLICA "$1" 250; }
scale_rps_par_exemplaire()   { env_value CARLYS_SCALE_RPS_PER_REPLICA "$1" 40; }
scale_latence_haute_ms()     { env_value CARLYS_SCALE_LATENCY_HIGH_MS "$1" 750; }
scale_delai_de_garde()       { env_value CARLYS_SCALE_COOLDOWN_SECONDS "$1" 300; }
scale_patience_baisse()      { env_value CARLYS_SCALE_DOWN_PATIENCE "$1" 3; }

# Plafond. Le .env peut le fixer ; sinon il se DÉDUIT de la machine.
#
# `nproc` comme défaut, et non un chiffre écrit en dur : l'API est un
# processus Node, mono-thread pour le code utilisateur. Au-delà d'un
# exemplaire par cœur, les exemplaires se disputent le même processeur — on
# paie la mémoire de chacun sans gagner de débit. Un exploitant qui mesure
# autre chose (charge très liée aux entrées-sorties, cœurs partagés) relève la
# valeur en connaissance de cause.
#
# Et dans tous les cas, jamais plus que la plage de ports : au-delà, Docker
# échoue en cours de route et laisse la pile à moitié mise à l'échelle.
scale_max() {
  local env_name="$1" file="$2" declare_ capacite coeurs
  capacite="$(api_port_capacity "$env_name" "$file")"
  declare_="$(env_value CARLYS_SCALE_MAX "$file" '')"
  if [ -z "$declare_" ]; then
    coeurs="$(nproc 2>/dev/null || printf '2')"
    declare_="$coeurs"
  fi
  [ "$declare_" -lt 1 ] && declare_=1
  [ "$declare_" -gt "$capacite" ] && declare_="$capacite"
  printf '%d' "$declare_"
}

# `scale_cible <utilisateurs> <requêtes/s> <par_utilisateurs> <par_rps>`
#
# Le maximum des deux besoins, jamais leur somme : ce sont deux façons de
# mesurer LA MÊME charge. Les additionner doublerait la pile pour un seul pic.
# Une valeur inconnue (-1 pour les utilisateurs, vide pour le débit) ne
# compte pas — elle ne doit ni gonfler ni écraser la cible.
scale_cible() {
  awk -v u="$1" -v rps="$2" -v pu="$3" -v pr="$4" '
    BEGIN {
      cible = 1
      if (u >= 0 && pu > 0)   { n = int((u + pu - 1) / pu);       if (n > cible) cible = n }
      if (rps != "" && pr > 0) { n = int((rps + pr - 1) / pr);    if (n > cible) cible = n }
      print cible
    }'
}

# `scale_decide <env> <.env> <exemplaires actuels> <utilisateurs> <rps> <latence_ms>`
#
# Rend une ligne : `<cible> <verdict> <raison> <votes_baisse>` où verdict vaut
# `monter`, `descendre`, `garder` ou `attendre`.
#
# `attendre` n'est pas `garder` : il dit qu'un changement SERAIT justifié mais
# que le délai de garde ou la patience l'en empêche. La distinction n'est pas
# cosmétique — elle est ce que lira l'exploitant qui se demande pourquoi la
# pile ne bouge pas alors que la charge monte.
#
# ELLE N'ÉCRIT RIEN. Le compte de votes qu'elle rend en quatrième position est
# ce que l'état DEVRAIT valoir si la décision est retenue ; c'est l'appelant
# qui l'inscrit. Une fonction de décision qui mémorise ne peut plus être
# appelée pour un simple « qu'est-ce que tu ferais ? » sans changer le
# comportement du tour suivant.
scale_decide() {
  local env_name="$1" file="$2" actuel="$3" utilisateurs="$4" rps="$5" latence="$6"
  local mini maxi cible depuis patience votes latence_haute

  mini="$(scale_min "$file")"
  maxi="$(scale_max "$env_name" "$file")"
  latence_haute="$(scale_latence_haute_ms "$file")"
  cible="$(scale_cible "$utilisateurs" "$rps" \
    "$(scale_users_par_exemplaire "$file")" "$(scale_rps_par_exemplaire "$file")")"

  # La latence ne dit pas COMBIEN d'exemplaires il faut, elle dit que ceux qui
  # tournent n'y arrivent pas. Elle ne fixe donc pas la cible : elle force un
  # cran de plus. Une pile qui rame sans que le débit l'explique — requêtes
  # lentes, base sous tension — a besoin d'aide, mais pas de tripler.
  if [ -n "$latence" ] && awk -v l="$latence" -v h="$latence_haute" 'BEGIN { exit !(l > h) }'; then
    [ "$cible" -le "$actuel" ] && cible=$((actuel + 1))
  fi

  [ "$cible" -lt "$mini" ] && cible="$mini"
  [ "$cible" -gt "$maxi" ] && cible="$maxi"

  if [ "$cible" -eq "$actuel" ]; then
    printf '%d garder charge-stable 0\n' "$cible"
    return 0
  fi

  # Délai de garde : commun aux deux sens. Le compte de votes est REMIS À ZÉRO
  # pendant l'attente — sinon trois passages bloqués par le délai vaudraient
  # trois passages d'accord, et la réduction partirait dès la levée du délai
  # sans qu'aucune mesure libre l'ait confirmée.
  depuis="$(state_get "$env_name" dernier_changement 0)"
  if [ "$(($(maintenant) - depuis))" -lt "$(scale_delai_de_garde "$file")" ]; then
    printf '%d attendre delai-de-garde 0\n' "$actuel"
    return 0
  fi

  if [ "$cible" -gt "$actuel" ]; then
    printf '%d monter charge-en-hausse 0\n' "$cible"
    return 0
  fi

  # Descendre : il faut plusieurs passages d'accord.
  patience="$(scale_patience_baisse "$file")"
  votes="$(state_get "$env_name" votes_baisse 0)"
  votes=$((votes + 1))
  if [ "$votes" -lt "$patience" ]; then
    printf '%d attendre patience-%d-sur-%d %d\n' "$actuel" "$votes" "$patience" "$votes"
    return 0
  fi
  printf '%d descendre charge-en-baisse 0\n' "$cible"
}

# `scale_apply <env> <.env> <n>` — pose le nombre et le fait vivre.
#
# L'ORDRE COMPTE. Le .env est écrit AVANT `up -d` parce que c'est lui que
# Compose interpole : l'écrire après ferait mentir le fichier pendant tout
# l'intervalle, et un `docker compose up -d` tapé entre-temps par quelqu'un
# d'autre ramènerait l'ancien nombre. L'amont Nginx est régénéré APRÈS, une
# fois que Docker a attribué les ports.
scale_apply() {
  local env_name="$1" file="$2" cible="$3" maxi
  maxi="$(scale_max "$env_name" "$file")"
  [ "$cible" -ge 1 ] || die "Nombre d'exemplaires invalide : $cible"
  [ "$cible" -le "$maxi" ] || die \
    "Impossible de monter à $cible exemplaires : le plafond de cet environnement est $maxi." \
    "Il vient du plus petit de CARLYS_SCALE_MAX (ou du nombre de cœurs) et de la" \
    "taille de la plage de ports ($(api_port_capacity "$env_name" "$file"))."

  env_set_value "$file" CARLYS_API_REPLICAS "$cible"
  dc "$env_name" "$file" up -d --no-deps api || die \
    "Compose n'a pas pu porter l'API à $cible exemplaire(s)." \
    "Le .env porte déjà $cible : corriger la cause puis relancer" \
    "  carlysctl scale $env_name <n>"
  api_attendre_exemplaires_sains "$env_name" "$file" "$cible"
  nginx_apply_upstream "$env_name" "$file" || warn \
    "exemplaires en place, mais l'amont Nginx n'a pas suivi — le trafic peut encore aller à l'ancienne liste."
  state_set_many "$env_name" dernier_changement "$(maintenant)" votes_baisse 0
}
