# shellcheck shell=bash
# Exemplaires de l'API et amont Nginx engendré.
#
# POURQUOI CE FICHIER EST SÉPARÉ DE _common.sh. _common.sh décrit ce qui ne
# bouge pas : où vivent les fichiers, comment on lit un .env, comment on appelle
# Compose. Ici, on décrit un ÉTAT qui change tout seul — combien d'exemplaires
# tournent, sur quels ports, et ce que Nginx doit en savoir. Les deux
# préoccupations n'ont ni le même rythme ni les mêmes lecteurs.
#
# Chargé par _common.sh, il ne définit que des fonctions et ne fait aucun effet
# de bord. Il suppose `set -euo pipefail` chez l'appelant.

# Répertoire des amonts engendrés. Variable pour que ces fonctions puissent
# être jouées hors serveur, contre une arborescence jetable.
CARLYS_NGINX_CONF_DIR="${CARLYS_NGINX_CONF_DIR:-/etc/nginx/conf.d}"
# Comment on demande à Nginx de relire sa configuration. Surchargeable pour la
# même raison.
CARLYS_NGINX_RELOAD="${CARLYS_NGINX_RELOAD:-systemctl reload nginx}"
CARLYS_NGINX_TEST="${CARLYS_NGINX_TEST:-nginx -t}"

# ── Ce que le .env déclare ──────────────────────────────────────────────────
# Mêmes défauts que les .example, pour que ces fonctions répondent juste même
# devant un .env qui ne nomme pas la variable.
api_host_port_last() {
  local env_name="$1" file="$2" fallback=3019
  [ "$env_name" = staging ] && fallback=3119
  env_value CARLYS_API_HOST_PORT_LAST "$file" "$fallback"
}

api_replicas_wanted() {
  local env_name="$1" file="$2"
  env_value CARLYS_API_REPLICAS "$file" 1
}

# Combien d'exemplaires la plage de ports peut accueillir.
#
# Ce n'est pas une curiosité : demander plus que ça fait échouer Docker EN
# COURS DE ROUTE (« all ports are allocated ») et laisse la pile à moitié mise
# à l'échelle — mesuré. On refuse donc avant d'appeler Compose.
api_port_capacity() {
  local env_name="$1" file="$2" premier dernier
  premier="$(api_host_port "$env_name" "$file")"
  dernier="$(api_host_port_last "$env_name" "$file")"
  if [ "$dernier" -lt "$premier" ]; then
    printf '0'
    return 0
  fi
  printf '%d' $((dernier - premier + 1))
}

# ── Ce que Docker fait réellement ───────────────────────────────────────────
#
# Le gabarit d'inspection, en un seul endroit. `with index .State "Health"`
# plutôt que `.State.Health` : sur une image SANS sonde, la clé est absente de
# la structure et `.State.Health` fait échouer le gabarit — mesuré. Les images
# de Carlys en ont une, mais un script d'exploitation ne doit pas tomber parce
# qu'on lui a montré un conteneur inattendu.
#
# Les `$p` sont des variables du gabarit Go, pas du shell : les guillemets
# simples sont voulus.
# shellcheck disable=SC2016
_CARLYS_INSPECT_FMT='{{.Name}}|{{.State.Status}}|{{with index .State "Health"}}{{.Status}}{{else}}sans-sonde{{end}}|{{range $p := index .NetworkSettings.Ports "%s/tcp"}}{{$p.HostPort}}{{end}}'

# `api_replica_states <env> <.env>` — une ligne par exemplaire EN MARCHE :
#     <nom>|<état>|<santé>|<port de l'hôte>
#
# `compose ps -q` ne liste que ce qui tourne (vérifié : un exemplaire arrêté
# en disparaît, et son port n'est plus publié). C'est exactement ce qu'on veut :
# un conteneur arrêté ne publie plus rien, l'inscrire dans l'amont enverrait du
# trafic vers un port que personne n'écoute.
api_replica_states() {
  local env_name="$1" file="$2" port_interne fmt id
  port_interne="$(env_value PORT "$file" 3000)"
  # shellcheck disable=SC2059 # le gabarit contient volontairement un %s
  fmt="$(printf "$_CARLYS_INSPECT_FMT" "$port_interne")"
  while read -r id; do
    [ -n "$id" ] || continue
    docker inspect --format "$fmt" "$id" 2>/dev/null || true
  done < <(dc "$env_name" "$file" ps -q api 2>/dev/null || true)
}

