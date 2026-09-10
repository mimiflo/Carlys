#!/usr/bin/env bash
# Prépare un serveur Debian/Ubuntu NU à héberger Carlys (staging + production).
#
#     sudo scripts/server/setup.sh
#
# IDEMPOTENT, et c'est sa propriété la plus importante. Un script de mise en
# place ne se joue jamais une seule fois : on l'exécute la première fois sur une
# machine nue, puis à chaque fois que le dépôt en ajoute une brique — et à ce
# moment-là le serveur héberge une production. Chaque étape vérifie donc l'état
# avant d'agir, et le geste qui détruit une production — écraser un .env rempli
# par la valeur d'exemple — n'est écrit NULLE PART dans ce fichier : un .env
# existant est conservé, toujours, sans option pour forcer.
#
# CE QU'IL FAIT
#   1. paquets système : nginx, ufw, cron, et de quoi parler à un dépôt apt ;
#   2. Docker et son plugin compose, depuis le dépôt officiel Docker ;
#   3. amonts Nginx de départ, sans lesquels nginx refuse de démarrer dès que
#      les vhosts du dépôt sont posés ;
#   4. pare-feu : tout refusé en entrée sauf 22 (SSH), et 80 DEPUIS LE SEUL
#      reverse proxy réseau (CARLYS_PROXY_CIDR) ;
#   5. arborescence /srv/carlys (staging, production, backups) ;
#   6. copie des .env d'exemple s'ils n'existent pas encore ;
#   7. jeton de registre en 600, vide, à remplir ;
#   8. cron quotidien de sauvegarde ;
#   9. minuterie systemd de supervision (réparation + mise à l'échelle) ;
#  10. récapitulatif de ce qui reste MANUEL.
#
# UN SERVICE QUI NE DÉMARRE PAS NE L'ARRÊTE PAS. docker et cron sont activés à
# l'étape 2, nginx à l'étape 3 ; si l'un refuse de démarrer, le script le
# signale, VA QUAND MÊME AU BOUT (arborescence, .env, jeton, cron, supervision,
# récapitulatif), redit lesquels en défaut avec leur commande de diagnostic,
# puis sort en 1. Sans cela, l'échec le plus banal — port 80 déjà pris par un
# Apache livré avec l'image du fournisseur, snippet référencé par un vhost mais
# pas encore installé — laissait la machine sans rien : le script mourait à 2/9.
#
# CE QU'IL NE FAIT PAS, ET N'A PAS À FAIRE
#   - les vhosts nginx : ils vivent dans infrastructure/nginx/, versionnés ;
#     ce script installe nginx et dit où les prendre, il ne les invente pas ;
#   - les certificats TLS : CE SERVEUR N'EN A PLUS. Le TLS est terminé par le
#     reverse proxy réseau (gra6.luuc.fr), qui relaie en HTTP clair vers le
#     port 80 d'ici ; les six noms publics restent en https:// pour le client.
#     Rien à installer, rien à renouveler, rien à surveiller ici — d'où
#     l'absence de certbot dans les paquets et du 443 dans le pare-feu ;
#   - configurer ce reverse proxy réseau : il n'est pas sur cette machine. Le
#     récapitulatif final dit exactement ce qu'on attend de lui, y compris les
#     trois en-têtes dont dépend l'adresse du client ;
#   - remplir les secrets, acheter le domaine, poser les DNS.
#
# ESSAI À BLANC. CARLYS_SETUP_DRY_RUN=1 n'exécute AUCUNE commande système
# (apt, systemctl, ufw, docker) et se contente de les afficher ; les opérations
# de fichiers, elles, s'exécutent pour de vrai, contre CARLYS_ROOT. C'est ce
# qui permet d'éprouver l'idempotence pour de bon, hors serveur :
#     CARLYS_SETUP_DRY_RUN=1 CARLYS_ROOT=/tmp/essai CARLYS_CRON_DIR=/tmp/cron \
#       scripts/server/setup.sh
#
# CARLYS_PROXY_CIDR : adresse (ou réseau) du reverse proxy réseau, la SEULE
# source autorisée à joindre le port 80. Sans valeur, le script n'ouvre pas le
# 80 — il le DIT, et le rappelle dans le récapitulatif. Voir l'étape 4.
#     CARLYS_PROXY_CIDR=172.16.0.1 sudo scripts/server/setup.sh
set -euo pipefail

# shellcheck source=scripts/server/_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/_common.sh"

