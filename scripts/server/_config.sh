# shellcheck shell=bash
# La migration d'un .env vers la configuration versionnée (ADR 0017).
#
# Le .env d'un serveur mis en service avant l'ADR porte encore ses réglages,
# son état et ses secrets mêlés. Il passe EN DERNIER : tant qu'un réglage y
# reste, c'est lui qui joue. La migration le vide donc sans rien changer à ce
# qui tourne :
#   - un SECRET (clé du gabarit de secrets) reste ;
#   - l'ÉTAT (CARLYS_TAG, CARLYS_API_REPLICAS) part dans etat.env ;
#   - un réglage IDENTIQUE à la configuration versionnée part ;
#   - un réglage DIFFÉRENT reste : on reporte d'abord sa vraie valeur dans le
#     dépôt, puis on relance ;
#   - un réglage que le dépôt ne pose pas (commenté, ou absent) reste aussi,
#     signalé : le retirer reviendrait à le remettre à son défaut.
#
# Chargé par _common.sh, après _envcheck.sh. Aucun effet de bord au chargement.

CONFIG_ETAT_CLES=(CARLYS_TAG CARLYS_API_REPLICAS)

# Les deux fichiers versionnés d'un environnement.
# Ceux EN SERVICE : figés pour le sha déployé, ou ceux du clone avant.
config_fichiers() {
  local conf
  conf="$(config_dir_de "$(env_file "$1")")"
  printf '%s\n' "${conf:-$CARLYS_CONFIG_DIR}/commun.conf" "${conf:-$CARLYS_CONFIG_DIR}/$1.conf"
}

# `config_classer <env> <.env>` — une ligne « <classe>\t<clé> » par clé
# ACTIVE du .env : secret, etat, identique, different ou hors-config.
#
# ÉCHOUE FERMÉ : sans gabarit de secrets lisible, aucun secret ne serait
# reconnu, et tous passeraient pour des réglages à reporter dans le dépôt.
config_classer() {
  local env_name="$1" file="$2" cle serveur depot exemple secrets actives
  local -a fichiers=()
  mapfile -t fichiers < <(config_fichiers "$env_name")
  exemple="$(envcheck_exemple "$env_name")"
  secrets="$(envcheck_cles_exemple "$exemple" 2>/dev/null)" && [ -n "$secrets" ] || {
    warn "gabarit de secrets illisible ou vide : $exemple — classement impossible"
    return 1
  }
  actives="$({ envcheck_cles "${fichiers[0]}"; envcheck_cles "${fichiers[1]}"; } 2>/dev/null | sort -u || true)"
  while IFS= read -r cle; do
    [ -n "$cle" ] || continue
    if printf '%s\n' "${CONFIG_ETAT_CLES[@]}" | grep -xF -- "$cle" > /dev/null; then
      printf 'etat\t%s\n' "$cle"
    elif printf '%s\n' "$secrets" | grep -xF -- "$cle" > /dev/null; then
      printf 'secret\t%s\n' "$cle"
    elif printf '%s\n' "$actives" | grep -xF -- "$cle" > /dev/null; then
      serveur="$(env_value_dans "$cle" '' "$file")"
      depot="$(env_value_dans "$cle" '' "${fichiers[@]}")"
      if [ "$serveur" = "$depot" ]; then
        printf 'identique\t%s\n' "$cle"
      else
        printf 'different\t%s\n' "$cle"
      fi
    else
      printf 'hors-config\t%s\n' "$cle"
    fi
  done < <(envcheck_cles "$file" | sort -u)
}

