# shellcheck shell=bash
# Mise à jour autonome — et ce qui l'autorise.
#
# LES DEUX ENVIRONNEMENTS NE SE METTENT PAS À JOUR DE LA MÊME FAÇON, et c'est
# le cœur de ce fichier.
#
#   RECETTE : elle suit la tête d'une branche. Son rôle est d'être en avance,
#   d'essuyer les plâtres, de montrer ce que donne le dernier code. Rien à
#   valider : si les images du commit existent, elles partent.
#
#   PRODUCTION : elle ne suit AUCUNE branche. Elle suit la RECETTE — le sha qui
#   y tourne déjà, et depuis assez longtemps pour qu'un problème ait eu le
#   temps de se voir. C'est la règle du dépôt (« on construit une fois, on
#   déploie deux fois ») et c'est aussi la seule qui ait un sens : une
#   production qui suivrait une branche déploierait du code que personne n'a vu
#   tourner.
#
# L'ACCORD HUMAIN EST UN INTERRUPTEUR, PAS UNE ABSENCE DE GARDE-FOU.
# `CARLYS_AUTO_UPDATE=oui` dans le .env de l'environnement : posé une fois, à
# la main, par quelqu'un qui sait ce qu'il fait. Absent ou à `non`, rien ne
# part tout seul — et c'est la valeur livrée pour la production. Ce qui reste
# vrai dans les deux cas : les vérifications de deploy.sh et de promote.sh
# (images présentes, migration, santé, retour arrière) ne sont JAMAIS
# court-circuitées. L'interrupteur décide qui appuie sur le bouton, pas si le
# filet est tendu.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# ── MÉMOIRE DES SHAS QUI ONT ÉCHOUÉ ─────────────────────────────────────────
#
# LE DÉFAUT QUE CECI CORRIGE, et c'est le plus grave qu'un audit ait trouvé
# dans cet orchestrateur. Sans mémoire, un sha dont le déploiement échoue est
# RETENTÉ À CHAQUE PASSE, c'est-à-dire toutes les deux minutes, indéfiniment :
# la cible recalculée reste la tête de la branche, et `deployed_current` est
# resté au sha précédent (deploy.sh remet le journal à l'ancien après un
# retour arrière réussi), donc la comparaison « déjà à jour » ne coupe rien.
#
# Deux conséquences, la seconde pire que la première :
#
#   - une MIGRATION cassée est rejouée sur la base toutes les deux minutes.
#     deploy.sh meurt alors sans rien basculer et sans écrire DEPLOYED, donc
#     le cycle complet tient dans une seule passe et recommence aussitôt ;
#   - à chaque tour, la bascule recrée les conteneurs AVANT que la santé ne
#     soit vérifiée, et l'amont Nginx n'est réécrit qu'après : le service rend
#     502 pendant toute l'attente de santé puis tout le retour arrière —
#     plusieurs minutes par tour, en boucle.
#
# Un sha qui a échoué ici ne sera donc plus retenté. Ce n'est pas un délai de
# garde : c'est définitif pour CE sha. Le jour où un nouveau commit arrive, la
# cible change et la mise à jour repart d'elle-même. C'est le bon compromis :
# réessayer ne répare rien (le code est le même), et attendre le correctif est
# exactement ce qu'un humain ferait.
#
# La liste est bornée à vingt entrées — assez pour couvrir toute rafale
# plausible, assez peu pour qu'un fichier d'état reste lisible à la main.
CARLYS_UPDATE_ECHECS_GARDES=20

update_a_echoue() {
  case " $(state_get "$1" maj_echecs '') " in
    *" $2 "*) return 0 ;;
  esac
  return 1
}

update_marquer_echec() {
  local env_name="$1" sha="$2" liste
  liste="$(state_get "$env_name" maj_echecs '')"
  # Dédoublonne en gardant l'ordre d'arrivée, puis ne conserve que les
  # dernières : `tail` sur une liste où les nouvelles sont à la fin.
  liste="$(printf '%s %s' "$liste" "$sha" | tr ' ' '\n' \
    | awk 'NF && !vu[$0]++' | tail -n "$CARLYS_UPDATE_ECHECS_GARDES" | tr '\n' ' ')"
  state_set "$env_name" maj_echecs "${liste% }"
}

