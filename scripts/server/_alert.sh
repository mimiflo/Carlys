# shellcheck shell=bash
# Faire SORTIR une alerte de la machine.
#
# CE QUE CE FICHIER CORRIGE, et c'est une affirmation fausse écrite dans le
# dépôt lui-même. `scripts/server/README.md` disait « Le code de retour EST
# l'alerte », et `setup.sh` détaillait le raisonnement : le `-o pipefail` de la
# ligne de cron préserve bien le code de sortie de backup.sh, donc « cron
# alerte ». Le raisonnement sur pipefail est juste. La conclusion ne l'est pas,
# pour trois raisons indépendantes :
#
#   - cron n'envoie un courriel que lorsqu'un travail produit de la SORTIE. La
#     ligne redirige tout vers `logger`, donc cron n'a rien à poster, quel que
#     soit le code de retour ;
#   - aucun MAILTO n'est déclaré ;
#   - aucun MTA n'est installé (APT_BASE : ca-certificates curl gnupg nginx ufw
#     cron).
#
# Autrement dit : une sauvegarde qui échoue toutes les nuits à 3 h ne réveille
# personne, et le dépôt affirmait le contraire.
#
# PAS DE MTA, PAS DE DÉPENDANCE. `curl` est déjà dans les outils requis par ces
# scripts, et il sait parler SMTP (`curl --version` liste `smtp smtps`).
# Installer et configurer postfix pour envoyer trois courriels par an serait
# une dépendance de plus, un fichier de mot de passe de plus, et un service de
# plus à surveiller.
#
# LA PROPRIÉTÉ QUI REND CECI UTILISABLE : ON N'ALERTE QUE SUR LES TRANSITIONS.
# Une panne détectée par une passe qui repasse toutes les deux minutes
# enverrait 720 courriels par jour. Le dépôt tient déjà ce raisonnement
# ailleurs (backup.sh : « une alerte qui crie tous les jours ne se lit plus ») ;
# ici il est appliqué :
#
#   sain  -> en panne : on envoie, tout de suite
#   panne -> panne    : silence, sauf rappel au-delà de CARLYS_ALERT_RAPPEL_HEURES
#   panne -> sain     : on envoie « RÉSOLU », avec la durée de la panne
#   sain  -> sain     : rien
#
# CE QU'AUCUNE ALERTE NE PEUT FAIRE : prévenir que la machine est morte. Une
# alerte part DE la machine ; si elle ne répond plus, rien ne part et le
# silence ressemble à « tout va bien ». Il faut pour cela une surveillance
# extérieure, qui n'est pas dans ce dépôt. C'est dit ici pour que personne ne
# croie le contraire.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# La configuration des alertes vit à part des .env d'environnement, et c'est
# voulu : une panne de disque ou de sauvegarde n'appartient à aucun des deux
# environnements, et le relais SMTP des alertes n'est pas celui de
# l'application (en recette, SMTP_HOST vaut « mailpit » — un attrapeur local ;
# une alerte qui y atterrirait ne sortirait pas de la machine).
alerte_config_file() { printf '%s/alertes.env' "$CARLYS_ROOT"; }

alerte_valeur() {
  local fichier
  fichier="$(alerte_config_file)"
  [ -r "$fichier" ] || { printf '%s' "${2-}"; return 0; }
  env_value "$1" "$fichier" "${2-}"
}

# Y a-t-il un canal ? Sans destinataire ni webhook, tout ce fichier est inerte
# — et `doctor` le dit, parce qu'un système d'alerte éteint en silence est
# exactement le défaut qu'on répare ici.
alerte_canal() {
  if [ -n "$(alerte_valeur CARLYS_ALERT_WEBHOOK '')" ]; then printf 'webhook'; return 0; fi
  if [ -n "$(alerte_valeur CARLYS_ALERT_TO '')" ]; then printf 'courriel'; return 0; fi
  printf 'aucun'
}

alerte_rappel_heures() { alerte_valeur CARLYS_ALERT_RAPPEL_HEURES 24; }

# Un sujet de courriel qui porte des accents doit être encodé, sinon il arrive
# en charabia dans la moitié des clients. RFC 2047, forme base64.
alerte_sujet_encode() {
  printf '=?UTF-8?B?%s?=' "$(printf '%s' "$1" | base64 -w0)"
}