DRY_RUN="${CARLYS_SETUP_DRY_RUN:-0}"
CRON_DIR="${CARLYS_CRON_DIR:-/etc/cron.d}"
BACKUP_HOUR="${CARLYS_BACKUP_HOUR:-3}"

# Adresse ou réseau du reverse proxy qui termine le TLS et relaie vers le
# port 80 de cette machine. PAS DE DÉFAUT : un défaut inventé (« 172.16.0.0/12
# sans doute ») ouvrirait un port à des machines qu'on n'a pas choisies tout en
# donnant l'impression d'une règle réfléchie. Vide, on n'ouvre rien et on le dit.
# Voir l'étape 4.
PROXY_CIDR="${CARLYS_PROXY_CIDR:-}"

# run : exécute une commande SYSTÈME, ou l'affiche en essai à blanc. Toutes les
# commandes qui touchent la machine (paquets, services, pare-feu) passent par
# elle — c'est ce qui rend le script jouable hors serveur.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '   %s[essai]%s %s\n' "$_c_yellow" "$_c_off" "$*"
    return 0
  fi
  "$@"
}

printf '%s\n' "$_c_bold"
printf 'Préparation du serveur Carlys\n'
printf '%s\n' "$_c_off"
if [ "$DRY_RUN" = "1" ]; then
  warn "ESSAI À BLANC : aucune commande système ne sera exécutée."
fi
info "racine des données : $CARLYS_ROOT"
info "dépôt              : $CARLYS_REPO_DIR"

# ── 0. Préalables ──────────────────────────────────────────────────────────
step "0/9 Préalables"
if [ "$DRY_RUN" != "1" ] && [ "$(id -u)" -ne 0 ]; then
  die "Ce script doit être lancé en root." \
    "  sudo $0" \
    "Pour le relire sans rien exécuter :" \
    "  CARLYS_SETUP_DRY_RUN=1 CARLYS_ROOT=/tmp/essai $0"
fi

OS_ID=''
if [ -r /etc/os-release ]; then
  OS_ID="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
fi
case "$OS_ID" in
  debian | ubuntu) ok "système : $OS_ID" ;;
  *)
    if [ "$DRY_RUN" = "1" ]; then
      warn "système « ${OS_ID:-inconnu} » : les commandes apt seront affichées, pas jouées."
    else
      die "Système non supporté : « ${OS_ID:-inconnu} »." \
        "Ce script cible Debian et Ubuntu (apt, systemd, ufw)." \
        "Sur une autre distribution, installer les mêmes briques à la main :" \
        "docker + plugin compose, nginx, ufw, cron."
    fi
    ;;
esac

# ── 1. Paquets système ─────────────────────────────────────────────────────
step "1/9 Paquets système"
# PAS DE CERTBOT, ni le paquet ni son greffon nginx. Le TLS des six noms
# publics est terminé par le reverse proxy réseau, qui détient les certificats
# et les renouvelle ; cette machine ne sert que du HTTP en interne. Installer
# certbot ici poserait une minuterie de renouvellement pour des certificats
# qui n'existent pas, et laisserait croire au prochain exploitant que le TLS
# se règle sur ce serveur.
APT_BASE=(ca-certificates curl gnupg nginx ufw cron)
missing=()
for pkg in "${APT_BASE[@]}"; do
  if [ "$DRY_RUN" = "1" ]; then missing+=("$pkg"); continue; fi
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$' || missing+=("$pkg")
done
if [ "${#missing[@]}" -eq 0 ]; then
  ok "déjà installés : ${APT_BASE[*]}"
else
  info "à installer : ${missing[*]}"
  run apt-get update -qq
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
  ok "paquets installés"
fi

# ── 2. Docker et son plugin compose ────────────────────────────────────────
# Le dépôt officiel Docker, pas celui de la distribution : le plugin compose v2
# (`docker compose`, sans tiret) n'existe que là, et c'est lui que les scripts
# de déploiement appellent.
step "2/9 Docker"
if docker compose version >/dev/null 2>&1; then
  ok "docker $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ,) avec plugin compose — rien à faire"
