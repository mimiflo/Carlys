#!/usr/bin/env bash
# Prépare TOUT ce dont un lancement a besoin, et seulement si ça manque :
# remise à niveau du poste, infrastructure Docker, migrations, émulateur.
#
# Accroché à `F5` (tâche « Préparer Carlys »), mais utilisable seul :
#     bash scripts/dev_up.sh
#
# Deux principes. Chaque étape est CONDITIONNELLE — relancer quand tout est
# déjà debout doit coûter quelques secondes, pas un redémarrage. Et rien ne
# bloque : une étape qui échoue explique et laisse la suivante tenter sa
# chance, parce qu'un préalable qui empêche de lancer est pire que le
# problème qu'il prétend éviter.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 0

say() { printf '\n\033[1m── %s\033[0m\n' "$1"; }
warn() { printf '  ⚠ %s\n' "$1"; }

# ── 1. Le poste suit-il le dépôt ? ──────────────────────────────────────
# Les hooks git couvrent le cas normal (pull, checkout, rebase). Ce filet
# rattrape le reste : hooks pas encore armés, dépôt mis à jour autrement.
STAMP=".git/carlys-prepared-at"
HEAD_NOW="$(git rev-parse HEAD 2>/dev/null)"
LAST="$(cat "$STAMP" 2>/dev/null || true)"
if [ "$HEAD_NOW" != "$LAST" ]; then
  say "Remise à niveau du poste"
  if [ -n "$LAST" ] && git rev-parse -q --verify "$LAST^{commit}" >/dev/null 2>&1; then
    bash scripts/after_update.sh "$LAST" "$HEAD_NOW"
  else
    bash scripts/after_update.sh # première fois : tout vérifier
  fi
  echo "$HEAD_NOW" > "$STAMP"
fi

# ── 2. Infrastructure Docker ────────────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
  RUNNING="$(docker compose ps --services --status running 2>/dev/null | wc -l)"
  EXPECTED="$(docker compose config --services 2>/dev/null | wc -l)"
  if [ "$RUNNING" -lt "$EXPECTED" ]; then
    say "Infrastructure (postgres, redis, mailpit, minio)"
    if docker compose up -d 2>&1 | tail -3; [ "${PIPESTATUS[0]}" -eq 0 ]; then
      # Attendre que PostgreSQL ACCEPTE une connexion : un conteneur démarré
      # n'est pas une base prête, et la migration suivante échouerait.
      printf '  attente de PostgreSQL'
      ready=0
      for _ in $(seq 1 30); do
        if docker compose exec -T postgres pg_isready -q 2>/dev/null; then
          ready=1; printf ' — prête\n'; break
        fi
        printf '.'; sleep 2
      done
      [ "$ready" -eq 1 ] || printf '\n  ⚠ PostgreSQL ne répond pas après 60s.\n'
    else
      # Inutile d'attendre une base dont le démarrage vient d'échouer :
      # Docker Desktop n'est pas lancé, la boucle tournerait pour rien.
      warn "Docker n'a pas démarré l'infrastructure — Docker Desktop est-il lancé ?"
    fi
  fi
else
  warn "Docker introuvable — l'API n'aura ni base ni cache."
fi

# ── 3. Migrations en attente ────────────────────────────────────────────
# `migrate status` sort non-zéro quand il en reste à appliquer : c'est
# exactement le test qu'on veut, sans jamais migrer pour rien.
if command -v pnpm >/dev/null 2>&1 && [ -d node_modules ]; then
  if ! (cd apps/api && npx prisma migrate status >/dev/null 2>&1); then
    say "Migrations de base"
    pnpm prisma:migrate 2>&1 | tail -5 ||
      warn "Migration impossible — vérifier que Docker est démarré."
  fi
fi

# ── 4. Émulateur ────────────────────────────────────────────────────────
bash scripts/start_emulator.sh

# ── 5. Le port de l'API est-il déjà pris ? ──────────────────────────────
# Le lancement démarre l'API lui-même. Si une autre instance occupe déjà le
# port, la session de débogage échouerait sur EADDRINUSE sans dire pourquoi.
if command -v node >/dev/null 2>&1; then
  node -e '
    const net = require("net");
    const s = net.createConnection({ port: 3000, host: "127.0.0.1" });
    s.on("connect", () => {
      console.log("\n  ⚠ Le port 3000 répond déjà : une API tourne ailleurs.");
      console.log("    La session de débogage échouera — arrêter l’autre d’abord.");
      s.destroy(); process.exit(0);
    });
    s.on("error", () => process.exit(0));
    setTimeout(() => { s.destroy(); process.exit(0); }, 1500);
  ' 2>/dev/null
fi

exit 0
