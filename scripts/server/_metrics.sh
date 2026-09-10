# shellcheck shell=bash
# Lecture de /metrics sur les exemplaires de l'API.
#
# POURQUOI ON INTERROGE CHAQUE EXEMPLAIRE, ET PAS NGINX. Passer par Nginx
# atteindrait UN exemplaire au hasard : on lirait le débit d'un tiers de la
# pile en croyant lire celui de la pile. Les compteurs HTTP sont par processus
# (c'est voulu : la répartition entre exemplaires est une information), donc
# la somme se fait ici.
#
# La présence, elle, est déjà globale — elle est comptée dans Redis. On ne
# l'additionne surtout PAS : ce serait multiplier les utilisateurs par le
# nombre d'exemplaires. On prend la valeur d'un exemplaire dont la mesure
# vient d'aboutir (`carlys_api_presence_up` à 1).
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Délai de lecture d'un exemplaire. Court : /metrics est local, et un
# exemplaire qui met plus de trois secondes à rendre son registre est un
# exemplaire en difficulté — l'attendre retarderait la décision au lieu de
# l'éclairer.
CARLYS_METRICS_TIMEOUT="${CARLYS_METRICS_TIMEOUT:-3}"

# `metrics_scrape_one <port> <jeton>` — l'exposition brute d'un exemplaire.
#
# `--noproxy '*'` : sur une machine où http_proxy est posé pour les paquets,
# curl enverrait une requête vers 127.0.0.1 AU PROXY. Sans cette option, la
# supervision d'un serveur derrière un proxy sortant lit… le proxy.
#
# LE CODE HTTP EST RENDU AVEC LE CORPS, et ce n'est pas un détail. `/metrics`
# est gardé : sur un environnement où NODE_ENV vaut « production » — ce qui
# est le cas de la RECETTE aussi — il répond 404 sans METRICS_TOKEN, et 401
# avec un mauvais. Ces deux réponses ont un corps NON VIDE (l'enveloppe
# d'erreur de l'API). Sans le code, elles passaient pour des lectures
# réussies : l'orchestrateur comptait un exemplaire « lu », n'y trouvait
# évidemment aucune série, et concluait « Redis illisible » — en accusant
# Redis d'un refus qui venait de l'API. Mesuré sur le premier serveur migré.
metrics_scrape_one() {
  local port="$1" jeton="${2-}" args=()
  args=(-s --noproxy '*' -m "$CARLYS_METRICS_TIMEOUT" -w '\n#--code--%{http_code}')
  [ -n "$jeton" ] && args+=(-H "Authorization: Bearer $jeton")
  # `|| true` et pas de repli : même sur connexion refusée, `-w` imprime le
  # code (000). En ajouter un second brouillerait le compte.
  curl "${args[@]}" "http://127.0.0.1:${port}/metrics" 2>/dev/null || true
}