update_actif() {
  local valeur
  valeur="$(env_value CARLYS_AUTO_UPDATE "$1" non | tr '[:upper:]' '[:lower:]')"
  case "$valeur" in oui | yes | true | 1) printf 'oui' ;; *) printf 'non' ;; esac
}

# La branche suivie par la RECETTE. Défaut `development` : c'est la branche
# permanente de travail depuis la refonte du modèle Git. Un défaut qui ne
# correspond pas à la réalité du dépôt est exactement ce qui a produit le
# recul du 10 septembre 2026 — celui-ci est aligné, et `doctor` signale de
# toute façon toute divergence avec la branche du clone.
update_branche() { env_value CARLYS_UPDATE_BRANCH "$1" development; }

# Combien de temps un sha doit avoir tourné en recette avant d'aller en
# production. Une heure par défaut : assez pour qu'une fuite de mémoire, une
# migration lente ou une régression visible se manifestent, assez peu pour que
# la production ne traîne pas une journée derrière.
update_maturation_minutes() { env_value CARLYS_PROMOTE_SOAK_MINUTES "$1" 60; }

# Depuis quand le sha courant d'un environnement est déployé, en secondes.
# Rend -1 si le journal ne permet pas de le dire — auquel cas l'appelant doit
# refuser d'agir plutôt que de supposer.
deployed_since() {
  local env_name="$1" fichier ligne date_iso epoque
  fichier="$(deployed_file "$env_name")"
  [ -f "$fichier" ] || { printf '%d' -1; return 0; }
  ligne="$(grep -v '^[[:space:]]*#' "$fichier" | grep -v '^[[:space:]]*$' | tail -1)"
  [ -n "$ligne" ] || { printf '%d' -1; return 0; }
  date_iso="$(printf '%s' "$ligne" | awk '{print $2}')"
  epoque="$(date -u -d "$date_iso" +%s 2>/dev/null || printf '')"
  [ -n "$epoque" ] || { printf '%d' -1; return 0; }
  printf '%d' "$(($(maintenant) - epoque))"
}

# `image_publiee <image>` — le tag existe-t-il dans le registre ?
# `manifest inspect` interroge sans télécharger : on veut savoir, pas
# rapatrier plusieurs centaines de mégaoctets pour le découvrir.
image_publiee() { docker manifest inspect "$1" >/dev/null 2>&1; }

# `update_cible_staging <.env>` — le sha vers lequel la recette devrait aller,
# ou rien.
#
# `git ls-remote` suffit ICI : on ne veut qu'une tête, pas des objets.
#
# La version précédente de ce commentaire justifiait ce choix par « un fetch en
# pleine supervision changerait le code sous les pieds du script en train de
# tourner ». C'est FAUX, et il faut le dire parce que `update_est_un_recul`
# fait désormais un `fetch` : `git fetch` n'écrit que dans .git/ et ne touche
# PAS un seul fichier de l'arborescence. Seuls `pull` et `checkout` la
# réécrivent — et même eux sont sans danger, mesuré : ils remplacent l'inode,
# le bash qui tourne garde son descripteur sur l'ancien.
update_cible_staging() {
  local file="$1" branche tete sha12
  branche="$(update_branche "$file")"
  tete="$(git -C "$CARLYS_REPO_DIR" ls-remote origin "refs/heads/$branche" 2>/dev/null | awk '{print $1}')"
  [ -n "$tete" ] || return 0
  sha12="$(normalize_sha "$tete")"
  # Les images doivent EXISTER. Un commit dont la construction a échoué — ou
  # qui vient d'être poussé et dont la CI tourne encore — ne doit rien
  # déclencher : la recette reste sur ce qu'elle a, et réessaiera au passage
  # suivant. C'est aussi ce qui empêche de déployer un commit rejeté par la CI.
  image_publiee "$(image_api "$sha12")" || return 0
  image_publiee "$(image_admin "$sha12" staging)" || return 0
  image_publiee "$(image_migrate "$sha12")" || return 0
  printf '%s' "$sha12"
}