# `config_montrer <env> <clé> <valeur>` — une valeur s'affiche seulement si la
# clé est un RÉGLAGE que le dépôt déclare (actif ou commenté dans commun.conf
# ou <env>.conf), et si elle n'a pas l'allure d'un secret (identifiant dans
# une URL, clé privée, jeton Stripe). Une LISTE BLANCHE, pas une liste noire
# de noms : une clé inconnue peut être un secret que personne n'a rangé.
#
# `grep -x … > /dev/null`, jamais `grep -q` (voir backup.sh) : sous
# `pipefail`, `-q` sort au premier résultat, la boucle qui écrit encore meurt
# de SIGPIPE, et le pipeline échoue — une clé de commun.conf, le PREMIER lu,
# passait ainsi pour un secret.
config_montrer() {
  local env_name="$1" cle="$2" valeur="$3"
  if config_fichiers "$env_name" | while IFS= read -r f; do envcheck_cles_exemple "$f" 2>/dev/null; done \
       | grep -xF -- "$cle" > /dev/null \
     && ! [[ "$valeur" =~ ://[^/?#[:space:]]*@|-----BEGIN|private_key|sk_(live|test)_|rk_live_|whsec_ ]]; then
    printf '« %s »' "$valeur"
  else
    printf '(non affichée : elle pourrait être un secret)'
  fi
}

# Le rendu de la pile, en empreinte : ce que Compose donnerait aux
# conteneurs, valeurs RÉSOLUES comprises (un `${DOMAIN}` retiré du .env se
# résout ensuite ailleurs). Jamais affiché : il contient les secrets. L'état
# en est exclu, la migration le déplace sans que l'API le lise.
config_empreinte() {
  dc "$1" "$2" config 2>/dev/null \
    | grep -vE '^[[:space:]]*(CARLYS_TAG|CARLYS_API_REPLICAS):' | sha256sum | cut -d' ' -f1
}

# `config_migrer <env> <.env> <essai|ecrire>` — le rapport, puis, en
# écriture, le .env vidé de ce qui n'a plus à y être. Rend 0 si le .env ne
# porte plus que des secrets, 1 s'il reste des réglages à reporter.
config_migrer() {
  local env_name="$1" file="$2" mode="$3"
  local classe cle valeur reste=0 sauvegarde etat classement avant
  local -a secrets=() etats=() identiques=() differents=() hors=()
  local -a fichiers=()
  mapfile -t fichiers < <(config_fichiers "$env_name")
  [ -f "${fichiers[1]}" ] || { warn "configuration versionnée absente : ${fichiers[1]} (dépôt à jour ?)"; return 1; }
  classement="$(config_classer "$env_name" "$file")" || return 1

  while IFS="$(printf '\t')" read -r classe cle; do
    case "$classe" in
      secret) secrets+=("$cle") ;;
      etat)
        # Recopiée telle quelle dans etat.env : une valeur qui n'a pas la
        # forme attendue reste où elle est, signalée.
        valeur="$(env_value_dans "$cle" '' "$file")"
        if [[ "$cle" = CARLYS_TAG && "$valeur" =~ ^sha-[A-Za-z0-9_]+$ ]] \
           || [[ "$cle" = CARLYS_API_REPLICAS && "$valeur" =~ ^[0-9]+$ ]]; then
          etats+=("$cle")
        else
          warn "  état à la forme inattendue, gardé : $cle"
          reste=1
        fi
        ;;
      identique) identiques+=("$cle") ;;
      different) differents+=("$cle") ;;
      hors-config) hors+=("$cle") ;;
    esac
  done <<< "$classement"

  info "secrets, qui restent : ${#secrets[@]}${secrets[*]:+ (${secrets[*]})}"
  for cle in ${etats[@]+"${etats[@]}"}; do
    info "  état → etat.env : $cle = $(env_value_dans "$cle" '' "$file")"
  done
  for cle in ${identiques[@]+"${identiques[@]}"}; do
    info "  identique à la configuration, retiré : $cle"
  done
  for cle in ${differents[@]+"${differents[@]}"}; do
    warn "  DIFFÉRENT, gardé : $cle — serveur $(config_montrer "$env_name" "$cle" "$(env_value_dans "$cle" '' "$file")"), dépôt $(config_montrer "$env_name" "$cle" "$(env_value_dans "$cle" '' "${fichiers[@]}")")"
    reste=1
  done
  for cle in ${hors[@]+"${hors[@]}"}; do
    warn "  absent de la configuration, gardé : $cle = $(config_montrer "$env_name" "$cle" "$(env_value_dans "$cle" '' "$file")")"
    reste=1
  done
  if [ "${#differents[@]}" -gt 0 ]; then
    info "  → un réglage DIFFÉRENT : reporter la bonne valeur dans $CARLYS_CONFIG_DIR (commit), déployer, relancer"
  fi
  if [ "${#hors[@]}" -gt 0 ]; then
    info "  → une clé ABSENTE : si ce n'est PAS un secret, la poser dans $CARLYS_CONFIG_DIR ;"
    info "    si c'en est un, l'ajouter au gabarit $(envcheck_exemple "$env_name")"
  fi

  if [ "$(( ${#etats[@]} + ${#identiques[@]} ))" -eq 0 ]; then
    ok "  rien à retirer du .env"
    return "$reste"
  fi
  if [ "$mode" != ecrire ]; then
    info "  (essai — rien n'a été écrit ; --appliquer pour le faire)"
    info "  à faire juste avant un déploiement : l'API ne recevant plus l'état, le"
    info "  prochain « up -d » recrée ses exemplaires d'un coup"
    return "$reste"
  fi

  # La preuve que rien ne change : la pile rendue AVANT, puis APRÈS. Une pile
  # que Compose refuse déjà ne se migre pas : on ne saurait rien prouver.
  dc "$env_name" "$file" config -q >/dev/null 2>&1 \
    || { warn "  Compose refuse déjà cette pile — rien n'est écrit (carlysctl doctor $env_name)"; return 1; }
  avant="$(config_empreinte "$env_name" "$file")"

  sauvegarde="$file.avant-config-$(date -u +%Y%m%dT%H%M%SZ)"
  # 600 quoi qu'il arrive : c'est une copie de tous les secrets, même si le
  # .env d'origine avait été laissé lisible par erreur.
  (umask 077 && cp "$file" "$sauvegarde") && chmod 600 "$sauvegarde" \
    || { warn "  sauvegarde impossible — rien n'est écrit"; return 1; }

  # L'état D'ABORD dans etat.env : retiré du .env avant, la version déployée
  # manquerait le temps d'une écriture.
  etat="$(dirname -- "$file")/etat.env"
  # etat.env aussi se rend, si la migration ne va pas au bout.
  local etat_avant="$etat.avant-config"
  rm -f "$etat_avant"
  [ -f "$etat" ] && cp -p "$etat" "$etat_avant"
  for cle in ${etats[@]+"${etats[@]}"}; do
    etat_creer "$etat" || { warn "  création de $etat impossible — rien n'est retiré"; return 1; }
    env_set_value "$etat" "$cle" "$(env_value_dans "$cle" '' "$file")"
  done

  # Puis le .env, par fichier temporaire et `mv`, comme env_set_value : une
  # écriture interrompue ne le laisse jamais tronqué. 600 : il ne porte plus
  # que des secrets.
  local tmp retirer
  retirer="$(printf '%s\n' ${etats[@]+"${etats[@]}"} ${identiques[@]+"${identiques[@]}"})"
  tmp="$(mktemp "${file}.XXXXXX")" || { warn "  écriture impossible à côté de $file"; return 1; }
  chmod 600 "$tmp"
  awk -v liste="$retirer" '
    BEGIN { n = split(liste, cles, "\n"); for (i = 1; i <= n; i++) if (cles[i] != "") ote[cles[i]] = 1 }
    {
      ligne = $0
      sub(/^[[:space:]]*(export[[:space:]]+)?/, "", ligne)
      cle = ligne; sub(/[[:space:]]*=.*/, "", cle)
      if (ligne ~ /^[A-Za-z_][A-Za-z_0-9]*[[:space:]]*=/ && (cle in ote)) next
      print
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; warn "  réécriture échouée — rien n'est retiré"; return 1; }
  mv -f "$tmp" "$file" || { rm -f "$tmp"; warn "  remplacement échoué — rien n'est retiré"; return 1; }

  if [ "$(config_empreinte "$env_name" "$file")" != "$avant" ]; then
    warn "  la pile rendue CHANGE après migration — retour à l'état précédent"
    warn "  (une valeur \${…} se résout autrement sans le .env : reporter le réglage dans le dépôt)"
    cp -p "$sauvegarde" "$file" || warn "  RESTAURATION ÉCHOUÉE — voir $sauvegarde"
    if [ -f "$etat_avant" ]; then mv -f "$etat_avant" "$etat"; else rm -f "$etat"; fi
    return 1
  fi
  rm -f "$etat_avant"
  ok "  $(( ${#etats[@]} + ${#identiques[@]} )) ligne(s) retirée(s) du .env, pile rendue identique"
  info "  sauvegarde, avec tous les secrets : $sauvegarde — la supprimer une fois vérifié"
  info "  les commentaires de l'ancien gabarit restent : le .env peut repartir du"
  info "  nouveau ($(envcheck_exemple "$env_name")), ses secrets recopiés"
  return "$reste"
}