else
  info "installation depuis le dépôt officiel Docker"
  run install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    run sh -c "curl -fsSL https://download.docker.com/linux/${OS_ID:-debian}/gpg -o /etc/apt/keyrings/docker.asc"
    run chmod a+r /etc/apt/keyrings/docker.asc
  fi
  CODENAME="$( (. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_CODENAME:-}") || true)"
  run sh -c "printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
      \"\$(dpkg --print-architecture)\" '${OS_ID:-debian}' '${CODENAME:-stable}' > /etc/apt/sources.list.d/docker.list"
  run apt-get update -qq
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ok "docker installé"
fi
# UN SERVICE QUI NE DÉMARRE PAS N'ARRÊTE PAS LA MISE EN PLACE.
#
# Sous `set -e`, un `systemctl enable --now nginx` en échec tuait le script
# ICI, à l'étape 2 sur 9 : ni l'arborescence /srv/carlys, ni les .env, ni le
# jeton, ni la sauvegarde quotidienne, ni le récapitulatif de ce qui reste
# manuel. Or ce script est annoncé idempotent et rejouable, et les deux
# situations qui font échouer nginx sont précisément celles où on le rejoue :
#
#   - premier passage sur une machine dont le port 80 est déjà pris (Apache
#     installé par l'image du fournisseur, un conteneur qui publie 80) ;
#   - rejeu sur un serveur déjà en service dont un vhost référence un fichier
#     absent — le snippet partagé pas encore copié, par exemple : nginx refuse
#     alors de démarrer, et le rejeu, censé installer la brique que le dépôt
#     vient d'ajouter, ne faisait rien du tout.
#
# Le bon comportement n'est pas d'ignorer l'échec, c'est de FINIR LE TRAVAIL
# puis de le dire. Le récapitulatif final nomme les services en défaut avec
# leur commande de diagnostic, et le script sort en 1 pour qu'aucune
# automatisation ne prenne ça pour un succès.
services_ko=''
enable_service() {
  local svc="$1"
  if run systemctl enable --now "$svc"; then
    return 0
  fi
  services_ko="$services_ko $svc"
  warn "$svc n'a pas démarré — la mise en place CONTINUE, le bilan le rappellera."
  return 0
}

enable_service docker
enable_service cron

# ── Amonts Nginx de départ ──────────────────────────────────────────────────
#
# AVANT de démarrer nginx, et c'est l'ordre qui compte. Les vhosts de
# infrastructure/nginx/ ne déclarent PAS l'amont de l'API : elle tourne en
# plusieurs exemplaires sur des ports attribués par Docker, et c'est
# `carlysctl` qui écrit la liste réelle. Tant que ce fichier n'existe pas,
# nginx refuse toute la configuration :
#     [emerg] host not found in upstream "carlys_api_production"
# — donc, sur un serveur dont les vhosts sont déjà posés, il ne démarrerait
# pas, et le rejeu de ce script échouerait à l'étape suivante sans rapport
# avec sa cause.
#
# On pose donc un amont à UN exemplaire, sur le premier port de la plage
# (contrat de conception : 3000 en production, 3100 en recette — les mêmes
# valeurs que les .env.example). C'est exactement l'état de départ : un seul
# exemplaire. `carlysctl` le réécrira au premier déploiement, avec les ports
# que Docker aura réellement attribués.
step "3/9 Amonts Nginx de départ"
poser_amont_initial() {
  local env_name="$1" premier_port="$2" cible
  cible="/etc/nginx/conf.d/carlys-${env_name}-api-upstream.conf"
  if [ -f "$cible" ]; then
    info "$cible existe déjà — laissé tel quel (carlysctl en est propriétaire)"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    printf '   %s[essai]%s écriture de %s\n' "$_c_yellow" "$_c_off" "$cible"
    return 0
  fi
  mkdir -p /etc/nginx/conf.d
  cat > "$cible" <<FIN
# Carlys — amont de l'API de « $env_name ». État de DÉPART posé par setup.sh.
#
# Réécrit par \`carlysctl\` au premier déploiement, avec les ports que Docker
# aura réellement attribués aux exemplaires. Ne pas éditer à la main.
#
# Le raisonnement complet est dans
# infrastructure/nginx/carlys-api-upstream.conf.example.

upstream carlys_api_${env_name} {
    least_conn;

    server 127.0.0.1:${premier_port} max_fails=3 fail_timeout=10s;

    keepalive 32;
}
FIN
  chmod 644 "$cible"
  ok "$cible"
}
poser_amont_initial production 3000
poser_amont_initial staging 3100

enable_service nginx

