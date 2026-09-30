#!/usr/bin/env bash
# Les vhosts Carlys, chargés par un VRAI nginx, devant une application factice.
#
#   bash infrastructure/nginx/tests/nginx_test.sh
#
# Vérifie ce qu'aucune lecture du fichier ne prouve :
#   - le journal d'accès ne garde AUCUN jeton des liens d'e-mail — ni dans la
#     requête, ni dans le Referer des requêtes que la page déclenche — alors
#     que l'application, elle, reçoit toujours le lien complet ;
#   - le journal d'ERREURS non plus, quand l'amont est tombé (502) : c'est là
#     que nginx recopie la ligne de requête brute ;
#   - le JSON de l'API part compressé, y compris relayé en HTTP/1.0 par un
#     proxy (gra6), mais pas les petites réponses ni celles
#     d'authentification ;
#   - le flux SSE du coach passe évènement par évènement, sans être retenu.
#
# Aucun droit root n'est requis : nginx tourne sur un port haut de la boucle
# locale, avec ses fichiers dans un dossier jetable. Sans nginx sur la
# machine, l'essai est SAUTÉ et le dit (échec sous CARLYS_TEST_EXIGER_NGINX=oui).
set -euo pipefail

ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
NGINX_DIR="${CARLYS_TEST_NGINX_DIR:-$(cd -- "$ICI/.." && pwd -P)}"
T="$(mktemp -d)"
chmod 755 "$T"
nettoyer() {
  if [ -f "$T/nginx.pid" ]; then kill "$(cat "$T/nginx.pid")" 2>/dev/null || true; fi
  if [ -n "${APP_PID:-}" ]; then kill "$APP_PID" 2>/dev/null || true; fi
  rm -rf "$T"
}
trap nettoyer EXIT
[ -z "${CARLYS_TEST_GARDER:-}" ] || trap - EXIT

echecs=0; reussis=0
verifier() {
  if [ "$2" = "$3" ]; then reussis=$((reussis + 1)); printf '  ok    %s\n' "$1"
  else echecs=$((echecs + 1)); printf '  ÉCHEC %s : attendu « %s », obtenu « %s »\n' "$1" "$2" "$3"; fi
  return 0
}

NGINX="$(command -v nginx || true)"
[ -n "$NGINX" ] || [ ! -x /usr/sbin/nginx ] || NGINX=/usr/sbin/nginx
if [ -z "$NGINX" ]; then
  echo "  SAUTÉ nginx absent de cette machine"
  [ "${CARLYS_TEST_EXIGER_NGINX:-non}" != oui ]
  exit $?
fi

libre() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
PORT="$(libre)"; APP="$(libre)"

# ── L'application factice : note chaque requête reçue, rend du JSON ─────────
cat > "$T/app.py" <<'FIN'
import http.server, json, sys, time
journal = open(sys.argv[2], "a", buffering=1)
gros = json.dumps({"data": [{"id": i, "nom": "Développé couché", "description": "Allongé sur le banc, descendre la barre jusqu'à la poitrine puis pousser."} for i in range(80)], "meta": {}, "requestId": "r"})
class Gestion(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        journal.write(self.path + "\n")
        corps = (json.dumps({"data": {"ok": True}}) if self.path.startswith("/api/v1/petit") else gros).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8" if self.path.startswith("/api/") else "text/html")
        self.send_header("Content-Length", str(len(corps)))
        self.end_headers()
        self.wfile.write(corps)
    def do_POST(self):
        # Un flux SSE comme celui du coach : un évènement, une pause, un autre.
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()
        self.wfile.write(b"event: delta\ndata: {\"text\":\"Bon\"}\n\n"); self.wfile.flush()
        time.sleep(1.5)
        self.wfile.write(b"event: done\ndata: {}\n\n"); self.wfile.flush()
        self.close_connection = True
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Gestion).serve_forever()
FIN
python3 "$T/app.py" "$APP" "$T/app.log" &
APP_PID=$!
for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:$APP/api/v1/petit" && break
  sleep 0.1
done