# ── La configuration FIGÉE du sha déployé ──────────────────────────────────
#
# `config_figer <env> <sha>` — copie la configuration DE CE COMMIT (lue dans
# git, pas dans le clone tel qu'il est) dans <env>/config/, l'ancienne gardée
# dans <env>/config.precedent pour config_rendre. Rend 1 sans rien changer si
# le clone ne connaît pas le commit ou s'il précède l'ADR 0017 : la
# configuration en service reste, et l'avertissement le dit. Bloquer
# empêcherait le retour vers un ancien sha.
config_figer() {
  local env_name="$1" sha="$2" dir tmp f chemin
  dir="$(env_dir "$env_name")"
  for f in commun.conf "$env_name.conf"; do
    chemin="infrastructure/server/config/$f"
    git -C "$CARLYS_REPO_DIR" cat-file -e "$sha:$chemin" 2>/dev/null || {
      warn "configuration de sha-$sha introuvable dans le clone ($chemin)"
      warn "  celle en service est gardée — clone à jour ? git -C $CARLYS_REPO_DIR fetch"
      return 1
    }
  done
  tmp="$(mktemp -d "$dir/config.XXXXXX")" || return 1
  for f in commun.conf "$env_name.conf"; do
    git -C "$CARLYS_REPO_DIR" show "$sha:infrastructure/server/config/$f" > "$tmp/$f" \
      || { rm -rf "$tmp"; warn "lecture de $f à sha-$sha impossible"; return 1; }
  done
  chmod 755 "$tmp" && chmod 644 "$tmp"/*.conf
  rm -rf "$dir/config.precedent"
  if [ -d "$dir/config" ]; then
    mv "$dir/config" "$dir/config.precedent"
  else
    # Rien n'était figé : revenir en arrière, c'est retrouver le clone.
    mkdir -p "$dir/config.precedent" && : > "$dir/config.precedent/.clone"
  fi
  mv "$tmp" "$dir/config"
}

# `config_rendre <env>` — la configuration d'avant config_figer, remise en
# service (bascule ratée, retour arrière). Sans objet si rien n'a été figé.
config_rendre() {
  local dir
  dir="$(env_dir "$1")"
  [ -d "$dir/config.precedent" ] || return 0
  rm -rf "$dir/config"
  if [ -f "$dir/config.precedent/.clone" ]; then
    rm -rf "$dir/config.precedent"
  else
    mv "$dir/config.precedent" "$dir/config"
  fi
}