# ── 3. Pare-feu ────────────────────────────────────────────────────────────
# 22 (SSH), 80 DEPUIS LE SEUL REVERSE PROXY, et RIEN d'autre. Les ports
# applicatifs (3000/3100, 3001/3101, 9000/9200) sont publiés sur 127.0.0.1
# seulement (contrat de conception) : nginx est le seul chemin depuis
# l'extérieur. `ufw allow` et `ufw --force enable` sont idempotents par
# construction.
#
# PLUS DE 443 : aucun vhost Carlys n'écoute en TLS sur cette machine, le
# terminateur est ailleurs. Un port ouvert que plus rien ne sert reste une
# surface d'attaque, donc la règle d'un passage précédent est RETIRÉE.
#
# LE 80 N'EST PAS UN PORT PUBLIC. C'est cette règle-là qui rend honnête le
# `X-Forwarded-Proto https` que le nginx d'ici pose EN DUR : l'API en déduit
# req.secure=true alors que la liaison est en clair. Vrai tant que seul le
# reverse proxy — qui, lui, a bien terminé du TLS — peut frapper ce port ;
# mensonger dès que n'importe qui le peut. Même remarque pour l'adresse du
# client : `X-Forwarded-For` n'a de valeur que si le premier maillon est
# forcément le proxy.
step "4/9 Pare-feu (ufw)"

# `ufw delete` sort en 1 quand la règle n'existe pas — le cas nominal sur une
# machine neuve. Ce n'est pas une erreur : on efface si ça traîne, sinon rien.
ufw_forget() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '   %s[essai]%s ufw delete %s   (si la règle existe)\n' \
      "$_c_yellow" "$_c_off" "$*"
    return 0
  fi
  ufw delete "$@" >/dev/null 2>&1 || true
}

run ufw default deny incoming
run ufw default allow outgoing
run ufw allow 22/tcp
ufw_forget allow 443/tcp

# LE RETRAIT DE LA RÈGLE MONDIALE EST INCONDITIONNEL, et c'est le point le plus
# important de cette étape. C'est la version PRÉCÉDENTE de ce script qui a posé
# `ufw allow 80/tcp` — ouvert à tous —, et ce fichier est fait pour être rejoué
# sur un serveur déjà en service. Le laisser dans la seule branche « une adresse
# de proxy a été fournie » donnait le pire des deux mondes : un rejeu sans la
# variable — le cas par défaut — gardait le port 80 grand ouvert pendant que le
# script imprimait « le 80 reste FERMÉ ». Un pare-feu qui ment sur son état est
# pire qu'un pare-feu absent : on cesse de le vérifier.
ufw_forget allow 80/tcp

firewall_todo=0
if [ -z "$PROXY_CIDR" ]; then
  firewall_todo=1
  warn "CARLYS_PROXY_CIDR n'est pas défini : le port 80 N'EST PAS ouvert."
  info "  Le serveur reste injoignable depuis le reverse proxy — c'est le sens"
  info "  fermé, pas le sens ouvert : ouvrir 80 au monde donnerait un"
  info "  req.secure=true mensonger et un X-Forwarded-For forgeable."
  info "  Rejouer avec l'adresse du proxy, par exemple :"
  info "    CARLYS_PROXY_CIDR=172.16.0.1 sudo $0"
  info "  Le récapitulatif final le redit."
else
  case "$PROXY_CIDR" in
    0.0.0.0/0 | ::/0 | any)
      warn "CARLYS_PROXY_CIDR=$PROXY_CIDR ouvre le port 80 AU MONDE ENTIER."
      warn "  Le X-Forwarded-Proto https posé en dur par nginx devient un"
      warn "  mensonge, et n'importe qui peut se présenter avec l'en-tête"
      warn "  X-Forwarded-For de son choix. À ne garder que le temps d'un test."
      ;;
  esac
  # LA FORME EST VALIDÉE AVANT D'ÊTRE PASSÉE À ufw, qui ne résout AUCUN nom
  # d'hôte : `CARLYS_PROXY_CIDR=gra6.luuc.fr` lui fait rendre « ERROR: Bad
  # source address » et sortir en 1. Sous `set -e`, cela tuerait ce script ici
  # même, à l'étape 4 sur 9 — exactement le mode d'échec que l'en-tête de ce
  # fichier revendique d'avoir supprimé, réintroduit un cran plus loin. Et la
  # saisie fautive est probable : tout le reste de ce dépôt appelle le proxy par
  # son nom. On meurt donc AVANT, avec un message qui dit quoi taper.
  case "$PROXY_CIDR" in
    *[!0-9./:a-fA-F]*)
      die "CARLYS_PROXY_CIDR=« $PROXY_CIDR » n'est pas une adresse." \
        "ufw ne résout aucun nom d'hôte : il lui faut une adresse IPv4 ou IPv6," \
        "avec un préfixe facultatif. Résoudre le nom d'abord :" \
        "  dig +short gra6.luuc.fr" \
        "puis rejouer, par exemple :" \
        "  CARLYS_PROXY_CIDR=172.16.0.1 sudo $0"
      ;;
  esac
  run ufw allow from "$PROXY_CIDR" to any port 80 proto tcp
