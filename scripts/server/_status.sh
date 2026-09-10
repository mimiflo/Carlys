# shellcheck shell=bash
# Les `_c_*` (couleurs) viennent de _common.sh, qui source ce fichier — et
# l'analyseur, qui lit celui-ci isolément, ne peut pas le savoir.
# shellcheck disable=SC2154
# L'état des lieux d'un environnement, en une page.
#
# CE QUE CETTE PAGE DOIT PERMETTRE, c'est de répondre à « est-ce que ça va ? »
# sans taper autre chose. D'où le choix de ce qui y figure : pas tout ce qu'on
# peut mesurer, mais ce qui, absent, oblige à ouvrir un deuxième terminal —
# ce qui tourne, depuis quand, combien d'exemplaires, ce que Nginx en sait,
# combien de gens sont là, et ce que le superviseur s'apprête à faire.
#
# L'ÉCART ENTRE NGINX ET LA RÉALITÉ y a une ligne à lui. C'est la panne la plus
# sournoise de cette architecture : les conteneurs vont bien, la supervision
# est verte, et Nginx envoie le trafic à des ports que plus personne n'écoute.
# Rien d'autre ne la montre.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Les ports que Nginx CROIT servir, lus dans l'amont engendré.
status_ports_nginx() {
  local fichier
  fichier="$(nginx_upstream_file "$1")"
  [ -f "$fichier" ] || return 0
  awk '/^[[:space:]]*server[[:space:]]+127\.0\.0\.1:/ {
         sub(/^.*127\.0\.0\.1:/, ""); sub(/[^0-9].*$/, ""); print
       }' "$fichier"
}

status_ligne() { printf '   %-22s %s\n' "$1" "$2"; }

# `status_env <env>` — tout ce qu'on sait de cet environnement.
status_env() {
  local env_name="$1" file sha age
  file="$(env_file "$env_name")"

  printf '\n%s╔═ %s %s\n' "$_c_bold" "$env_name" "$_c_off"

  if [ ! -f "$file" ]; then
    warn "aucun fichier .env : cet environnement n'est pas installé ($file)"
    return 0
  fi

  # ── Version déployée ──────────────────────────────────────────────────────
  sha="$(deployed_current "$env_name")"
  age="$(deployed_since "$env_name")"
  if [ -n "$sha" ]; then
    if [ "$age" -ge 0 ]; then
      status_ligne 'version' "sha-$sha (depuis $(status_duree "$age"))"
    else
      status_ligne 'version' "sha-$sha (date de déploiement illisible)"
    fi
  else
    status_ligne 'version' 'aucune — jamais déployé'
  fi

  # ── Conteneurs ────────────────────────────────────────────────────────────
  local nom service etat sante politique lignes=0
  printf '   %s\n' 'conteneurs'
  while IFS='|' read -r nom service etat sante politique; do
    [ -n "${service:-}" ] || continue
    lignes=$((lignes + 1))
    local marque='  '
    case "$etat/$sante" in
      running/healthy | running/sans-sonde) marque="${_c_green}✓${_c_off} " ;;
      running/starting)                     marque='· ' ;;
      *)
        # Une TÂCHE terminée n'est pas une panne : minio-init crée le bucket
        # puis sort. Le compose le dit par `restart: 'no'`.
        if [ "$politique" = 'no' ] && [ "$etat" = exited ]; then marque='· '
        else marque="${_c_red}✗${_c_off} "; fi
        ;;
    esac
    printf '     %s%-28s %s / %s\n' "$marque" "${nom#/}" "$etat" "$sante"
  done < <(heal_inventaire "$env_name" "$file")
  [ "$lignes" -eq 0 ] && printf '     %saucun conteneur — la pile est éteinte%s\n' "$_c_yellow" "$_c_off"

  status_exemplaires "$env_name" "$file"
  status_metriques "$env_name" "$file"
  status_automatismes "$env_name" "$file"
}

# Exemplaires d'API, et ce que Nginx en sait.
status_exemplaires() {
  local env_name="$1" file="$2"
  local voulus reels=() nginx=() manquants

  voulus="$(api_replicas_wanted "$env_name" "$file")"
  mapfile -t reels < <(api_replica_ports "$env_name" "$file")
  mapfile -t nginx < <(status_ports_nginx "$env_name")

  status_ligne 'exemplaires API' \
    "${#reels[@]} en vie / $voulus voulus (plafond $(scale_max "$env_name" "$file"), plage de $(api_port_capacity "$env_name" "$file"))"
  status_ligne 'ports réels' "${reels[*]:-aucun}"
  status_ligne 'ports servis par nginx' "${nginx[*]:-aucun (amont absent)}"

  # L'écart, calculé et NOMMÉ. Comparaison sur les ensembles triés : l'ordre
  # des `server` dans l'amont n'a aucune importance, seule la composition en a.
  # `sed '/^$/d'` : un tableau vide donne une ligne vide à `printf`, qui
  # passerait pour un port absent des deux côtés.
  manquants="$(comm -3 \
    <(printf '%s\n' "${reels[@]}" | sed '/^$/d' | sort -u) \
    <(printf '%s\n' "${nginx[@]}" | sed '/^$/d' | sort -u) \
    | tr -d '\t' | tr '\n' ' ' | tr -s ' ')"
  if [ -n "${manquants// /}" ]; then
    printf '   %s⚠ ÉCART nginx ↔ réalité sur : %s%s\n' "$_c_yellow" "$manquants" "$_c_off"
    printf '     %s\n' "à corriger : carlysctl heal $env_name"
  fi
}