# ── La configuration : celle du dépôt, transposée sur la boucle locale ─────
mkdir -p "$T/sites" "$T/conf.d" "$T/snippets" "$T/tmp"
chmod 1777 "$T/tmp"
cp "$NGINX_DIR"/snippets/*.conf "$T/snippets/"
if [ -d "$NGINX_DIR/conf.d" ]; then cp "$NGINX_DIR"/conf.d/*.conf "$T/conf.d/"; fi
for env_name in production staging; do
  sed -e "s|^\( *\)listen 80;|\1listen 127.0.0.1:$PORT;|" -e '/listen \[::\]:80;/d' \
      -e "s|/var/log/nginx/access.log|$T/access.log|" \
      -e "s|/var/log/nginx/error.log|$T/error.log|" \
      -e "s|server 127.0.0.1:[0-9]*;|server 127.0.0.1:$APP;|" \
      "$NGINX_DIR/carlys-$env_name.conf.example" > "$T/sites/$env_name.conf"
  printf 'upstream carlys_api_%s { server 127.0.0.1:%s; }\n' "$env_name" "$APP" > "$T/conf.d/amont-$env_name.conf"
done
# Le reste imite le nginx.conf de Debian/Ubuntu : un journal global au format
# `combined`, `gzip on` sans types, conf.d puis sites.
cat > "$T/nginx.conf" <<FIN
pid $T/nginx.pid;
error_log $T/error.log;
events {}
http {
  include /etc/nginx/mime.types;
  access_log $T/global.log;
  gzip on;
  client_body_temp_path $T/tmp/corps;
  proxy_temp_path $T/tmp/proxy;
  fastcgi_temp_path $T/tmp/fcgi;
  uwsgi_temp_path $T/tmp/uwsgi;
  scgi_temp_path $T/tmp/scgi;
  include $T/conf.d/*.conf;
  include $T/sites/*.conf;
}
FIN
# `-e` : sans lui, nginx ouvre d'abord le journal d'erreurs compilé
# (/var/log/nginx/error.log), refusé à un utilisateur ordinaire — la CI.
if ! "$NGINX" -t -e "$T/error.log" -p "$T" -c "$T/nginx.conf" > "$T/test.log" 2>&1; then
  verifier "nginx accepte la configuration" oui non
  sed 's/^/        | /' "$T/test.log"
  printf '\n%s réussi(s), %s échec(s)\n' "$reussis" "$echecs"
  exit 1
fi
verifier "nginx accepte la configuration" oui oui
"$NGINX" -e "$T/error.log" -p "$T" -c "$T/nginx.conf"
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" -H 'Host: app.carlys.example')" = 200 ] && break
  sleep 0.1
done

requete() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "journal d'accès sans jeton"
for hote in app.carlys.example app-staging.carlys.example; do
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/reset-password?token=JETON-RESET-$hote" > /dev/null
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/verify-email?token=JETON-VERIF-$hote" > /dev/null
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/reset-password?token=JETON-RSC-$hote&_rsc=1a2b" > /dev/null
  requete -H "Host: $hote" -H "Referer: https://$hote/reset-password?token=JETON-REFERENT-$hote" \
    "http://127.0.0.1:$PORT/favicon.ico" > /dev/null
done
requete -H 'Host: api.carlys.example' -H 'Referer: https://app.carlys.example/verify-email?token=JETON-API' \
  "http://127.0.0.1:$PORT/api/v1/auth/verify-email" > /dev/null
sleep 0.2
verifier "aucun jeton dans le journal d'accès" 0 "$(grep -c 'JETON-' "$T/access.log" 2>/dev/null || true)"
verifier "aucun jeton dans le journal global non plus" 0 "$(grep -c 'JETON-' "$T/global.log" 2>/dev/null || true)"
verifier "les requêtes sont bien journalisées, jeton masqué" 2 \
  "$(grep -c '"GET /reset-password?token=\*\*\* HTTP' "$T/access.log" 2>/dev/null || true)"
verifier "le reste de l'adresse survit (paramètre _rsc)" 2 \
  "$(grep -c 'token=\*\*\*&_rsc=1a2b' "$T/access.log" 2>/dev/null || true)"
verifier "le Referer est masqué lui aussi" 3 "$(grep -c '"https://[a-z.-]*/[a-z-]*?token=\*\*\*"' "$T/access.log" 2>/dev/null || true)"
verifier "l'application reçoit toujours le lien complet (liens intacts)" 1 \
  "$(grep -c '^/reset-password?token=JETON-RESET-app.carlys.example$' "$T/app.log" || true)"

