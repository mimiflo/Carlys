# shellcheck shell=bash
# Faire de la place, sans jamais couper la branche du retour arrière.
#
# LE PROBLÈME, CHIFFRÉ. Chaque déploiement tire TROIS images taguées par sha
# (api, api-migrate, admin) et n'en supprime aucune. Rien, nulle part dans le
# dépôt, n'appelle `docker image prune` — vérifié par recherche. Sur le premier
# serveur en service, le constat après quelques semaines : 11 Go d'images pour
# 51 Go de disque, occupé à 85 %.
#
# Ce que remplir le disque produit ensuite n'est pas une lenteur, c'est une
# panne : PostgreSQL cesse d'écrire, les sauvegardes échouent, et l'état de
# l'orchestrateur lui-même ne peut plus être enregistré.
#
# CE QU'ON NE SUPPRIME JAMAIS, et c'est tout l'enjeu :
#
#   - le sha DÉPLOYÉ de chaque environnement. Évident ;
#   - le sha PRÉCÉDENT de chaque environnement. Moins évident, et c'est
#     l'erreur qu'un élagage naïf commet : `docker image prune -a` juge une
#     image « inutilisée » dès qu'aucun conteneur ne la porte. Or le retour
#     arrière de deploy.sh vise exactement ça — une image sans conteneur. Le
#     supprimer, c'est retirer le filet la veille du jour où il sert ;
#   - toute image portée par un conteneur, même arrêté. Docker refuse de
#     toute façon, mais on ne compte pas sur un refus pour tenir une règle.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Seuil d'occupation du disque au-delà duquel la supervision élague d'elle-même.
prune_seuil_pourcent() { env_value CARLYS_DISK_HIGH_PERCENT "$1" 80; }

# Occupation de la partition qui porte les données, en pourcentage entier.
# `$CARLYS_ROOT` et non `/` : sur une machine où /srv est un volume séparé,
# c'est lui qui se remplit, et c'est lui qu'il faut regarder.
disque_pourcent() {
  df -P "$CARLYS_ROOT" 2>/dev/null | awk 'NR == 2 { sub(/%/, "", $5); print $5 + 0 }'
}

# Les deux derniers shas DISTINCTS d'un environnement.
#
# Distincts, parce que DEPLOYED réinscrit le sha précédent après un retour
# arrière : les deux dernières LIGNES peuvent porter le même sha, et se
# contenter d'elles laisserait le vrai précédent sans protection.
prune_shas_proteges() {
  local fichier
  fichier="$(deployed_file "$1")"
  [ -f "$fichier" ] || return 0
  grep -v '^[[:space:]]*#' "$fichier" | awk 'NF { print $1 }' \
    | tac | awk '!vu[$0]++' | head -2
}

# `prune_images [--essai]` — supprime les images Carlys qu'aucune règle ne
# protège. Rend le nombre de suppressions sur la sortie standard.
# shellcheck disable=SC2120  # l'argument --essai est optionnel, et bien passé par cmd_prune
prune_images() {
  local essai=non
  [ "${1-}" = '--essai' ] && essai=oui
  local env_name image tag sha proteges='' portees='' supprimees=0

  for env_name in staging production; do
    [ -f "$(env_file "$env_name")" ] || continue
    while read -r sha; do
      [ -n "$sha" ] && proteges="$proteges $sha"
    done < <(prune_shas_proteges "$env_name")
  done

  # Les images portées par un conteneur, MÊME ARRÊTÉ. `docker ps -a` et non
  # `docker ps` : un conteneur arrêté est précisément ce qu'un redémarrage va
  # relever.
  portees="$(docker ps -a --format '{{.Image}}' 2>/dev/null | tr '\n' ' ')"

  info "shas protégés : ${proteges:-aucun}"

  while read -r image; do
    [ -n "$image" ] || continue
    case " $portees " in *" $image "*) continue ;; esac
    tag="${image##*:}"
    # Les tags mouvants (`staging`, `production`) désignent un sha déjà couvert
    # par la règle ci-dessus : les retirer ne libère rien et ferait perdre un
    # repère lisible dans `docker image ls`.
    case "$tag" in sha-*) sha="${tag#sha-}"; sha="${sha%-prod}" ;; *) continue ;; esac
    case " $proteges " in *" $sha "*) continue ;; esac

    if [ "$essai" = oui ]; then
      info "  [essai] supprimerait $image"
    else
      if docker image rm "$image" >/dev/null 2>&1; then
        info "  supprimé $image"
      else
        # Docker refuse une image encore référencée. Ce n'est pas une erreur :
        # c'est le second filet, et il vient de servir.
        info "  conservé  $image (Docker le refuse — encore référencé)"
        continue
      fi
    fi
    supprimees=$((supprimees + 1))
  done < <(docker image ls --format '{{.Repository}}:{{.Tag}}' \
    --filter "reference=${CARLYS_REGISTRY}/carlys-*" 2>/dev/null || true)

  printf '%d' "$supprimees"
}

# `prune_si_necessaire <.env>` — appelé par la supervision. N'agit QUE si le
# disque dépasse le seuil.
#
# Pourquoi pas à chaque passe : un élagage inutile n'est pas gratuit — il fait
# perdre le cache d'images qui rend un retour arrière instantané. On ne paie ce
# prix que lorsque la place manque vraiment.
prune_si_necessaire() {
  local file="$1" occupe seuil n
  occupe="$(disque_pourcent)"
  seuil="$(prune_seuil_pourcent "$file")"
  [ -n "$occupe" ] || return 0
  if [ "$occupe" -lt "$seuil" ]; then
    return 0
  fi
  warn "disque à ${occupe} % (seuil ${seuil} %) — élagage des images Carlys"
  # shellcheck disable=SC2119  # sans --essai : on élague pour de vrai
  n="$(prune_images)"
  occupe="$(disque_pourcent)"
  if [ "$n" -eq 0 ]; then
    warn "aucune image à élaguer, et le disque est toujours à ${occupe} %."
    warn "  Regarder ailleurs : docker system df ; du -xh --max-depth=1 $CARLYS_ROOT"
    warn "  Les volumes de données et les sauvegardes ne sont PAS élagués ici."
    return 1
  fi
  ok "$n image(s) supprimée(s) — disque à ${occupe} %"
  return 0
}
