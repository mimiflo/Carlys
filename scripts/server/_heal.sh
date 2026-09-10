# shellcheck shell=bash
# Remettre debout ce qui est tombé — et savoir s'arrêter.
#
# CE QU'UNE AUTO-RÉPARATION DOIT SURTOUT SAVOIR FAIRE, c'est renoncer. Un
# conteneur qui meurt au démarrage — migration incompatible, secret manquant,
# image corrompue — remourra au redémarrage suivant. Le relancer en boucle ne
# répare rien : cela consomme la machine, noie le journal, et surtout DONNE
# L'IMPRESSION QUE QUELQU'UN S'EN OCCUPE, ce qui retarde le moment où un humain
# regarde. D'où un plafond de réparations par heure, au-delà duquel ce fichier
# ne fait plus rien d'autre que le dire.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

heal_max_par_heure() { env_value CARLYS_HEAL_MAX_PER_HOUR "$1" 5; }
# Une sonde « unhealthy » isolée arrive : redémarrage de PostgreSQL, pic de
# charge, requête lente. On agit à partir du DEUXIÈME passage consécutif.
heal_patience_sonde() { env_value CARLYS_HEAL_UNHEALTHY_PASSES "$1" 2; }

# `heal_inventaire <env> <.env>` — une ligne par conteneur de la pile :
#     <nom>|<service>|<état>|<santé>|<politique de redémarrage>
#
# `--all` : un conteneur ARRÊTÉ est précisément ce qu'on cherche, et
# `compose ps` sans option ne le montre pas.
#
# La politique de redémarrage est là pour distinguer un SERVICE d'une TÂCHE.
# `minio-init` crée le bucket puis se termine avec succès : il est « exited »
# en régime normal, et le redémarrer serait une réparation imaginaire. Le
# compose versionné exprime déjà la différence (`restart: unless-stopped` pour
# les services, `restart: 'no'` pour les tâches) : on la lit là plutôt que
# d'écrire une liste de noms qui périmerait au prochain service ajouté.
heal_inventaire() {
  local env_name="$1" file="$2" id
  while read -r id; do
    [ -n "$id" ] || continue
    docker inspect --format \
      '{{.Name}}|{{index .Config.Labels "com.docker.compose.service"}}|{{.State.Status}}|{{with index .State "Health"}}{{.Status}}{{else}}sans-sonde{{end}}|{{.HostConfig.RestartPolicy.Name}}' \
      "$id" 2>/dev/null || true
  done < <(dc "$env_name" "$file" ps -q --all 2>/dev/null || true)
}

# Combien de réparations dans l'heure écoulée, d'après l'état.
heal_compte_recent() {
  local env_name="$1" fenetre debut compte=0 horodatage
  fenetre="$(state_get "$env_name" reparations '')"
  debut="$(($(maintenant) - 3600))"
  for horodatage in $fenetre; do
    [ "$horodatage" -ge "$debut" ] 2>/dev/null && compte=$((compte + 1))
  done
  printf '%d' "$compte"
}

# Inscrit une réparation et purge ce qui a plus d'une heure : sans la purge,
# la liste grandirait indéfiniment et le plafond finirait par se déclencher
# sur des réparations d'il y a six mois.
heal_inscrire() {
  local env_name="$1" fenetre debut gardees='' horodatage
  fenetre="$(state_get "$env_name" reparations '')"
  debut="$(($(maintenant) - 3600))"
  for horodatage in $fenetre; do
    [ "$horodatage" -ge "$debut" ] 2>/dev/null && gardees="$gardees $horodatage"
  done
  gardees="$gardees $(maintenant)"
  state_set "$env_name" reparations "${gardees# }"
}