# `update_est_un_recul <env> <cible> <courant>` — vrai si la cible est un
# ANCÊTRE STRICT de ce qui tourne.
#
# EN CAS DE DOUTE, ON REFUSE. Si le dépôt local ne connaît pas l'un des deux
# commits, `merge-base` ne peut pas trancher — et un `git ls-remote` ne
# rapatrie aucun objet, donc le cas est réel. On tente d'abord un `fetch` de la
# seule référence utile ; s'il n'aboutit pas, l'ancêtre reste indécidable et la
# fonction rend « recul » : mieux vaut une mise à jour qui attend et le dit
# qu'un déploiement à l'aveugle. Le message renvoie de toute façon vers la
# commande manuelle.
update_est_un_recul() {
  local env_name="$1" cible="$2" courant="$3"
  # Rien de déployé, ou la même chose : il n'y a pas de recul possible.
  [ -n "$courant" ] || return 1
  [ "$cible" != "$(normalize_sha "$courant")" ] || return 1

  git -C "$CARLYS_REPO_DIR" fetch --quiet origin 2>/dev/null || true

  if ! git -C "$CARLYS_REPO_DIR" cat-file -e "${cible}^{commit}" 2>/dev/null \
    || ! git -C "$CARLYS_REPO_DIR" cat-file -e "${courant}^{commit}" 2>/dev/null; then
    warn "impossible de situer sha-$cible par rapport à sha-$courant (objet absent)"
    return 0
  fi

  git -C "$CARLYS_REPO_DIR" merge-base --is-ancestor "$cible" "$courant" 2>/dev/null
}