echo
echo "compression du JSON de l'API"
entetes() { curl -s -D - -o /dev/null "$@" | tr -d '\r'; }
for hote in api.carlys.example api-staging.carlys.example; do
  e="$(entetes --http1.0 -H "Host: $hote" -H 'Accept-Encoding: gzip' -H 'Via: 1.1 gra6' "http://127.0.0.1:$PORT/api/v1/exercises?limit=50")"
  verifier "$hote : JSON relayé en HTTP/1.0 par un proxy → gzip" oui \
    "$(grep -qi '^content-encoding: gzip' <<< "$e" && echo oui || echo non)"
  verifier "$hote : Vary: Accept-Encoding" oui "$(grep -qi '^vary: accept-encoding' <<< "$e" && echo oui || echo non)"
  e="$(entetes -H "Host: $hote" -H 'Accept-Encoding: gzip' "http://127.0.0.1:$PORT/api/v1/petit")"
  verifier "$hote : petite réponse (< 1 Ko) laissée telle quelle" non \
    "$(grep -qi '^content-encoding: gzip' <<< "$e" && echo oui || echo non)"
  for chemin in /api/v1/auth/login /api/v1/admin/auth/login; do
    e="$(entetes -H "Host: $hote" -H 'Accept-Encoding: gzip' "http://127.0.0.1:$PORT$chemin")"
    verifier "$hote : $chemin jamais compressé (BREACH)" non \
      "$(grep -qi '^content-encoding: gzip' <<< "$e" && echo oui || echo non)"
  done
  e="$(entetes -H "Host: $hote" "http://127.0.0.1:$PORT/api/v1/exercises?limit=50")"
  verifier "$hote : sans Accept-Encoding, réponse en clair" non \
    "$(grep -qi '^content-encoding: gzip' <<< "$e" && echo oui || echo non)"
done
brut="$(curl -s -H 'Host: api.carlys.example' "http://127.0.0.1:$PORT/api/v1/exercises?limit=50" | wc -c)"
comprime="$(curl -s -H 'Host: api.carlys.example' -H 'Accept-Encoding: gzip' "http://127.0.0.1:$PORT/api/v1/exercises?limit=50" | wc -c)"
echo "  (réponse de l'application factice : $brut octets bruts, $comprime compressés)"
verifier "le corps compressé se décompresse à l'identique" oui \
  "$(cmp -s <(curl -s -H 'Host: api.carlys.example' "http://127.0.0.1:$PORT/api/v1/exercises?limit=50") \
     <(curl -s -H 'Host: api.carlys.example' -H 'Accept-Encoding: gzip' "http://127.0.0.1:$PORT/api/v1/exercises?limit=50" | gunzip) && echo oui || echo non)"

echo
echo "flux du coach relayé au fil de l'eau"
for hote in api.carlys.example api-staging.carlys.example; do
  debut="$(curl -s -N --max-time 1 -X POST -H "Host: $hote" \
    "http://127.0.0.1:$PORT/api/v1/coach/conversations/c/messages/stream" || true)"
  verifier "$hote : le premier évènement arrive avant la fin du flux" oui \
    "$(grep -q '^event: delta' <<< "$debut" && echo oui || echo non)"
  e="$(curl -s -D - -o /dev/null -X POST -H "Host: $hote" "http://127.0.0.1:$PORT/api/v1/coach/conversations/c/messages/stream" | tr -d '\r')"
  verifier "$hote : X-Accel-Buffering transmis à gra6" oui \
    "$(grep -qi '^x-accel-buffering: no' <<< "$e" && echo oui || echo non)"
done

echo
echo "journal d'erreurs sans jeton, amont tombé"
# L'application s'arrête : c'est l'admin redémarré pendant un déploiement.
# nginx répond 502 et écrit l'erreur de l'amont, avec la ligne de requête.
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
APP_PID=''
for hote in app.carlys.example app-staging.carlys.example; do
  verifier "$hote : amont tombé, la page à jeton répond 502" 502 \
    "$(requete -H "Host: $hote" "http://127.0.0.1:$PORT/reset-password?token=JETON-PANNE-$hote")"
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/verify-email?token=JETON-PANNE-VERIF-$hote" > /dev/null
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/reset-password?token=JETON-PANNE-RSC-$hote&_rsc=1a2b" > /dev/null
  # Le témoin : une autre page de l'hôte, dont l'erreur DOIT s'écrire — sans
  # lui, un journal vide prouverait seulement que rien n'a été journalisé.
  requete -H "Host: $hote" "http://127.0.0.1:$PORT/login?temoin=TEMOIN-$hote" > /dev/null
done
sleep 0.2
verifier "aucun jeton dans le journal d'erreurs" 0 "$(grep -c 'JETON-' "$T/error.log" 2>/dev/null || true)"
verifier "la panne reste écrite pour les autres pages (témoin)" 2 \
  "$(grep -c 'upstream.*request: "GET /login?temoin=TEMOIN-' "$T/error.log" 2>/dev/null || true)"
verifier "le 502 des pages à jeton reste au journal d'accès, jeton masqué" 2 \
  "$(grep -c '"GET /reset-password?token=\*\*\* HTTP/1.1" 502' "$T/access.log" 2>/dev/null || true)"

printf '\n%s réussi(s), %s échec(s)\n' "$reussis" "$echecs"
[ "$echecs" -eq 0 ]