# La même chaîne, mais utilisable dans un EN-TÊTE HTTP.
#
# Mesuré : « Sauvegarde des bases ÉCHOUÉE » posé tel quel dans `Title:` arrive
# en « Sauvegarde des bases ÃCHOUÃE ». Les en-têtes HTTP ne transportent pas
# de l'UTF-8 de façon fiable — la spécification les veut en ASCII. On translittère
# donc pour l'en-tête, et le titre EXACT part de toute façon dans le corps,
# qui, lui, est déclaré en UTF-8.
alerte_titre_ascii() {
  # Un filet, pas une translittération.
  #
  # LE VRAI CHOIX EST EN AMONT : les titres d'alerte sont ÉCRITS EN ASCII aux
  # sites d'appel (« Sauvegarde des bases: ECHEC »), et le français complet, lui,
  # vit dans le CORPS du message, déclaré en UTF-8. Un en-tête HTTP ne
  # transporte pas d'UTF-8 de façon fiable, et toutes les façons de le
  # contourner se sont révélées pires — mesurées sous la locale « C », celle de
  # cron et de systemd :
  #
  #   - `iconv -t ASCII//TRANSLIT` rend « ÉCHOUÉE » en « ?CHOU?E » ;
  #   - `y/…/…/` de sed compte des OCTETS et refuse net les chaînes accentuées ;
  #   - une classe `[àâä]` apparie des octets isolés au milieu de séquences
  #     UTF-8, donc corrompt au lieu de nettoyer.
  #
  # Il ne reste ici qu'un garde-fou : si un titre accentué passait un jour, on
  # ne laisse pas partir du charabia dans l'en-tête.
  printf '%s' "$1" | tr -cd '\11\40-\176'
}

# `alerte_envoyer <sujet> <corps>` — le transport brut, sans déduplication.
# Rend 0 si l'alerte est partie.
alerte_envoyer() {
  local sujet="$1" corps="$2" canal url to from message code
  canal="$(alerte_canal)"

  case "$canal" in
    webhook)
      url="$(alerte_valeur CARLYS_ALERT_WEBHOOK '')"
      # Texte brut, et non JSON : c'est ce qu'attend ntfy.sh, le service qui
      # demande le moins de choses (une URL, aucun identifiant, une
      # notification sur le téléphone). L'en-tête `Title` est sa convention ;
      # un service qui ne la connaît pas l'ignore sans échouer.
      # Le titre EXACT est répété en tête du corps : l'en-tête est
      # translittéré, le corps ne l'est pas.
      code="$(curl -sS -o /dev/null -w '%{http_code}' -m 20 \
        -H "Title: $(alerte_titre_ascii "$sujet")" \
        -H 'Content-Type: text/plain; charset=utf-8' \
        --data-binary "$sujet

