# shellcheck shell=bash
# Ajouter au .env ce qui lui manque — et REFUSER d'inventer le reste.
#
# LE BESOIN. `setup.sh` ne réécrit jamais un .env existant : c'est sa propriété
# la plus importante, sinon il écraserait les secrets à chaque exécution. La
# conséquence est qu'un réglage introduit APRÈS la création du fichier n'y
# arrive jamais tout seul. Sur le premier serveur en service, trois variables
# sont nées de cette façon (CARLYS_API_HOST_PORT_LAST, CARLYS_API_REPLICAS,
# METRICS_TOKEN) et chacune a demandé une intervention à la main, dont deux
# après une panne.
#
# CE QUI REND CE FICHIER DANGEREUX SI ON L'ÉCRIT NAÏVEMENT. « Recopier les
# lignes manquantes de l'exemple » est faux, et de deux façons qui coûtent cher :
#
#   - les valeurs de l'exemple sont FACTICES par construction (le dépôt est
#     public). Recopier POSTGRES_PASSWORD=CHANGE_MOI_… installerait un mot de
#     passe connu de tous. Recopier DOMAIN=CHANGE_MOI_exemple.fr casserait le
#     site en silence ;
#   - ENGENDRER une valeur à la place n'est sûr que si RIEN d'extérieur n'en
#     dépend. Un JWT_ACCESS_SECRET absent veut dire que l'API n'a jamais
#     démarré, donc qu'aucune session n'existe : l'engendrer ne casse rien. Un
#     POSTGRES_PASSWORD engendré sur un serveur qui a déjà des données ferme la
#     base à double tour, définitivement.
#
# D'OÙ VIENT LE CLASSEMENT. Pas d'une liste tenue ici — elle périmerait au
# premier ajout, comme celle que `doctor` portait. Il vient du fichier
# d'exemple lui-même, qui porte déjà la convention `CHANGE_MOI_` documentée en
# tête, et une directive lisible par la machine posée juste au-dessus des
# secrets qu'on sait engendrer sans risque :
#
#     #carlysctl:engendrer hex32
#     METRICS_TOKEN=CHANGE_MOI_JETON_METRIQUES
#
# Le défaut, en l'absence de directive, est de REFUSER. Ajouter une variable
# sans y penser la range donc du côté prudent ; c'est le seul sens dans lequel
# l'oubli est acceptable.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# La complétion pendant la supervision. DÉFAUT « oui », contrairement à
# CARLYS_AUTO_UPDATE : les deux ne demandent pas la même confiance. La mise à
# jour installe du CODE NOUVEAU ; la complétion ne fait qu'écrire la valeur que
# le script utilisait DÉJÀ comme défaut, dans le seul cas où son absence
# empêche la pile de démarrer. Elle n'écrase rien, n'engendre rien, et ne
# devine rien. La refuser laisse le serveur tomber en panne sur un oubli.
envsync_actif() {
  local valeur
  valeur="$(env_value CARLYS_ENV_SYNC "$1" oui | tr '[:upper:]' '[:lower:]')"
  case "$valeur" in non | no | false | 0) printf 'non' ;; *) printf 'oui' ;; esac
}

# Les recettes autorisées, par NOM. Pas de commande arbitraire tirée d'un
# fichier et passée à un shell : la directive nomme une recette, ce fichier
# décide de ce qu'elle vaut. On ne gagnerait rien à être plus général, et on
# perdrait de pouvoir lire ici, en entier, tout ce que ce module peut exécuter.
envsync_engendrer() {
  case "$1" in
    hex32) openssl rand -hex 32 ;;
    *) return 1 ;;
  esac
}

# La directive `#carlysctl:<mot>` du bloc de commentaires qui précède une clé.
#
# Une ligne VIDE coupe le bloc : une directive posée au-dessus d'un autre
# paragraphe ne déborde pas sur la clé suivante. Une ligne de commentaire
# ordinaire, elle, ne coupe pas — la directive peut donc rester collée à
# l'explication qu'elle accompagne.
envsync_directive() {
  local cle="$1" exemple="$2"
  [ -f "$exemple" ] || return 0
  awk -v cle="$cle" '
    /^[[:space:]]*#carlysctl:/ {
      d = $0
      sub(/^[[:space:]]*#carlysctl:[[:space:]]*/, "", d)
      next
    }
    /^[[:space:]]*$/ { d = ""; next }
    /^[[:space:]]*#/ { next }
    {
      if ($0 ~ "^[[:space:]]*(export[[:space:]]+)?" cle "=") { print d; exit }
      d = ""
    }
  ' "$exemple"
}