# `metrics_summary <env> <.env>` — une ligne de `clé=valeur`, séparées par des
# espaces :
#
#   lus=<exemplaires ayant répondu>
#   utilisateurs=<utilisateurs en ligne, -1 si inconnu>
#   requetes=<compteur cumulé de requêtes HTTP, somme des exemplaires>
#   latence_somme=<secondes cumulées>  latence_compte=<requêtes comptées>
#
# Les trois derniers sont des COMPTEURS CUMULÉS, pas des débits : c'est
# l'appelant qui les compare à l'échantillon précédent (voir metrics_rate).
# Les rendre déjà dérivés obligerait cette fonction à connaître l'état, donc à
# ne plus pouvoir être appelée pour un simple coup d'œil.
metrics_summary() {
  local env_name="$1" file="$2" jeton port ports=()
  jeton="$(env_value METRICS_TOKEN "$file" '')"
  mapfile -t ports < <(api_replica_ports "$env_name" "$file")

  if [ "${#ports[@]}" -eq 0 ]; then
    printf 'horodatage=%s lus=0 refuses=0 code= utilisateurs=-1 requetes=0 latence_somme=0 latence_compte=0' "$(maintenant)"
    return 0
  fi

  {
    for port in "${ports[@]}"; do
      metrics_scrape_one "$port" "$jeton"
      # Séparateur d'exemplaire. Il ferme le bloc de CHACUN — y compris le
      # dernier — et c'est ce qui permet de décider par exemplaire plutôt que
      # sur un flot indistinct : la présence se lit chez UN exemplaire, les
      # compteurs HTTP s'additionnent sur tous.
      printf '\n#--exemplaire--\n'
    done
  } | awk -v horodatage="$(maintenant)" '
    # Le code HTTP que curl imprime après le corps. Il ferme la lecture dun
    # exemplaire ; le separateur qui suit la comptabilise.
    # `sub` plutot que `substr($0, N)` : compter les caracteres du prefixe a
    # la main donne « 04 » au lieu de « 404 » a un caractere pres, et le
    # diagnostic tombe alors dans aucune branche. La substitution ne compte
    # rien.
    /^#--code--/ { code = $0; sub(/^#--code--/, "", code); next }

    /^#--exemplaire--$/ {
      if (code != "200") {
        # 404 : pas de METRICS_TOKEN alors que NODE_ENV=production.
        # 401 : le jeton du .env ne correspond pas. 000 : rien na repondu.
        # Dans les trois cas le corps est NON VIDE et ne contient aucune
        # serie : le compter comme une lecture ferait accuser Redis.
        if (code != "") { refuses++; dernier_code = code }
        vu = 0; up = 0; u = -1; code = ""
        next
      }
      if (vu) {
        lus++
        # Presence : globale (comptee dans Redis), donc JAMAIS additionnee.
        # La sommer multiplierait les utilisateurs par le nombre
        # dexemplaires. On retient celle du premier exemplaire dont la
        # mesure a abouti ; presence_up a 0 signale « je ne sais pas », et
        # surtout pas « personne ».
        # (Sans accent ni apostrophe : ce commentaire vit DANS le programme
        # awk, qui est delimite par des apostrophes simples.)
        if (up && !fige) { utilisateurs = u; fige = 1 }
      }
      vu = 0; up = 0; u = -1; code = ""
      next
    }
    { vu = 1 }

    $1 == "carlys_api_presence_up"  { up = ($2 == 1) }
    $1 == "carlys_api_online_users" { u = $2 }

    # Debit et latence : par processus, donc additionnes.
    /^carlys_api_http_requests_total\{/                  { requetes += $2 }
    /^carlys_api_http_request_duration_seconds_sum\{/    { lat_somme += $2 }
    /^carlys_api_http_request_duration_seconds_count\{/  { lat_compte += $2 }

    END {
      printf "horodatage=%s lus=%d refuses=%d code=%s utilisateurs=%s requetes=%d latence_somme=%.6f latence_compte=%d",
        horodatage, lus, refuses, dernier_code, (fige ? utilisateurs : -1),
        requetes, lat_somme, lat_compte
    }
  '
}

# `metrics_field <résumé> <clé>` — extrait une valeur du résumé ci-dessus.
metrics_field() {
  printf '%s' "$1" | tr ' ' '\n' | awk -F= -v k="$2" '$1 == k { print $2 }'
}

# `metrics_rate <échantillon précédent> <échantillon courant>` — rend
#     requetes_par_seconde latence_moyenne_ms intervalle_secondes
# ou une ligne vide si l'intervalle n'est pas exploitable.
#
# TROIS RAISONS DE NE RIEN RENDRE, et chacune a un mode de panne derrière :
#
#   - pas d'échantillon précédent : le tout premier passage n'a rien à
#     comparer. Rendre « 0 requête par seconde » ferait réduire la pile au
#     redémarrage du superviseur ;
#   - intervalle nul ou négatif : horloge ajustée, ou deux passages dans la
#     même seconde. Diviser par ça produit l'infini ;
#   - compteur qui RECULE : un exemplaire a redémarré et ses compteurs sont
#     repartis de zéro, donc la somme a baissé. L'intervalle n'est pas
#     mesurable ; le sauter est la seule réponse honnête.
metrics_rate() {
  local avant="$1" apres="$2"
  local t0 t1 r0 r1 s0 s1 c0 c1
  t0="$(metrics_field "$avant" horodatage)"; t1="$(metrics_field "$apres" horodatage)"
  r0="$(metrics_field "$avant" requetes)";   r1="$(metrics_field "$apres" requetes)"
  s0="$(metrics_field "$avant" latence_somme)"; s1="$(metrics_field "$apres" latence_somme)"
  c0="$(metrics_field "$avant" latence_compte)"; c1="$(metrics_field "$apres" latence_compte)"

  [ -n "${t0:-}" ] && [ -n "${t1:-}" ] && [ -n "${r0:-}" ] && [ -n "${r1:-}" ] || return 0

  awk -v t0="$t0" -v t1="$t1" -v r0="$r0" -v r1="$r1" \
      -v s0="${s0:-0}" -v s1="${s1:-0}" -v c0="${c0:-0}" -v c1="${c1:-0}" '
    BEGIN {
      dt = t1 - t0
      if (dt <= 0) exit 0
      if (r1 < r0 || c1 < c0 || s1 < s0) exit 0
      dc = c1 - c0
      latence = (dc > 0) ? ((s1 - s0) / dc) * 1000 : 0
      printf "%.3f %.1f %d\n", (r1 - r0) / dt, latence, dt
    }'
}