fi

run ufw --force enable
if [ "$DRY_RUN" != "1" ]; then
  ufw status | sed 's/^/   /' || true
fi
if [ "$firewall_todo" = "1" ]; then
  warn "entrée : 22 seulement — le 80 reste FERMÉ (voir le récapitulatif)"
else
  ok "entrée : 22 (SSH) et 80 depuis $PROXY_CIDR — tout le reste refusé"
fi

# ── 4. Arborescence ────────────────────────────────────────────────────────
# mkdir -p et chmod sont idempotents ; c'est la partie du script qu'on peut
# rejouer les yeux fermés.
step "5/9 Arborescence $CARLYS_ROOT"
mkdir -p "$CARLYS_ROOT/staging" "$CARLYS_ROOT/production" "$(backups_dir)"
chmod 750 "$CARLYS_ROOT"
chmod 750 "$CARLYS_ROOT/staging" "$CARLYS_ROOT/production"
chmod 700 "$(backups_dir)"
ok "staging/ production/ backups/"

# ── 5. Fichiers .env ───────────────────────────────────────────────────────
# LE geste à ne jamais faire : recopier l'exemple par-dessus un .env rempli.
# Il n'y a donc pas d'option --force ici, volontairement.
step "6/9 Fichiers d'environnement"
for env_name in staging production; do
  target="$(env_file "$env_name")"
  example="$CARLYS_ENV_EXAMPLES_DIR/${env_name}.env.example"
  if [ -f "$target" ]; then
    ok "$target existe — CONSERVÉ (jamais écrasé)"
    chmod 600 "$target"
  elif [ -f "$example" ]; then
    cp "$example" "$target"
    chmod 600 "$target"
    ok "$target créé depuis $(basename -- "$example") — À REMPLIR"
  else
    warn "modèle absent : $example"
    warn "  le dépôt est-il à jour sur le serveur ? ($CARLYS_REPO_DIR)"
  fi
done

# LE FICHIER D'ALERTES, même règle : jamais écrasé. Il vit à la racine et non
# dans un environnement, parce qu'un disque plein ou une sauvegarde ratée
# n'appartiennent ni à la recette ni à la production.
alertes="$(printf '%s/alertes.env' "$CARLYS_ROOT")"
alertes_ex="$CARLYS_ENV_EXAMPLES_DIR/alertes.env.example"
if [ -f "$alertes" ]; then
  ok "$alertes existe — CONSERVÉ (jamais écrasé)"
  chmod 600 "$alertes"
elif [ -f "$alertes_ex" ]; then
  cp "$alertes_ex" "$alertes"
  chmod 600 "$alertes"
  ok "$alertes créé — TOUT EST COMMENTÉ, donc AUCUNE alerte ne sortira"
  info "  décommenter UNE ligne de canal, puis : carlysctl alert-test"
else
  warn "modèle absent : $alertes_ex"
fi

# ── 6. Jeton du registre ───────────────────────────────────────────────────
# Créé VIDE avec les bons droits : l'opérateur n'a plus qu'à y coller le PAT,
# sans avoir à penser au chmod. deploy.sh refuse explicitement un jeton vide.
step "7/9 Jeton du registre"
token="$(ghcr_token_file)"
if [ -s "$token" ]; then
  chmod 600 "$token"
  ok "$token présent et non vide"
else
  : > "$token"
  chmod 600 "$token"
  ok "$token créé (vide, mode 600) — À REMPLIR"
fi