# `update_cible_production <.env de production>` — le sha que la production
# devrait prendre, ou rien, avec la raison sur la sortie d'erreur.
update_cible_production() {
  local file="$1" sha_recette age maturation
  sha_recette="$(deployed_current staging)"
  if [ -z "$sha_recette" ]; then
    info "aucun sha déployé en recette : rien à promouvoir"
    return 0
  fi
  sha_recette="$(normalize_sha "$sha_recette")"

  age="$(deployed_since staging)"
  if [ "$age" -lt 0 ]; then
    warn "impossible de dater le déploiement de recette — promotion automatique refusée"
    return 0
  fi
  maturation="$(($(update_maturation_minutes "$file") * 60))"
  if [ "$age" -lt "$maturation" ]; then
    info "sha-$sha_recette n'a que $((age / 60)) min de recette (maturation exigée : $((maturation / 60)) min)"
    return 0
  fi

  # La recette doit être SAINE MAINTENANT, pas seulement avoir démarré. Un sha
  # qui a passé sa maturation en répondant 503 n'a rien prouvé.
  local ports=() port staging_env
  staging_env="$(env_file staging)"
  mapfile -t ports < <(api_replica_ports staging "$staging_env")
  if [ "${#ports[@]}" -eq 0 ]; then
    warn "aucun exemplaire d'API en recette — promotion automatique refusée"
    return 0
  fi
  for port in "${ports[@]}"; do
    if [ "$(curl -s --noproxy '*' -o /dev/null -m 5 -w '%{http_code}' \
        "http://127.0.0.1:${port}/health/ready" 2>/dev/null || true)" != 200 ]; then
      warn "la recette n'est pas saine (port $port) — promotion automatique refusée"
      return 0
    fi
  done

  printf '%s' "$sha_recette"
}

# `update_run <env> <.env>` — un passage de mise à jour.
#
# Rend 0 si rien à faire ou si le déploiement a réussi, 1 sinon.
update_run() {
  local env_name="$1" file="$2" cible courant

  if [ "$(update_actif "$file")" != oui ]; then
    info "mise à jour automatique DÉSACTIVÉE pour « $env_name » (CARLYS_AUTO_UPDATE)"
    return 0
  fi

  require_commands docker git curl
  ghcr_login >/dev/null 2>&1 || { warn "registre injoignable — mise à jour reportée"; return 1; }

  courant="$(deployed_current "$env_name")"
  if [ "$env_name" = production ]; then
    cible="$(update_cible_production "$file")"
  else
    cible="$(update_cible_staging "$file")"
  fi

  if [ -z "$cible" ]; then
    info "rien à déployer sur « $env_name »"
    return 0
  fi
  if [ "$cible" = "$(normalize_sha "${courant:-0000000000000}")" ] && [ -n "$courant" ]; then
    ok "« $env_name » est déjà sur sha-$cible"
    return 0
  fi

  # Un sha qui a déjà échoué ici ne sera pas retenté — voir le raisonnement en
  # tête de fichier. Le message est court exprès : il se répétera à chaque
  # passe tant qu'aucun nouveau commit n'arrive, et une ligne longue répétée
  # toutes les deux minutes rend un journal illisible.
  if update_a_echoue "$env_name" "$cible"; then
    info "sha-$cible a déjà échoué sur « $env_name » — pas de nouvelle tentative"
    info "  la mise à jour repartira au prochain commit ; pour forcer :"
    info "    carlysctl deploy $env_name $cible"
    return 0
  fi

  # JAMAIS EN ARRIÈRE. Ce garde-fou n'est pas théorique : il a manqué, et le
  # 10 septembre 2026 à 12:02:16Z une recette est repartie de 14 commits en
  # arrière, toute seule, en deux minutes.
  #
  # LA CAUSE. CARLYS_UPDATE_BRANCH vaut `main` par défaut, et le serveur
  # travaillait sur une branche de fonctionnalité que `main` n'avait pas
  # encore reçue. La CI publie les images des DEUX branches
  # (images-publish.yml) : la tête de `main` avait donc bien ses trois images,
  # tous les contrôles existants passaient, et rien n'a fait obstacle. Ce qui
  # tournait a été remplacé par plus ancien, sans un mot.
  #
  # POURQUOI L'ANCÊTRE EST LE BON CRITÈRE. Un `git revert` fabrique un commit
  # NEUF, descendant de ce qui tourne : il n'est jamais un ancêtre, et un
  # retour arrière voulu passe donc sans entrave. Seul le recul LITTÉRAL — la
  # branche suivie pointe sur un commit déjà contenu dans le déployé — est
  # refusé. C'est exactement le cas ci-dessus, et rien d'autre.
  if update_est_un_recul "$env_name" "$cible" "$courant"; then
    warn "RECUL REFUSÉ sur « $env_name » : sha-$cible est un ANCÊTRE de sha-$courant."
    warn "  La branche suivie ($(update_branche "$file")) pointe sur du code PLUS ANCIEN"
    warn "  que ce qui tourne. Le plus souvent, c'est la mauvaise branche :"
    warn "    grep -n '^CARLYS_UPDATE_BRANCH=' $file"
    warn "  Pour reculer volontairement, c'est une commande, pas un automatisme :"
    warn "    carlysctl deploy $env_name $cible"
    return 0
  fi

  # PREMIÈRE MISE EN PRODUCTION : jamais toute seule.
  #
  # deploy.sh n'a de retour arrière que s'il existe un sha précédent. Une
  # production qui n'a jamais rien hébergé n'en a pas : un échec de santé y
  # laisserait la pile debout sur un sha malade, sans filet, et sans personne
  # au clavier. Le premier passage en production est aussi celui où les
  # secrets, le domaine et les textes légaux sont éprouvés pour de bon — c'est
  # exactement le geste qui mérite un humain.
  if [ "$env_name" = production ] && [ -z "$courant" ]; then
    warn "La production n'a JAMAIS été déployée : la mise à jour automatique s'abstient."
    warn "  Un premier déploiement n'a pas de retour arrière possible, et c'est"
    warn "  celui où les secrets et les textes légaux s'éprouvent pour de bon."
    warn "  À faire une fois, à la main :  carlysctl promote"
    return 0
  fi

  step "Mise à jour automatique de « $env_name » vers sha-$cible"
  local sortie=0
  if [ "$env_name" = production ]; then
    # On passe par promote.sh, jamais par deploy.sh directement : c'est lui qui
    # porte les vérifications de la production — l'image admin -prod et sa
    # garde légale, et le message qui explique quoi faire quand elle manque.
    # Les recopier ici les ferait diverger.
    CARLYS_PROMOTE_ASSUME_YES="$cible" "$CARLYS_LIB_DIR/promote.sh" "$cible" || sortie=$?
  else
    "$CARLYS_LIB_DIR/deploy.sh" "$env_name" "$cible" || sortie=$?
  fi

  if [ "$sortie" -ne 0 ]; then
    update_marquer_echec "$env_name" "$cible"
    warn "sha-$cible a ÉCHOUÉ sur « $env_name » (code $sortie) — il est mis de côté."
    warn "  Il ne sera plus retenté automatiquement : réessayer ne répare rien,"
    warn "  le code est le même. La mise à jour repartira au prochain commit."
    warn "  Les journaux du déploiement, juste au-dessus, nomment la cause."
    return 1
  fi
  return 0
}
