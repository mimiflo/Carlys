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

# `scale_decide <env> <.env> <exemplaires actuels> <utilisateurs> <rps> <latence_ms> [<en_vol>]`
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
  local env_name="$1" file="$2" actuel="$3" utilisateurs="$4" rps="$5" latence="$6" en_vol="${7:-0}"
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

  # Descendre RETIRE un exemplaire, et coupe net ce qu'il sert encore : une
  # réponse du coach dure une à deux minutes sur processeur (2 octobre 2026,
  # une réponse tuée en plein calcul par une descente de 2 à 1). On attend
  # donc qu'aucun travail ne soit en cours, sans perdre les votes déjà
  # acquis. Ce n'est qu'un premier filtre, mesuré à l'instant du passage :
  # ce qui part entre-temps, `scale_drainer` le laisse finir.
  if [ "$en_vol" -gt 0 ]; then
    printf '%d attendre requetes-en-cours %d\n' "$actuel" "$(state_get "$env_name" votes_baisse 0)"
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
  local env_name="$1" file="$2" cible="$3" maxi mini
  maxi="$(scale_max "$env_name" "$file")"
  mini="$(scale_min "$file")"
  [ "$cible" -ge 1 ] || die "Nombre d'exemplaires invalide : $cible"
  [ "$cible" -ge "$mini" ] || die \
    "Impossible de descendre à $cible exemplaire(s) : le plancher de cet environnement est $mini." \
    "Il vient de CARLYS_SCALE_MIN, dans infrastructure/server/config/."
  [ "$cible" -le "$maxi" ] || die \
    "Impossible de monter à $cible exemplaires : le plafond de cet environnement est $maxi." \
    "Il vient du plus petit de CARLYS_SCALE_MAX (ou du nombre de cœurs) et de la" \
    "taille de la plage de ports ($(api_port_capacity "$env_name" "$file"))."

  # Réduire : les exemplaires retirés finissent d'abord ce qu'ils servent.
  # Leur travail ne finit pas à temps : la réduction est remise, rien n'est
  # coupé — le .env garde l'ancien nombre, le prochain passage réessaiera.
  # Rend 1 : `carlysctl scale` dit ainsi que rien n'a changé ; la
  # supervision, elle, l'ignore (`|| true`).
  if ! scale_drainer "$env_name" "$file" "$cible"; then
    return 1
  fi

  etat_set "$file" CARLYS_API_REPLICAS "$cible"
  # `--no-recreate` : quand le nombre vit encore dans le .env (avant
  # `config-migrer`), le .env est aussi l'`env_file` de l'API : y changer le
  # nombre change la configuration de CHAQUE exemplaire, et Compose les
  # recréerait tous — y compris ceux qui restent, réponses en cours comprises.
  # Seuls les exemplaires en trop partent, seuls les nouveaux naissent.
  dc "$env_name" "$file" up -d --no-deps --no-recreate api || die \
    "Compose n'a pas pu porter l'API à $cible exemplaire(s)." \
    "Le .env porte déjà $cible : corriger la cause puis relancer" \
    "  carlysctl scale $env_name <n>"
  api_attendre_exemplaires_sains "$env_name" "$file" "$cible"
  nginx_apply_upstream "$env_name" "$file" || warn \
    "exemplaires en place, mais l'amont Nginx n'a pas suivi — le trafic peut encore aller à l'ancienne liste."
  state_set_many "$env_name" dernier_changement "$(maintenant)" votes_baisse 0
}