# ── 7. Cron de sauvegarde ──────────────────────────────────────────────────
# Écrit seulement si le contenu change : rejouer setup.sh ne doit pas donner
# l'impression d'avoir modifié quelque chose alors que rien n'a bougé.
step "8/9 Sauvegarde quotidienne (cron)"
mkdir -p "$CRON_DIR"
cron_file="$CRON_DIR/carlys-backup"
cron_tmp="$(mktemp)"
trap 'rm -f "$cron_tmp"' EXIT
cat > "$cron_tmp" <<FIN
# Sauvegarde quotidienne des bases Carlys — posé par scripts/server/setup.sh.
# La sortie part vers syslog : une sauvegarde qui échoue doit laisser une trace
# ailleurs que dans un courriel que personne ne lit.
#
# -o pipefail N'EST PAS DÉCORATIF : sans lui, le code de retour d'un tube est
# celui de sa DERNIÈRE commande — ici « logger », qui réussit toujours — et
# quiconque appelle ce script en attendant son code se ferait berner.
#
# EN REVANCHE, CRON N'ALERTE PAS, et ces lignes ont longtemps affirmé le
# contraire. Cron n'envoie un courriel que si le travail produit de la SORTIE ;
# tout part vers « logger », donc il n'a rien à poster, quel que soit le code de
# retour. Il n'y a d'ailleurs ni MAILTO ici, ni MTA installé sur la machine.
# L'alerte est envoyée par backup.sh lui-même — voir _alert.sh — à condition
# qu'un canal soit configuré dans /srv/carlys/alertes.env.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
CARLYS_ROOT=$CARLYS_ROOT
0 $BACKUP_HOUR * * * root /bin/bash -o pipefail -c '$CARLYS_REPO_DIR/scripts/server/backup.sh 2>&1 | logger -t carlys-backup'
FIN
if [ -f "$cron_file" ] && cmp -s "$cron_tmp" "$cron_file"; then
  ok "$cron_file déjà à jour"
else
  cp "$cron_tmp" "$cron_file"
  chmod 644 "$cron_file"
  ok "$cron_file installé (tous les jours à ${BACKUP_HOUR}h00, rétention 14 j)"
fi
rm -f "$cron_tmp"
trap - EXIT

# ── 9. Supervision : la minuterie systemd ──────────────────────────────────
#
# CE QU'ELLE ALLUME, ET CE QU'ELLE N'ALLUME PAS. La minuterie fait passer
# `carlysctl supervise` toutes les deux minutes : il répare ce qui est tombé et
# ajuste le nombre d'exemplaires de l'API à la charge mesurée. Elle ne déploie
# RIEN : la mise à jour automatique reste commandée par CARLYS_AUTO_UPDATE dans
# le .env de chaque environnement, livré à « non ». Autrement dit, ce qui
# s'allume ici garde la pile debout ; ce qui change la version qu'elle sert
# reste un choix explicite.
step "9/9 Supervision (systemd)"
poser_unite_systemd() {
  local nom="$1" src dst tmp
  src="$CARLYS_REPO_DIR/infrastructure/server/systemd/$nom"
  dst="/etc/systemd/system/$nom"
  if [ ! -f "$src" ]; then
    warn "gabarit absent : $src — supervision non installée"
    return 1
  fi
  if [ "$DRY_RUN" = "1" ]; then
    printf '   %s[essai]%s écriture de %s\n' "$_c_yellow" "$_c_off" "$dst"
    return 0
  fi
  # `__DEPOT__` remplacé par le chemin réel : les unités doivent pouvoir
  # désigner carlysctl sans supposer où le dépôt a été cloné.
  tmp="$(mktemp)"
  sed "s#__DEPOT__#$CARLYS_REPO_DIR#g" "$src" > "$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
    rm -f "$tmp"
    info "$dst déjà à jour"
    return 0
  fi
  install -m 644 "$tmp" "$dst"
  rm -f "$tmp"
  ok "$dst"
  return 0
}

if poser_unite_systemd carlys-supervision.service && poser_unite_systemd carlys-supervision.timer; then
  run systemctl daemon-reload
  # Seule la MINUTERIE est activée : le service est un `oneshot` qu'elle
  # déclenche. L'activer lui aussi ajouterait une passe au démarrage, en plus
  # de celle de la minuterie, sans que rien ne le signale.
  enable_service carlys-supervision.timer
  info "prochaine passe : systemctl list-timers carlys-supervision.timer"
  info "journal         : journalctl -u carlys-supervision.service -f"
  info "passe immédiate : systemctl start carlys-supervision.service"
fi

# ── Récapitulatif : ce qui reste MANUEL ────────────────────────────────────
DOMAIN_HINT="$(env_value DOMAIN "$(env_file production)" 'exemple.fr' 2>/dev/null || printf 'exemple.fr')"

# Adresse de CETTE machine sur le réseau interne, celle que le reverse proxy
# devra viser. Détectée plutôt qu'affirmée ; si la détection échoue, on le dit
# et on donne la commande, on n'invente pas une adresse.
SERVER_IP="$(ip -4 route get 1.1.1.1 2>/dev/null \
  | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' \
  || true)"
SERVER_IP="${SERVER_IP:-<adresse interne de ce serveur : ip -4 addr>}"

