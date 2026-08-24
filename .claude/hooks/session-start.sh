#!/bin/bash
# Hook SessionStart — graphe de code Graphify, sans aucune commande manuelle.
#
# À l'ouverture d'une session Claude Code sur le web, ce hook installe le CLI
# graphify (paquet PyPI graphifyy) s'il manque, enregistre le skill /graphify,
# puis (re)construit graphify-out/. L'extraction est 100 % locale
# (tree-sitter) : aucun appel LLM, rien ne quitte la machine.
#
# Chaque étape est tolérante : un poste sans Python ou une panne de PyPI ne
# doit JAMAIS empêcher une session de démarrer — le graphe est un confort,
# pas une dépendance.
set -uo pipefail

# Sessions web uniquement : sur un poste local, on n'installe rien dans le dos
# du développeur (voir docs/development/poste-de-travail.md pour l'y installer).
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

export PATH="$HOME/.local/bin:$PATH"

# 1. Le CLI, s'il manque (idempotent — l'état du conteneur est mis en cache).
if ! command -v graphify >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    uv tool install --quiet "graphifyy[sql]" || exit 0
  elif command -v pipx >/dev/null 2>&1; then
    pipx install --quiet "graphifyy[sql]" || exit 0
  else
    exit 0 # pas d'outillage Python : tant pis pour le graphe, pas d'échec
  fi
fi

# 2. Le skill /graphify de l'assistant (idempotent).
graphify install --platform claude >/dev/null 2>&1 || true

# 3. Le PATH pour le reste de la session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# 4. Le graphe. Extraction locale ; le cache (graphify-out/cache) rend les
# reconstructions suivantes incrémentales.
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
graphify update . || true

exit 0