# `scale_drainer <env> <.env> <cible>` — avant une réduction, retire de
# l'amont Nginx les exemplaires en trop, attend qu'ils aient fini leur
# travail, puis les arrête. Rend 1 (amont rétabli) si ce travail ne finit pas
# dans CARLYS_SCALE_DRAIN_SECONDS (300 s par défaut : deux réponses du coach
# sur processeur), s'il ne se lit pas, ou si un partant refuse de s'arrêter.
# Rend 0 sans rien faire s'il n'y a rien à retirer.
#
# QUI PART : les malades d'abord, puis les plus hauts numéros (ceux que
# Compose retirerait lui-même). On les arrête NOUS-MÊMES, après les avoir
# drainés : laisser Compose choisir, c'était risquer qu'il en arrête un autre
# que celui qu'on venait de vider. Il ne lui reste ensuite que le bon nombre,
# et `up -d` n'a plus rien à retirer.
#
# L'ORDRE COMPTE : l'amont d'abord (plus aucune requête neuve n'arrive aux
# partants ; Nginx laisse finir celles qu'il leur a déjà confiées), la mesure
# ensuite. Mesurer d'abord laissait passer la requête arrivée entre les deux.
#
# LE TRAVAIL, c'est `metrics_travail` : requêtes HTTP, plus tours du coach et
# analyses de photo ouverts jusqu'à leur dernière écriture, qui survivent à
# leur requête (page quittée, scan relu par l'appareil).
scale_drainer() {
  local env_name="$1" file="$2" cible="$3" jeton delai limite debut
  local nom etat sante port travail reste i
  local -a lignes partants=() ports_partants=() malades=() restants=() sains=()

  # Malades d'abord (0), sains ensuite (1) ; à santé égale, le plus haut numéro.
  mapfile -t lignes < <(api_replica_states "$env_name" "$file" \
    | awk -F'|' '$2 == "running" && $4 != "" {
        n = $1; sub(/.*-/, "", n)
        sain = ($3 == "healthy" || $3 == "sans-sonde") ? 1 : 0
        print sain "|" n "|" $0
      }' \
    | sort -t'|' -k1,1n -k2,2nr | cut -d'|' -f3-)
  [ "${#lignes[@]}" -gt "$cible" ] || return 0

  # Compose compte TOUS les conteneurs du service, arrêtés ou en redémarrage
  # compris : s'il y en a d'autres que ceux en marche, `up -d` en retirerait
  # un de son choix après nous. Vérifié AVANT de toucher à quoi que ce soit ;
  # `heal` s'occupe d'abord de l'intrus, la réduction attendra.
  if [ "$(dc "$env_name" "$file" ps -a -q api 2>/dev/null | wc -l)" -ne "${#lignes[@]}" ]; then
    warn "un conteneur d'API arrêté ou en redémarrage : réduction remise, rien n'est touché"
    return 1
  fi

  for i in "${!lignes[@]}"; do
    IFS='|' read -r nom etat sante port <<< "${lignes[i]}"
    if [ "$i" -lt $((${#lignes[@]} - cible)) ]; then
      partants+=("${nom#/}"); ports_partants+=("$port")
      case "$sante" in healthy | sans-sonde) malades+=(non) ;; *) malades+=(oui) ;; esac
    else
      restants+=("$port")
      case "$sante" in healthy | sans-sonde) sains+=("$port") ;; esac
    fi
  done
  : "${etat:-}"
  # Comme api_replica_ports : les sains seuls, s'il y en a.
  [ "${#sains[@]}" -gt 0 ] && restants=("${sains[@]}")

  info "drainage de ${partants[*]} avant de les retirer"
  nginx_apply_upstream "$env_name" "$file" "${restants[@]}" || {
    warn "amont Nginx non réécrit : réduction remise, rien n'est arrêté"
    return 1
  }

  jeton="$(env_value METRICS_TOKEN "$file" '')"
  delai="${CARLYS_SCALE_DRAIN_DELAY:-2}"
  # L'environnement du processus d'abord (les essais), puis la configuration :
  # documentée dans les .env, la variable n'y était pourtant jamais relue.
  limite="${CARLYS_SCALE_DRAIN_SECONDS:-$(env_value CARLYS_SCALE_DRAIN_SECONDS "$file" 300)}"
  debut="$(maintenant)"
  while :; do
    # LA PAUSE D'ABORD : `reload` rend la main avant que les anciens
    # processus de Nginx aient cessé de distribuer. Une mesure immédiate
    # pouvait lire 0 juste avant la dernière requête confiée au partant.
    sleep "$delai"
    reste=0
    for i in "${!ports_partants[@]}"; do
      port="${ports_partants[i]}"
      travail="$(metrics_travail "$port" "$jeton")"
      # Malade ET muet : il était déjà hors de l'amont (api_replica_ports ne
      # garde que les sains), et c'est justement lui qu'on veut retirer.
      # L'attendre bloquerait toute réduction tant qu'il existe.
      [ "$travail" = '?' ] && [ "${malades[i]}" = oui ] && continue
      # Illisible chez un SAIN (jeton absent ou faux) : rien ne prouve qu'il
      # a fini, et attendre n'y changera rien.
      if [ "$travail" = '?' ]; then
        warn "travail de l'exemplaire du port $port illisible (/metrics) : réduction remise"
        nginx_apply_upstream "$env_name" "$file" || true
        return 1
      fi
      [ "$travail" = 0 ] || reste=1
    done
    [ "$reste" -eq 0 ] && break
    if [ "$(($(maintenant) - debut))" -ge "$limite" ]; then
      warn "travail encore en cours sur ${partants[*]} après $limite s : réduction remise"
      nginx_apply_upstream "$env_name" "$file" || true
      return 1
    fi
  done

  # `stop` laisse à l'API son arrêt propre (elle vide ses envois en vol) ;
  # `rm` libère le numéro et le port, comme Compose l'aurait fait. Un partant
  # qui refuse de s'arrêter : on ne laisse pas Compose en choisir un autre,
  # peut-être en plein travail. Amont rétabli, réduction remise.
  if ! { docker stop "${partants[@]}" >/dev/null && docker rm "${partants[@]}" >/dev/null; }; then
    warn "arrêt de ${partants[*]} incomplet : réduction remise — voir carlysctl status $env_name"
    nginx_apply_upstream "$env_name" "$file" || true
    return 1
  fi
  ok "drainés puis retirés : ${partants[*]}"
}

# `deploy_attendre_ia <env> <.env>` — avant une BASCULE, laisse finir les
# tours du coach et les analyses de photo en cours.
#
# Ils vivent DANS le processus de l'API : `up -d` le recrée, et la réponse
# meurt en route — le téléphone lisait « Le coach a besoin d'une connexion »
# (vécu le 5 octobre 2026 : la recette suit `development`, chaque poussée la
# redéploie). L'exemplaire reste dans l'amont pendant l'attente : seul, il
# sert encore tout le monde. Bornée par CARLYS_DEPLOY_DRAIN_SECONDS (120 s :
# une réponse du coach sur processeur), puis la bascule a lieu quand même —
# un déploiement ne reste pas suspendu à un trafic qui ne s'arrête pas. Pas
# plus : une passe de supervision peut déployer la recette PUIS la
# production, et systemd l'arrête à 20 min (carlys-supervision.service),
# drainage, migrations et santé compris — tué en pleine bascule, ce serait
# pire qu'une réponse coupée. Un /metrics illisible ne bloque rien non plus :
# rend toujours 0.
deploy_attendre_ia() {
  local env_name="$1" file="$2" jeton delai limite debut port ouvert reste annonce=non
  local -a ports=()
  mapfile -t ports < <(api_replica_ports "$env_name" "$file")
  [ "${#ports[@]}" -gt 0 ] || return 0
  jeton="$(env_value METRICS_TOKEN "$file" '')"
  delai="${CARLYS_SCALE_DRAIN_DELAY:-2}"
  limite="${CARLYS_DEPLOY_DRAIN_SECONDS:-$(env_value CARLYS_DEPLOY_DRAIN_SECONDS "$file" 120)}"
  # Une valeur qui n'est pas un nombre ferait échouer le test du délai, donc
  # attendre sans fin : on retombe sur le défaut.
  case "$limite" in '' | *[!0-9]*) limite=120 ;; esac
  debut="$(maintenant)"
  while :; do
    reste=0
    for port in "${ports[@]}"; do
      ouvert="$(metrics_ia_ouverte "$port" "$jeton")"
      if [ "$ouvert" = '?' ]; then
        warn "travail du coach illisible sur le port $port (/metrics) : bascule sans attendre"
        return 0
      fi
      [ "$ouvert" = 0 ] || reste=1
    done
    [ "$reste" -eq 0 ] && return 0
    if [ "$(($(maintenant) - debut))" -ge "$limite" ]; then
      warn "réponses du coach encore en cours après $limite s : bascule quand même"
      return 0
    fi
    if [ "$annonce" = non ]; then
      info "réponses du coach en cours : la bascule attend qu'elles finissent (au plus $limite s)"
      annonce=oui
    fi
    sleep "$delai"
  done
}
