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
#   1. paquets système : docker + plugin compose, nginx, certbot, ufw, cron ;
#   2. pare-feu : tout refusé en entrée sauf 22 (SSH), 80 et 443 ;
#   3. arborescence /srv/carlys (staging, production, backups) ;
#   4. copie des .env d'exemple s'ils n'existent pas encore ;
#   5. jeton de registre en 600, vide, à remplir ;
#   6. cron quotidien de sauvegarde ;
#   7. récapitulatif de ce qui reste MANUEL.
#
# CE QU'IL NE FAIT PAS, ET N'A PAS À FAIRE
#   - les vhosts nginx : ils vivent dans infrastructure/nginx/, versionnés ;
#     ce script installe nginx et dit où les prendre, il ne les invente pas ;
#   - certbot : obtenir un certificat exige que le DNS pointe DÉJÀ sur la
#     machine. Lancer certbot avant les enregistrements A, c'est se faire
#     limiter par Let's Encrypt pour rien ; les commandes exactes sont
#     rappelées à la fin ;
#   - remplir les secrets, acheter le domaine, poser les DNS.
#
# ESSAI À BLANC. CARLYS_SETUP_DRY_RUN=1 n'exécute AUCUNE commande système
# (apt, systemctl, ufw, docker) et se contente de les afficher ; les opérations
# de fichiers, elles, s'exécutent pour de vrai, contre CARLYS_ROOT. C'est ce
# qui permet d'éprouver l'idempotence pour de bon, hors serveur :
#     CARLYS_SETUP_DRY_RUN=1 CARLYS_ROOT=/tmp/essai CARLYS_CRON_DIR=/tmp/cron \
#       scripts/server/setup.sh
set -euo pipefail

# shellcheck source=scripts/server/_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/_common.sh"

DRY_RUN="${CARLYS_SETUP_DRY_RUN:-0}"
CRON_DIR="${CARLYS_CRON_DIR:-/etc/cron.d}"
BACKUP_HOUR="${CARLYS_BACKUP_HOUR:-3}"

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
step "0/7 Préalables"
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
        "docker + plugin compose, nginx, certbot, ufw, cron."
    fi
    ;;
esac

# ── 1. Paquets système ─────────────────────────────────────────────────────
step "1/7 Paquets système"
# Pas de python3-certbot-nginx : les certificats s'obtiennent en `certonly
# --webroot`, un par hôte, sans que certbot ne touche à la configuration nginx
# (le récapitulatif final et docs/deployment/mise-en-route-serveur.md § 6
# décrivent cette méthode, et les vhosts du dépôt servent déjà le défi ACME).
# Le greffon --nginx réécrirait des vhosts versionnés : rien à faire ici.
APT_BASE=(ca-certificates curl gnupg nginx certbot ufw cron)
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
step "2/7 Docker"
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
run systemctl enable --now docker
run systemctl enable --now cron
run systemctl enable --now nginx

# ── 3. Pare-feu ────────────────────────────────────────────────────────────
# 22, 80, 443 et RIEN d'autre. Les ports applicatifs (3000/3100, 3001/3101,
# 9000/9200) sont publiés sur 127.0.0.1 seulement (contrat de conception) :
# nginx est le seul chemin depuis l'extérieur. `ufw allow` et `ufw --force
# enable` sont idempotents par construction.
step "3/7 Pare-feu (ufw)"
run ufw default deny incoming
run ufw default allow outgoing
run ufw allow 22/tcp
run ufw allow 80/tcp
run ufw allow 443/tcp
run ufw --force enable
if [ "$DRY_RUN" != "1" ]; then
  ufw status | sed 's/^/   /' || true
fi
ok "entrée : 22, 80, 443 — tout le reste refusé"

# ── 4. Arborescence ────────────────────────────────────────────────────────
# mkdir -p et chmod sont idempotents ; c'est la partie du script qu'on peut
# rejouer les yeux fermés.
step "4/7 Arborescence $CARLYS_ROOT"
mkdir -p "$CARLYS_ROOT/staging" "$CARLYS_ROOT/production" "$(backups_dir)"
chmod 750 "$CARLYS_ROOT"
chmod 750 "$CARLYS_ROOT/staging" "$CARLYS_ROOT/production"
chmod 700 "$(backups_dir)"
ok "staging/ production/ backups/"

# ── 5. Fichiers .env ───────────────────────────────────────────────────────
# LE geste à ne jamais faire : recopier l'exemple par-dessus un .env rempli.
# Il n'y a donc pas d'option --force ici, volontairement.
step "5/7 Fichiers d'environnement"
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