# `api_replica_ports <env> <.env>` — les ports à mettre dans l'amont.
#
# Préférence aux exemplaires SAINS. S'il n'y en a aucun mais que des
# exemplaires tournent, on prend ceux-là : mieux vaut envoyer le trafic à un
# processus qui redémarre qu'à une liste vide ou à d'anciens ports. Si rien ne
# tourne, on ne rend rien — et l'appelant refusera d'écrire (voir
# nginx_apply_upstream).
api_replica_ports() {
  local env_name="$1" file="$2" nom etat sante port sains=() marche=()
  while IFS='|' read -r nom etat sante port; do
    [ -n "${port:-}" ] || continue
    [ "$etat" = running ] || continue
    marche+=("$port")
    case "$sante" in healthy | sans-sonde) sains+=("$port") ;; esac
  done < <(api_replica_states "$env_name" "$file")

  # `nom` n'est lu que pour découper la ligne ; il ne sert pas ici.
  : "${nom:-}"

  if [ "${#sains[@]}" -gt 0 ]; then
    printf '%s\n' "${sains[@]}"
  elif [ "${#marche[@]}" -gt 0 ]; then
    printf '%s\n' "${marche[@]}"
  fi
}

# Attente BORNÉE que les exemplaires attendus soient sains.
#
# POURQUOI ELLE EST INDISPENSABLE, et c'est un essai qui l'a montré : sans
# elle, `up -d` rend la main dès que Docker a DÉMARRÉ les conteneurs, alors que
# leur sonde est encore en « starting ». `api_replica_ports` — qui privilégie
# à raison les exemplaires sains — ne voyait donc que les anciens, l'amont
# Nginx était réécrit à l'identique (« déjà à jour »), et le nouvel exemplaire
# ne recevait de trafic qu'au passage de supervision SUIVANT. Une montée en
# charge décidée à l'instant T ne prenait effet qu'à T + un intervalle de
# minuterie : exactement le retard qu'on cherchait à supprimer.
#
# Bornée, et non bloquante : si un exemplaire ne devient jamais sain, on pose
# quand même l'amont avec ceux qui le sont. Servir avec moins d'exemplaires
# que prévu vaut mieux que ne pas servir du tout, et `heal` verra l'écart.
api_attendre_exemplaires_sains() {
  local env_name="$1" file="$2" cible="$3" tentatives delai i sains
  tentatives="${CARLYS_REPLICA_HEALTH_TRIES:-45}"
  delai="${CARLYS_REPLICA_HEALTH_DELAY:-2}"
  for ((i = 0; i < tentatives; i++)); do
    sains="$(api_replica_ports "$env_name" "$file" | wc -l)"
    if [ "$sains" -ge "$cible" ]; then
      return 0
    fi
    sleep "$delai"
  done
  warn "seulement $(api_replica_ports "$env_name" "$file" | wc -l) exemplaire(s) sain(s) sur $cible après $((tentatives * delai)) s"
  warn "  l'amont Nginx va être posé avec ceux qui répondent ; voir carlysctl status $env_name"
  return 0
}

# ── L'amont Nginx ───────────────────────────────────────────────────────────
nginx_upstream_name() { printf 'carlys_api_%s' "$1"; }
nginx_upstream_file() { printf '%s/carlys-%s-api-upstream.conf' "$CARLYS_NGINX_CONF_DIR" "$1"; }