# `heal_run <env> <.env>` — un passage de réparation.
#
# Rend 0 si tout va bien ou si la réparation a été tentée, 1 si le plafond est
# atteint (donc si un humain doit regarder).
heal_run() {
  local env_name="$1" file="$2"
  local nom service etat sante politique
  local absents=() malades=() recent plafond passes compteur cle

  # ── « JAMAIS DÉPLOYÉ » N'EST PAS UNE PANNE ────────────────────────────────
  #
  # setup.sh dépose les DEUX .env dès la mise en place. Pendant toute la phase
  # où seule la recette tourne — c'est-à-dire longtemps — la production existe
  # sur le disque sans avoir jamais rien hébergé, avec un
  # CARLYS_TAG=sha-CHANGE_MOI_SHA12 d'exemple.
  #
  # Sans ce garde, la supervision y trouvait 0 exemplaire pour 1 voulu,
  # concluait à une panne, et lançait `docker compose up -d` sur un tag qui
  # n'existe pas — toutes les deux minutes, avec à chaque fois une tentative
  # de connexion au registre. Trois dégâts, tous mesurés dans le journal :
  # le plafond de cinq réparations par heure était consommé par une pile qui
  # n'avait rien à réparer, le journal devenait illisible, et `heal` se
  # trouvait DÉSARMÉ pour la recette, qui elle sert le trafic.
  #
  # backup.sh tenait déjà ce raisonnement (« une alerte qui crie tous les
  # jours ne se lit plus ») ; il manquait ici. Le signal juste est le même :
  # DEPLOYED vide = rien n'a jamais tourné, donc rien à relever.
  if [ -z "$(deployed_current "$env_name")" ]; then
    info "« $env_name » n'a jamais été déployé — rien à réparer"
    info "  pour le monter : carlysctl deploy $env_name <sha>"
    return 0
  fi

  local voulus actuels
  voulus="$(api_replicas_wanted "$env_name" "$file")"
  actuels="$(api_replica_ports "$env_name" "$file" | wc -l)"

  while IFS='|' read -r nom service etat sante politique; do
    [ -n "${service:-}" ] || continue
    nom="${nom#/}"
    # Une tâche terminée n'est pas une panne.
    [ "$politique" = 'no' ] && continue

    cle="malade_${nom//[^A-Za-z0-9_]/_}"
    if [ "$etat" != running ]; then
      absents+=("$nom ($service, $etat)")
      state_set "$env_name" "$cle" 0
      continue
    fi
    if [ "$sante" = unhealthy ]; then
      compteur="$(state_get "$env_name" "$cle" 0)"
      compteur=$((compteur + 1))
      state_set "$env_name" "$cle" "$compteur"
      passes="$(heal_patience_sonde "$file")"
      if [ "$compteur" -ge "$passes" ]; then
        malades+=("$nom")
      else
        info "$nom est « unhealthy » (passage $compteur sur $passes) — on attend le suivant"
      fi
      continue
    fi
    state_set "$env_name" "$cle" 0
  done < <(heal_inventaire "$env_name" "$file")

  # ── L'AMONT NGINX EST RÉCONCILIÉ DANS TOUS LES CAS ────────────────────────
  #
  # Y compris — surtout — sur une pile parfaitement saine. Un amont périmé
  # n'est PAS un problème de conteneur : les conteneurs vont bien, ils sont au
  # bon nombre, leurs sondes sont vertes, et Nginx envoie pourtant le trafic
  # ailleurs. Cette panne-là ne se voit qu'ici.
  #
  # La première rédaction sortait avant, sur « pile saine — rien à réparer ».
  # Conséquence trouvée lors de la PREMIÈRE migration d'un vrai serveur :
  # `carlysctl heal` était incapable de réparer un amont manquant, alors que
  # c'est exactement ce que `carlysctl status` conseille de lancer quand il
  # affiche « ⚠ ÉCART nginx ↔ réalité », et ce que dit le tableau de
  # diagnostic. Le conseil était faux, et la seule commande qui aurait remis
  # l'amont en place était `scale`, qui n'a rien à voir.
  #
  # `nginx_apply_upstream` ne recharge que si le contenu a changé : sur une
  # pile stable, cet appel coûte un rendu de fichier et une comparaison, toutes
  # les deux minutes. C'est le bon prix pour la seule détection de cette panne.
  if [ "${#absents[@]}" -eq 0 ] && [ "${#malades[@]}" -eq 0 ] && [ "$actuels" -eq "$voulus" ]; then
    ok "pile saine — aucun conteneur à relever"
    nginx_apply_upstream "$env_name" "$file" || return 1
    return 0
  fi

  recent="$(heal_compte_recent "$env_name")"
  plafond="$(heal_max_par_heure "$file")"
  if [ "$recent" -ge "$plafond" ]; then
    warn "PLAFOND DE RÉPARATIONS ATTEINT : $recent dans l'heure (maximum $plafond)."
    warn "  Plus aucune réparation automatique ne sera tentée sur « $env_name »."
    warn "  Ce plafond existe pour qu'une panne qui revient à chaque redémarrage"
    warn "  cesse d'être masquée. À regarder à la main :"
    warn "    carlysctl status $env_name"
    warn "    docker compose -p $(compose_project "$env_name" "$file") logs --tail 200"
    return 1
  fi

  [ "${#absents[@]}" -gt 0 ] && warn "conteneurs absents ou arrêtés : ${absents[*]}"
  [ "${#malades[@]}" -gt 0 ] && warn "conteneurs « unhealthy » persistants : ${malades[*]}"
  [ "$actuels" -ne "$voulus" ] && warn "exemplaires d'API : $actuels en vie pour $voulus voulus"

  # `up -d` d'abord : il recrée ce qui manque et relance ce qui est arrêté,
  # en respectant les dépendances du compose — ce qu'un `docker start` pris
  # conteneur par conteneur ne saurait pas faire.
  step "Réparation de « $env_name »"
  if ! dc "$env_name" "$file" up -d; then
    heal_inscrire "$env_name"
    warn "« docker compose up -d » a échoué — la pile reste en l'état."
    return 1
  fi

  # Puis les « unhealthy », que `up -d` ne touche pas : ils TOURNENT, Compose
  # les considère donc à jour. Seul un redémarrage leur redonne une chance.
  if [ "${#malades[@]}" -gt 0 ]; then
    for nom in "${malades[@]}"; do
      info "redémarrage de $nom"
      docker restart "$nom" >/dev/null 2>&1 || warn "redémarrage de $nom refusé"
      state_set "$env_name" "malade_${nom//[^A-Za-z0-9_]/_}" 0
    done
  fi

  heal_inscrire "$env_name"

  # Attendre que ce qu'on vient de relever soit SAIN avant de le déclarer à
  # Nginx. Mesuré sans cette attente : `heal` relançait bien le troisième
  # exemplaire, mais l'amont n'en portait que deux — le conteneur relevé
  # n'était pas encore sain au moment de l'écriture, et le passage suivant
  # trouvait le même écart, relançait `up -d`, et réécrivait le même amont
  # incomplet. La pile était réparée sans que le trafic y aille jamais.
  api_attendre_exemplaires_sains "$env_name" "$file" "$voulus"
  nginx_apply_upstream "$env_name" "$file" || true
  return 0
}