# Le pare-feu a-t-il ouvert le 80, et depuis où : le récapitulatif doit dire
# l'état RÉEL de la machine, pas l'état souhaité.
if [ "$firewall_todo" = "1" ]; then
  FIREWALL_NOTE="4. PARE-FEU — LE PORT 80 EST FERMÉ, il reste à l'ouvrir pour le seul proxy.
   CARLYS_PROXY_CIDR n'était pas défini : ce script n'ouvre pas 80 au monde en
   silence, il préfère une machine injoignable à une machine qui ment. Rejouer
   avec l'adresse (ou le réseau) du reverse proxy :
     CARLYS_PROXY_CIDR=<adresse du proxy> sudo $0
   ou, sans rejouer le script :
     ufw allow from <adresse du proxy> to any port 80 proto tcp
   POURQUOI cette restriction et pas un simple « allow 80 » : le nginx d'ici
   pose X-Forwarded-Proto https EN DUR, sans quoi les URL publiques
   retomberaient en http://. L'API en déduit req.secure=true alors que la
   liaison est en clair. Cette déduction n'est vraie que si le seul émetteur
   possible est un proxy qui, lui, a terminé du TLS. Même chose pour
   l'adresse du client : X-Forwarded-For ne vaut que si le premier maillon
   est forcément le proxy."
else
  FIREWALL_NOTE="4. PARE-FEU — fait : 22 (SSH) et 80 depuis $PROXY_CIDR uniquement, 443 retiré.
   Rien à faire ici, mais à savoir avant d'y toucher : c'est cette règle qui
   rend honnête le X-Forwarded-Proto https posé EN DUR par le nginx d'ici.
   L'API en déduit req.secure=true alors que toute la liaison interne est en
   clair — vrai tant que seul un proxy ayant terminé du TLS peut frapper ce
   port, mensonger le jour où on ouvrira 80 plus largement. Même chose pour
   X-Forwarded-For, qui ne vaut que si le premier maillon est forcément le
   proxy. Si l'adresse du proxy change : ufw delete puis ufw allow from …"
fi

cat <<FIN

$_c_bold── Ce que ce script n'a PAS fait, et qu'il faut faire à la main ──$_c_off

1. DNS — 6 enregistrements CNAME vers gra6.luuc.fr, le reverse proxy réseau
   qui termine le TLS. Ils ne pointent PAS sur ce serveur : rien de public ne
   frappe directement cette machine.
     api.$DOMAIN_HINT            app.$DOMAIN_HINT            media.$DOMAIN_HINT
     api-staging.$DOMAIN_HINT    app-staging.$DOMAIN_HINT    media-staging.$DOMAIN_HINT
   Rien d'autre ne peut avancer tant qu'ils ne résolvent pas.

2. Vhosts nginx — les prendre dans le dépôt, ils y sont versionnés :
     $CARLYS_REPO_DIR/infrastructure/nginx/
   Ils n'écoutent QU'EN HTTP sur le port 80 : ni 443, ni certificat, ni
   redirection vers https, ni défi ACME — tout cela vit sur gra6.
   puis : nginx -t && systemctl reload nginx

3. REVERSE PROXY RÉSEAU (gra6.luuc.fr) — À CONFIGURER LÀ-BAS, PAS ICI.
   C'est lui qui détient les certificats des six noms, termine le TLS et
   relaie en HTTP clair vers cette machine :
     proxy_pass         http://$SERVER_IP:80;
     proxy_set_header   Host              \$host;          # nom public CONSERVÉ
     proxy_set_header   X-Forwarded-For   \$remote_addr;   # ÉCRASER, jamais ajouter
     proxy_set_header   X-Forwarded-Proto https;
   Ces trois en-têtes sont une EXIGENCE, pas une supposition : les vérifier
   sur gra6 avant de déclarer la mise en route terminée.
   - Host : les vhosts d'ici choisissent le service par server_name, et les
     liens des e-mails portent le nom public. Un Host réécrit, et on tombe
     sur l'attrape-tout.
   - X-Forwarded-For à \$remote_addr et NON \$proxy_add_x_forwarded_for.
     Mesuré sur la chaîne montée pour de vrai (client → gra6 → nginx d'ici →
     Express) : avec \$proxy_add_x_forwarded_for ou \$http_x_forwarded_for,
     un client qui envoie lui-même « X-Forwarded-For: 1.2.3.4 » fait retenir
     1.2.3.4 à l'API. Un compteur de sauts ne retire des entrées QUE PAR LA
     DROITE : tout ce que le client PRÉFIXE survit. Conséquences : limitation
     de débit contournée, audit empoisonné.
     Seul \$remote_addr, qui écrase, protège.
   - X-Forwarded-Proto https en dur, pour que les URL publiques restent en
     https:// alors que la liaison interne est en clair.
   Le nginx d'ici garde \$proxy_add_x_forwarded_for : il AJOUTE l'adresse de
   gra6 derrière ce que gra6 a écrit — c'est le second saut, et c'est pourquoi
   les deux .env portent TRUST_PROXY_HOPS=2. Mesuré : avec 1, l'API voit
   l'adresse de gra6 et tout le monde partage un seul seau de limitation ;
   avec 2, elle voit celle du client.

