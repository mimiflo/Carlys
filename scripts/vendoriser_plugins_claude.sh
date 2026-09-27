#!/usr/bin/env bash
# Recopie dans `.claude/` deux plugins Claude Code, à un commit ÉPINGLÉ :
#
#   - ponytail (DietrichGebert/ponytail, MIT) : la règle « le code le plus
#     court qui marche » injectée à chaque session et à chaque sous-agent,
#     plus six skills (/ponytail, /ponytail-review, /ponytail-audit…) ;
#   - agent-skills (addyosmani/agent-skills, MIT) : 25 skills d'ingénierie
#     (spec, plan, TDD, revue, sécurité, performance…), 4 agents et 9
#     commandes /agent-skills-<phase>.
#
# Pourquoi recopier plutôt que `/plugin install` : une session Claude Code
# sur le WEB ne charge AUCUN plugin, ni ceux que `.claude/settings.json`
# active (https://code.claude.com/docs/en/plugins/install.md, onglet « Cloud
# session »). Les skills, agents, commandes et hooks du PROJET, eux, se
# chargent partout — web comme poste local. Épingler le commit garde aussi
# la main : rien de ce que publient ces dépôts n'entre dans nos sessions
# sans une relecture et un commit.
#
# Monter de version : changer un SHA ci-dessous, relancer le script, relire
# `git diff .claude/`, commiter.
set -euo pipefail

PONYTAIL_SHA="e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156" # v4.10.0
AGENT_SKILLS_SHA="2686b620fc1fed2e8f60c704839c766b8594c6b6" # v0.6.11

racine="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cible="$racine/.claude"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cloner() { # <dépôt> <sha> <dossier>
  git init -q "$3"
  git -C "$3" fetch -q --depth 1 "https://github.com/$1.git" "$2"
  git -C "$3" checkout -q FETCH_HEAD
}
cloner DietrichGebert/ponytail "$PONYTAIL_SHA" "$tmp/ponytail"
cloner addyosmani/agent-skills "$AGENT_SKILLS_SHA" "$tmp/agent-skills"

# Repartir de zéro : un fichier retiré en amont doit disparaître ici aussi.
rm -rf "$cible/ponytail" "$cible/references" "$cible/licences"
for d in "$tmp"/ponytail/skills/* "$tmp"/agent-skills/skills/*; do
  rm -rf "$cible/skills/$(basename "$d")"
done
for f in "$tmp"/agent-skills/agents/*.md; do rm -f "$cible/agents/$(basename "$f")"; done
rm -f "$cible"/commands/agent-skills-*.md
mkdir -p "$cible"/{ponytail,skills,agents,commands,references,licences}

# ponytail : les hooks vont dans .claude/ponytail/ ; ils lisent la règle dans
# ../skills/ponytail/SKILL.md, c'est-à-dire .claude/skills/ponytail/SKILL.md.
cp "$tmp"/ponytail/hooks/*.js "$tmp"/ponytail/hooks/ponytail-statusline.sh "$cible/ponytail/"
cp -r "$tmp"/ponytail/skills/* "$cible/skills/"
cp "$tmp/ponytail/LICENSE" "$cible/licences/ponytail.txt"

# agent-skills : hors plugin, plus d'espace de noms « agent-skills: ». Les
# commandes sont préfixées pour ne pas masquer /review et /plan intégrés.
cp -r "$tmp"/agent-skills/skills/* "$cible/skills/"
cp "$tmp"/agent-skills/agents/*.md "$cible/agents/"
cp "$tmp"/agent-skills/references/*.md "$cible/references/"
for f in "$tmp"/agent-skills/.claude/commands/*.md; do
  cp "$f" "$cible/commands/agent-skills-$(basename "$f")"
done
cp "$tmp/agent-skills/LICENSE" "$cible/licences/agent-skills.txt"
grep -rlZ 'agent-skills:' "$cible/skills" "$cible/agents" "$cible"/commands/agent-skills-*.md |
  xargs -0 -r sed -i 's/agent-skills:\([a-z-]*\)/\1/g'

echo "ponytail $PONYTAIL_SHA et agent-skills $AGENT_SKILLS_SHA recopiés dans $cible."