# Rend le contenu du fichier d'amont sur la sortie standard.
# `nginx_render_upstream <env> <port…>`
nginx_render_upstream() {
  local env_name="$1"; shift
  cat <<FIN
# Carlys — amont de l'API de « $env_name ». ENGENDRÉ PAR carlysctl.
#
# NE PAS ÉDITER À LA MAIN : ce fichier est réécrit à chaque déploiement et à
# chaque mise à l'échelle, à partir des ports que Docker a réellement
# attribués. Toute modification manuelle disparaîtra sans avertissement.
#
# Écrit le : $(date -u '+%Y-%m-%dT%H:%M:%SZ') (UTC)
# Exemplaires : $#
#
# Le raisonnement (pourquoi engendré, pourquoi least_conn, pourquoi keepalive)
# est dans infrastructure/nginx/carlys-api-upstream.conf.example.

upstream $(nginx_upstream_name "$env_name") {
    least_conn;

$(for port in "$@"; do printf '    server 127.0.0.1:%s max_fails=3 fail_timeout=10s;\n' "$port"; done)
    keepalive 32;
}
FIN
}

# `nginx_apply_upstream <env> <.env>` — écrit l'amont, vérifie, recharge.
#
# LA SÉQUENCE COMPTE, et c'est tout l'intérêt de la fonction :
#   1. refuser une liste VIDE — un bloc `upstream` sans `server` est une
#      configuration invalide, et écraser un amont sain par du vide couperait
#      le service au lieu de le réparer ;
#   2. ne rien faire si le contenu est déjà le bon (hors ligne de date) — un
#      rechargement Nginx pour rien à chaque tour de supervision, c'est du
#      bruit dans les journaux et une chance de plus de tomber ;
#   3. sauvegarder, écrire, TESTER ; si le test échoue, restaurer et le dire.
#      Un amont refusé par Nginx ne doit jamais rester en place : le prochain
#      `systemctl reload` d'un tiers échouerait alors sans rapport avec lui.
#
# Rend 0 si rechargé ou déjà à jour, 1 si refusé.
nginx_apply_upstream() {
  local env_name="$1" file="$2"
  local cible sauvegarde nouveau ports=()

  mapfile -t ports < <(api_replica_ports "$env_name" "$file")
  if [ "${#ports[@]}" -eq 0 ]; then
    warn "Aucun exemplaire d'API en marche pour « $env_name » : l'amont Nginx est laissé INTACT."
    warn "  (un amont vide est une configuration invalide ; l'écraser couperait le service)"
    return 1
  fi

  cible="$(nginx_upstream_file "$env_name")"
  sauvegarde="${cible}.precedent"
  nouveau="$(mktemp)"
  nginx_render_upstream "$env_name" "${ports[@]}" > "$nouveau"

  # Comparaison hors ligne « Écrit le : » : sinon deux amonts identiques
  # diffèrent à chaque seconde qui passe, et Nginx se recharge pour rien.
  if [ -f "$cible" ] && diff -q \
      <(grep -v '^# Écrit le' "$cible") \
      <(grep -v '^# Écrit le' "$nouveau") >/dev/null 2>&1; then
    rm -f "$nouveau"
    info "amont Nginx déjà à jour (${#ports[@]} exemplaire(s) : ${ports[*]})"
    return 0
  fi

  [ -f "$cible" ] && cp -p "$cible" "$sauvegarde"
  mv "$nouveau" "$cible"
  chmod 644 "$cible"

  if ! $CARLYS_NGINX_TEST >/dev/null 2>&1; then
    if [ -f "$sauvegarde" ]; then
      mv "$sauvegarde" "$cible"
    else
      rm -f "$cible"
    fi
    warn "Nginx REFUSE la configuration avec ce nouvel amont — l'ancien état est restauré."
    warn "  Diagnostic : $CARLYS_NGINX_TEST"
    return 1
  fi

  rm -f "$sauvegarde"
  if ! $CARLYS_NGINX_RELOAD >/dev/null 2>&1; then
    warn "Amont écrit et validé, mais le rechargement de Nginx a échoué."
    warn "  Nginx sert encore l'ANCIENNE liste d'exemplaires. Diagnostic :"
    warn "    $CARLYS_NGINX_RELOAD"
    return 1
  fi

  ok "amont Nginx rechargé — ${#ports[@]} exemplaire(s) : ${ports[*]}"
  return 0
}