# La ligne EXACTE de l exemple pour une clé, valeur comprise.
#
# `grep` et non `env_value` : on veut le texte brut. Une valeur comme
# `https://app-staging.${DOMAIN}` doit être recopiée TELLE QUELLE — c'est
# docker compose qui la résoudra, à la lecture, contre le vrai DOMAIN du
# serveur. La développer ici la figerait sur la valeur factice de l'exemple.
envsync_ligne_exemple() {
  grep -m1 -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$2" 2>/dev/null || true
}

# `envsync_classer <cle> <exemple>` — rend « recopier », « engendrer:<recette> »
# ou « humain », sur la sortie standard.
envsync_classer() {
  local cle="$1" exemple="$2" ligne directive
  ligne="$(envsync_ligne_exemple "$cle" "$exemple")"
  case "$ligne" in
    *CHANGE_MOI_*) ;;
    *) printf 'recopier'; return 0 ;;
  esac
  directive="$(envsync_directive "$cle" "$exemple")"
  case "$directive" in
    engendrer\ *)
      # La recette doit exister ICI, sinon on retombe du côté prudent.
      if envsync_engendrer "${directive#engendrer }" >/dev/null 2>&1; then
        printf 'engendrer:%s' "${directive#engendrer }"
        return 0
      fi
      ;;
  esac
  printf 'humain'
}

# `envsync_conseil <cle> <env>` — que faire de cette clé, en une phrase.
#
# NE RÉVÈLE JAMAIS UNE VALEUR FACTICE. C'est le contraire d'une précaution
# esthétique : les placeholders des exemples sont assez longs pour PASSER la
# validation Zod (49 caractères pour le JWT, minimum exigé 32). Un exploitant à
# qui l'on affiche « l'exemple propose : JWT_ACCESS_SECRET=CHANGE_MOI_… » et
# qui recopie la ligne obtient une API qui démarre sans un mot, en signant tous
# ses jetons avec une chaîne publiée dans un dépôt public. Le CHANGE_MOI_ n'est
# un garde-fou que dans le fichier d'exemple, où un grep documenté le traque ;
# recopié depuis la sortie d'un diagnostic, il n'a plus aucun filet.
envsync_conseil() {
  local cle="$1" env_name="$2" exemple classe
  exemple="$(envcheck_exemple "$env_name")"
  classe="$(envsync_classer "$cle" "$exemple")"
  case "$classe" in
    recopier)
      printf 'carlysctl env-sync %s --appliquer   (valeur : %s)' \
        "$env_name" "$(envsync_ligne_exemple "$cle" "$exemple")"
      ;;
    engendrer:hex32)
      printf 'secret À ENGENDRER : carlysctl env-sync %s --appliquer --tout   (ou openssl rand -hex 32)' \
        "$env_name"
      ;;
    engendrer:*)
      printf 'secret À ENGENDRER : carlysctl env-sync %s --appliquer --tout' "$env_name"
      ;;
    *)
      printf 'À ÉCRIRE À LA MAIN, aucune valeur ne peut être devinée — voir %s' "$exemple"
      ;;
  esac
}

# `envsync_plan <env> <.env>` — une ligne par clé manquante :
#   <classement><TAB><clé><TAB><ligne à écrire, ou la ligne d exemple>
#
# N'ÉCRIT RIEN. C'est ce que lisent l'affichage et l'application, pour que les
# deux ne puissent pas diverger.
envsync_plan() {
  local env_name="$1" file="$2" exemple cle classe valeur
  exemple="$(envcheck_exemple "$env_name")"
  [ -f "$exemple" ] || return 0
  while read -r cle; do
    [ -n "$cle" ] || continue
    classe="$(envsync_classer "$cle" "$exemple")"
    case "$classe" in
      recopier) valeur="$(envsync_ligne_exemple "$cle" "$exemple")" ;;
      engendrer:*)
        valeur="$cle=$(envsync_engendrer "${classe#engendrer:}")" || continue ;;
      *) valeur="$(envsync_ligne_exemple "$cle" "$exemple")" ;;
    esac
    printf '%s\t%s\t%s\n' "$classe" "$cle" "$valeur"
  done < <(envcheck_nouveautes "$env_name" "$file")
}

