# Dépendances : audit et exceptions

`security-ci` refuse tout avis **high** ou **critical** (`pnpm audit --audit-level high`),
développement compris. Une faille se corrige d'abord par une surcharge vers la version
corrigée (`pnpm.overrides` de `package.json`), jamais en baissant le seuil.

## Avis ignorés (`pnpm.auditConfig.ignoreGhsas`)

Une seule voie pour ignorer un avis : il n'existe AUCUNE version corrigée, et la
dépendance n'atteint pas la production. Chaque entrée s'écrit ici, avec sa raison, et se
retire dès qu'un correctif paraît.

| Avis | Paquet | Pourquoi ignoré | Revoir |
| --- | --- | --- | --- |
| [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) | `braces` ≤ 3.0.3 (dépassement de pile sur des motifs très imbriqués) | Aucune version corrigée (3 octobre 2026). Seul chemin : `apps/admin` → `eslint-config-next` → `fast-glob` → `micromatch` → `braces`, l'outil de lint de l'admin : les motifs viennent de la configuration du dépôt, jamais d'un utilisateur. `pnpm audit --prod` est vierge. | À chaque mise à jour de `eslint-config-next`, et dès qu'une version corrigée de `braces` paraît |