# Mesures lues sur les exemplaires.
status_metriques() {
  local env_name="$1" file="$2" resume precedent debit utilisateurs lus refuses code
  resume="$(metrics_summary "$env_name" "$file")"
  lus="$(metrics_field "$resume" lus)"; lus="${lus:-0}"
  refuses="$(metrics_field "$resume" refuses)"; refuses="${refuses:-0}"
  code="$(metrics_field "$resume" code)"
  utilisateurs="$(metrics_field "$resume" utilisateurs)"; utilisateurs="${utilisateurs:--1}"

  if [ "$lus" -eq 0 ]; then
    # DISTINGUER LE REFUS DU SILENCE. Un /metrics qui répond 404 et un
    # exemplaire qui ne répond pas du tout demandent des gestes opposés, et
    # les confondre envoie chercher la panne du mauvais côté — la première
    # rédaction accusait Redis d'un refus qui venait de l'API.
    if [ "$refuses" -gt 0 ]; then
      status_ligne 'mesures' "/metrics REFUSE — code $code sur $refuses exemplaire(s)"
      case "$code" in
        404)
          status_ligne '' 'METRICS_TOKEN absent du .env. Le garde répond 404 dès que'
          status_ligne '' 'NODE_ENV=production — ce qui est le cas de la RECETTE aussi.'
          status_ligne '' "  openssl rand -hex 32   puis METRICS_TOKEN=… dans $file"
          status_ligne '' '  puis : carlysctl deploy '"$env_name"' <sha>'
          ;;
        401)
          status_ligne '' "Le METRICS_TOKEN de $file ne correspond pas à celui que"
          status_ligne '' "l'API a reçu au démarrage. Redéployer après l'avoir corrigé."
          ;;
        000)
          status_ligne '' "Aucune réponse : l'exemplaire écoute-t-il vraiment ?"
          ;;
      esac
    else
      status_ligne 'mesures' 'aucun exemplaire ne rend /metrics'
    fi
    status_ligne '' "Sans elles, la mise à l'échelle reste figée (la santé, elle, est vue)."
    return 0
  fi

  if [ "$utilisateurs" -lt 0 ]; then
    status_ligne 'utilisateurs en ligne' "inconnu (Redis illisible depuis l'API)"
  else
    status_ligne 'utilisateurs en ligne' "$utilisateurs"
  fi

  precedent="$(state_get "$env_name" mesures '')"
  debit="$(metrics_rate "$precedent" "$resume")"
  if [ -n "$debit" ]; then
    # Découpage volontaire : metrics_rate rend TROIS champs séparés par des
    # espaces (débit, latence, intervalle).
    # shellcheck disable=SC2086
    status_ligne 'débit / latence' \
      "$(printf '%s req/s, %s ms en moyenne (sur %s s)' $debit)"
  else
    status_ligne 'débit / latence' 'pas encore mesurable (il faut deux passages)'
  fi
}

# Ce que le superviseur ferait, et ce qu'il a le droit de faire.
status_automatismes() {
  local env_name="$1" file="$2" actif reparations
  actif="$(update_actif "$file")"
  if [ "$actif" = oui ] && [ "$env_name" = production ]; then
    status_ligne 'mise à jour auto' "OUI — promeut la recette après $(update_maturation_minutes "$file") min de maturation"
  elif [ "$actif" = oui ]; then
    status_ligne 'mise à jour auto' "OUI — suit la branche $(update_branche "$file")"
  else
    status_ligne 'mise à jour auto' 'non (CARLYS_AUTO_UPDATE)'
  fi

  reparations="$(heal_compte_recent "$env_name")"
  status_ligne 'réparations (1 h)' "$reparations / $(heal_max_par_heure "$file")"
}

# Durée lisible : « 3 h 12 min » plutôt que 11 520 secondes.
status_duree() {
  awk -v s="$1" 'BEGIN {
    if (s < 60) { printf "%d s", s; exit }
    if (s < 3600) { printf "%d min", s / 60; exit }
    if (s < 86400) { printf "%d h %d min", int(s / 3600), int((s % 3600) / 60); exit }
    printf "%d j %d h", int(s / 86400), int((s % 86400) / 3600)
  }'
}

# La machine elle-même : ce qui tombe en premier sur un serveur dédié.
status_machine() {
  printf '\n%s╔═ machine %s\n' "$_c_bold" "$_c_off"
  status_ligne 'charge' "$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null || printf 'inconnue') (pour $(nproc 2>/dev/null || printf '?') cœur(s))"
  status_ligne 'mémoire' "$(free -h 2>/dev/null | awk '/^Mem:/ {printf "%s utilisés sur %s, %s disponibles", $3, $2, $7}' || printf 'inconnue')"
  # Le disque tue les serveurs plus souvent que le processeur : journaux non
  # bornés, images Docker accumulées, sauvegardes jamais purgées.
  status_ligne 'disque /' "$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s utilisés sur %s (%s)", $3, $2, $5}')"
  if command -v docker >/dev/null 2>&1; then
    status_ligne 'images docker' "$(docker system df --format '{{.Type}} {{.Size}}' 2>/dev/null | awk '/^Images/ {print $2}' || printf 'inconnu')"
  fi
}