# `envsync_appliquer <env> <.env> <essai|ecrire> <sur|tout>`
#
#   essai   : n'écrit rien, dit ce qui serait fait
#   ecrire  : écrit
#   sur     : uniquement les valeurs recopiables de l'exemple
#   tout    : + les secrets qu'on sait engendrer sans casser d'état extérieur
#
# Rend 0 si le fichier est en ordre (rien à faire, ou tout ajouté), 1 s'il
# reste une valeur que seul un humain peut écrire.
envsync_appliquer() {
  local env_name="$1" file="$2" mode="$3" portee="$4"
  local valide_avant=non sauvegarde classe cle ligne reste=0
  local -a a_ecrire=()

  # L'avis de Compose AVANT d'écrire. On ne restaure une sauvegarde que si l'on
  # a réellement dégradé un fichier qui allait bien : appliquer sur un .env
  # déjà refusé peut légitimement le laisser refusé, sans que ce soit notre
  # faute ni un motif d'annuler ce qu'on vient d'ajouter.
  if dc "$env_name" "$file" config -q >/dev/null 2>&1; then valide_avant=oui; fi

  while IFS="$(printf '\t')" read -r classe cle ligne; do
    [ -n "$cle" ] || continue
    case "$classe" in
      recopier)
        a_ecrire+=("$ligne")
        info "  + $ligne"
        ;;
      engendrer:*)
        if [ "$portee" != tout ]; then
          warn "  $cle manque — secret, non engendré sans --tout"
          reste=1
          continue
        fi
        a_ecrire+=("$ligne")
        # LA VALEUR N'EST JAMAIS AFFICHÉE. Un secret imprimé sur un terminal
        # part dans l'historique du shell, dans le journal systemd et dans la
        # capture d'écran qu'on colle pour demander de l'aide.
        info "  + $cle=… (engendré, ${classe#engendrer:}, non affiché)"
        ;;
      *)
        # La ligne d'exemple n'est PAS affichée : elle porte une valeur factice
        # que Zod accepterait. Voir envsync_conseil.
        warn "  $cle manque et NE PEUT PAS être devinée"
        warn "        $(envsync_conseil "$cle" "$env_name")"
        reste=1
        ;;
    esac
  done < <(envsync_plan "$env_name" "$file")

  if [ "${#a_ecrire[@]}" -eq 0 ]; then
    [ "$reste" -eq 0 ] && ok "  rien à ajouter"
    return "$reste"
  fi

  if [ "$mode" != ecrire ]; then
    info "  (essai — rien n'a été écrit ; --appliquer pour le faire)"
    return "$reste"
  fi

  # `cp -p` conserve le mode 600 et le propriétaire : une sauvegarde de .env
  # lisible par tous serait une fuite à elle seule.
  sauvegarde="$file.avant-sync-$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$file" "$sauvegarde" || { warn "  sauvegarde impossible — rien n'est écrit"; return 1; }

  # EN FIN DE FICHIER, et c'est un choix : une valeur comme
  # `https://app-staging.${DOMAIN}` est résolue par compose contre une variable
  # déclarée PLUS HAUT dans le même fichier. Ajouter à la fin garantit que tout
  # ce dont la nouvelle ligne dépend est déjà défini.
  {
    printf '\n# ── ajouté par carlysctl env-sync le %s ──\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "${a_ecrire[@]}"
  } >> "$file" || { warn "  écriture impossible"; return 1; }

  if [ "$valide_avant" = oui ] && ! dc "$env_name" "$file" config -q >/dev/null 2>&1; then
    warn "  Compose REFUSE le fichier APRÈS ajout — retour à l'état précédent"
    warn "  la version rejetée est conservée : $file.refuse-par-compose"
    cp -p "$file" "$file.refuse-par-compose" || true
    cp -p "$sauvegarde" "$file" || warn "  RESTAURATION ÉCHOUÉE — voir $sauvegarde"
    return 1
  fi

  ok "  ${#a_ecrire[@]} ligne(s) ajoutée(s) — sauvegarde : $sauvegarde"
  return "$reste"
}