$corps" "$url" 2>/dev/null || printf '000')"
      case "$code" in
        2*) return 0 ;;
        *) warn "alerte NON envoyée (webhook, code $code)"; return 1 ;;
      esac
      ;;
    courriel)
      to="$(alerte_valeur CARLYS_ALERT_TO '')"
      from="$(alerte_valeur CARLYS_ALERT_FROM "carlys@$(hostname -f 2>/dev/null || hostname)")"
      url="$(alerte_valeur CARLYS_ALERT_SMTP_URL '')"
      if [ -z "$url" ]; then
        warn "CARLYS_ALERT_TO est posé mais CARLYS_ALERT_SMTP_URL manque — rien n'est envoyé"
        return 1
      fi
      message="$(mktemp)" || return 1
      {
        printf 'From: %s\n' "$from"
        printf 'To: %s\n' "$to"
        printf 'Subject: %s\n' "$(alerte_sujet_encode "$sujet")"
        printf 'Content-Type: text/plain; charset=UTF-8\n'
        printf 'X-Carlys-Alerte: 1\n'
        printf '\n%s\n' "$corps"
      } > "$message"
      local -a args=(-sS -m 30 --url "$url" --mail-from "$from" --mail-rcpt "$to"
        --upload-file "$message")
      local u p
      u="$(alerte_valeur CARLYS_ALERT_SMTP_USER '')"
      p="$(alerte_valeur CARLYS_ALERT_SMTP_PASSWORD '')"
      [ -n "$u" ] && args+=(--user "$u:$p")
      if curl "${args[@]}" >/dev/null 2>&1; then
        rm -f "$message"; return 0
      fi
      rm -f "$message"
      warn "alerte NON envoyée (SMTP $url) — vérifier $(alerte_config_file)"
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# Le corps commun : qui parle, d'où, et quand. Un courriel d'alerte qui ne dit
# pas de quelle machine il vient est inutilisable dès qu'il y en a deux.
alerte_entete() {
  printf 'machine     : %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'environnement : %s\n' "$1"
  printf 'date        : %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# `alerte_signaler <env> <clé> <titre> [détail…]`
#
# À appeler À CHAQUE passage tant que la panne dure : c'est cette fonction qui
# décide de se taire, pas l'appelant. Le contraire — laisser chaque appelant
# gérer sa propre déduplication — donnerait autant de politiques que de sites
# d'appel, et l'une d'elles finirait par crier.
alerte_signaler() {
  local env_name="$1" cle="$2" titre="$3"
  shift 3
  local etat depuis dernier maintenant_s rappel_s corps sujet envoye=0

  etat="$(state_get "$env_name" "alerte_${cle}_etat" sain)"
  dernier="$(state_get "$env_name" "alerte_${cle}_envoi" 0)"
  maintenant_s="$(maintenant)"
  rappel_s=$(( $(alerte_rappel_heures) * 3600 ))

  if [ "$etat" = panne ]; then
    depuis="$(state_get "$env_name" "alerte_${cle}_depuis" "$maintenant_s")"
    # Déjà signalée et le rappel n'est pas dû : on se tait, mais on garde
    # l'état à jour pour que la résolution sache quoi annoncer.
    if [ "$dernier" -gt 0 ] && [ $(( maintenant_s - dernier )) -lt "$rappel_s" ]; then
      return 0
    fi
  else
    depuis="$maintenant_s"
  fi

  if [ "$(alerte_canal)" != aucun ]; then
    sujet="[Carlys] PANNE - $titre"
    [ "$etat" = panne ] && sujet="[Carlys] TOUJOURS EN PANNE - $titre"
    corps="$(
      alerte_entete "$env_name"
      printf 'depuis      : %s\n\n' "$(status_duree $(( maintenant_s - depuis )) 2>/dev/null || printf '%ss' $(( maintenant_s - depuis )))"
      if [ "$#" -gt 0 ]; then printf "%s\n" "$@"; fi
      printf '\nCe que la machine peut en dire :\n'
      printf '  journalctl -u carlys-supervision.service -n 80 --no-pager\n'
      printf '  %s/carlysctl status\n' "$CARLYS_LIB_DIR"
    )"
    if alerte_envoyer "$sujet" "$corps"; then envoye="$maintenant_s"; else envoye="$dernier"; fi
  else
    envoye="$dernier"
  fi

  state_set_many "$env_name" \
    "alerte_${cle}_etat" panne \
    "alerte_${cle}_depuis" "$depuis" \
    "alerte_${cle}_envoi" "$envoye"
}

# `alerte_resoudre <env> <clé> <titre>`
#
# À appeler à chaque passage où tout va bien. N'envoie QUE si une panne avait
# réellement été signalée : annoncer la résolution d'un problème dont personne
# n'a jamais entendu parler est du bruit, pas une information.
alerte_resoudre() {
  local env_name="$1" cle="$2" titre="$3"
  local etat depuis dernier maintenant_s corps

  etat="$(state_get "$env_name" "alerte_${cle}_etat" sain)"
  [ "$etat" = panne ] || return 0

  dernier="$(state_get "$env_name" "alerte_${cle}_envoi" 0)"
  depuis="$(state_get "$env_name" "alerte_${cle}_depuis" 0)"
  maintenant_s="$(maintenant)"

  if [ "$dernier" -gt 0 ] && [ "$(alerte_canal)" != aucun ]; then
    corps="$(
      alerte_entete "$env_name"
      printf 'panne ouverte %s, maintenant résolue.\n' \
        "$(status_duree $(( maintenant_s - depuis )) 2>/dev/null || printf 'pendant %ss' $(( maintenant_s - depuis )))"
    )"
    alerte_envoyer "[Carlys] RESOLU - $titre" "$corps" || true
  fi

  state_set_many "$env_name" \
    "alerte_${cle}_etat" sain \
    "alerte_${cle}_depuis" 0 \
    "alerte_${cle}_envoi" 0
}