$FIREWALL_NOTE

5. Secrets — remplir les .env, toutes les valeurs CHANGE_MOI_… :
     $(env_file staging)
     $(env_file production)
   Attendus : mots de passe PostgreSQL et MinIO, JWT_ACCESS_SECRET (32
   caractères minimum), SMTP, Stripe, Firebase. L'API REFUSE de démarrer si une
   variable essentielle manque, et refuse en plus les valeurs de développement
   en production (docs/security/reverse-proxy.md, section 5).

6. Jeton du registre — un PAT GitHub avec la portée read:packages :
     printf '%s' '<le jeton>' > $(ghcr_token_file)
     chmod 600 $(ghcr_token_file)

7. Marqueurs légaux — tant que docs/legal/*.md portent des « [À COMPLÉTER : … ] »,
   l'image admin de PRODUCTION ne se construit pas, et promote.sh refusera de
   promouvoir. C'est voulu. Les lister :
     grep -rn 'À COMPLÉTER' $CARLYS_REPO_DIR/docs/legal/

Ensuite seulement :
     $CARLYS_REPO_DIR/scripts/server/carlysctl deploy staging <sha>
     $CARLYS_REPO_DIR/scripts/server/carlysctl promote      # production, geste humain

── CE QUI TOURNE DÉSORMAIS TOUT SEUL, ET CE QUI NE TOURNE PAS ──

  OUI, sans rien demander (minuterie installée à l'étape 9, toutes les 2 min) :
    · réparation — conteneur disparu, arrêté, ou « unhealthy » deux passages
      de suite ; plafonnée à 5 réparations par heure, au-delà elle s'arrête et
      le DIT plutôt que de masquer une panne qui revient ;
    · mise à l'échelle de l'API sur la charge mesurée (utilisateurs en ligne,
      débit, latence), avec délai de garde et patience à la baisse ;
    · amont Nginx tenu à jour après chaque changement.

  NON, tant que vous ne l'avez pas écrit vous-même :
    · déployer une nouvelle version. CARLYS_AUTO_UPDATE=non dans les deux
      .env. Passé à « oui », la RECETTE suit la branche configurée, et la
      PRODUCTION promeut le sha qui tourne déjà en recette après une heure de
      maturation saine — jamais une branche, jamais sans les vérifications de
      promote.sh.

  Pour regarder :   $CARLYS_REPO_DIR/scripts/server/carlysctl status
  Pour diagnostiquer : $CARLYS_REPO_DIR/scripts/server/carlysctl doctor
  Journal de la supervision : journalctl -u carlys-supervision.service -f
  Pour tout arrêter :  systemctl disable --now carlys-supervision.timer

FIN

# ── Services en défaut ─────────────────────────────────────────────────────
# Placé APRÈS le récapitulatif, et non à la place : l'exploitant a besoin des
# deux. Le travail de mise en place a bien eu lieu — l'arborescence, les .env,
# le jeton, le cron sont en place — mais la machine n'est pas prête tant qu'un
# de ces services ne tourne pas, et le dire en dernier le met sous les yeux.
if [ -n "$services_ko" ]; then
  printf '%s── Services qui ne démarrent PAS ──%s\n' "$_c_red" "$_c_off"
  for svc in $services_ko; do
    printf '   %s✗%s %s\n' "$_c_red" "$_c_off" "$svc"
    printf '     systemctl status %s   ·   journalctl -xeu %s\n' "$svc" "$svc"
  done
  printf '\n   Causes fréquentes : port 80 déjà pris par un autre serveur (nginx),\n'
  printf '   fichier référencé par un vhost mais pas encore installé — le snippet\n'
  printf '   partagé, par exemple (nginx), noyau sans cgroup v2 (docker).\n'
  printf '   Tout le reste de la mise en place a bien été fait : ce script se\n'
  printf '   rejoue sans risque une fois la cause levée.\n\n'
  exit 1
fi