# ── 6. Jeton du registre ───────────────────────────────────────────────────
# Créé VIDE avec les bons droits : l'opérateur n'a plus qu'à y coller le PAT,
# sans avoir à penser au chmod. deploy.sh refuse explicitement un jeton vide.
step "6/7 Jeton du registre"
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
step "7/7 Sauvegarde quotidienne (cron)"
mkdir -p "$CRON_DIR"
cron_file="$CRON_DIR/carlys-backup"
cron_tmp="$(mktemp)"
trap 'rm -f "$cron_tmp"' EXIT
cat > "$cron_tmp" <<FIN
# Sauvegarde quotidienne des bases Carlys — posé par scripts/server/setup.sh.
# La sortie part vers syslog : une sauvegarde qui échoue doit laisser une trace
# ailleurs que dans un courriel que personne ne lit.
#
# -o pipefail N'EST PAS DÉCORATIF. Sans lui, le code de retour d'un tube est
# celui de sa DERNIÈRE commande — ici « logger », qui réussit toujours. La
# sortie en erreur de backup.sh serait donc avalée, cron ne verrait qu'un
# succès, et le courriel d'alerte ne partirait jamais : la sauvegarde
# échouerait toutes les nuits en silence. Avec pipefail, le tube rend le code
# de backup.sh, et cron alerte.
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

# ── Récapitulatif : ce qui reste MANUEL ────────────────────────────────────
DOMAIN_HINT="$(env_value DOMAIN "$(env_file production)" 'exemple.fr' 2>/dev/null || printf 'exemple.fr')"
cat <<FIN

$_c_bold── Ce que ce script n'a PAS fait, et qu'il faut faire à la main ──$_c_off

1. DNS — 6 enregistrements A vers l'adresse publique de ce serveur :
     api.$DOMAIN_HINT            app.$DOMAIN_HINT            media.$DOMAIN_HINT
     api-staging.$DOMAIN_HINT    app-staging.$DOMAIN_HINT    media-staging.$DOMAIN_HINT
   Rien d'autre ne peut avancer tant qu'ils ne résolvent pas.

2. Vhosts nginx — les prendre dans le dépôt, ils y sont versionnés :
     $CARLYS_REPO_DIR/infrastructure/nginx/
   puis : nginx -t && systemctl reload nginx

3. Certificats TLS — UN CERTIFICAT PAR HÔTE, en mode webroot, et SEULEMENT une
   fois le DNS en place (sinon Let's Encrypt limite les tentatives ratées).
   Les vhosts du dépôt attendent /etc/letsencrypt/live/<hôte>/ pour CHACUN des
   six noms, et servent le défi ACME depuis /var/www/certbot :
     mkdir -p /var/www/certbot
     for h in api app media api-staging app-staging media-staging; do
       certbot certonly --webroot -w /var/www/certbot \\
         -d "\$h.$DOMAIN_HINT" --agree-tos -m <votre adresse> --non-interactive
     done
     ls -d /etc/letsencrypt/live/*.$DOMAIN_HINT     # six répertoires attendus
   L'ordre a un piège : nginx REFUSE de démarrer si les certificats n'existent
   pas encore, et certbot en webroot a besoin d'un nginx qui tourne. On casse
   la boucle avec un vhost ACME temporaire en HTTP seul — la marche à suivre
   complète est dans docs/deployment/mise-en-route-serveur.md, section 6.
   Le renouvellement automatique est posé par le paquet certbot lui-même.

4. Secrets — remplir les .env, toutes les valeurs CHANGE_MOI_… :
     $(env_file staging)
     $(env_file production)
   Attendus : mots de passe PostgreSQL et MinIO, JWT_ACCESS_SECRET (32
   caractères minimum), SMTP, Stripe, Firebase. L'API REFUSE de démarrer si une
   variable essentielle manque, et refuse en plus les valeurs de développement
   en production (docs/security/reverse-proxy.md, section 2).

5. Jeton du registre — un PAT GitHub avec la portée read:packages :
     printf '%s' '<le jeton>' > $(ghcr_token_file)
     chmod 600 $(ghcr_token_file)

6. Marqueurs légaux — tant que docs/legal/*.md portent des « [À COMPLÉTER : … ] »,
   l'image admin de PRODUCTION ne se construit pas, et promote.sh refusera de
   promouvoir. C'est voulu. Les lister :
     grep -rn 'À COMPLÉTER' $CARLYS_REPO_DIR/docs/legal/

Ensuite seulement :
     $CARLYS_REPO_DIR/scripts/server/deploy.sh staging <sha>
     $CARLYS_REPO_DIR/scripts/server/promote.sh          # production, geste humain

FIN
