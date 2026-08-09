# Branches et flux de travail Git

Deux branches permanentes, et rien d'autre qui vive longtemps.

| Branche   | Rôle           | Ce qu'elle contient                                              |
| --------- | -------------- | ---------------------------------------------------------------- |
| `main`    | **Production** | Ce qui est déployé, ou déployable à l'instant. Chaque avancée y est une version, marquée par un tag. |
| `develop` | **Développement** | L'intégration du travail en cours. Toujours verte en CI, pas forcément prête à déployer. |

Les branches de fonctionnalité (`feat/<sujet>`, `fix/<sujet>`, `docs/<sujet>`)
sont **temporaires** : elles partent de `develop`, y reviennent par pull
request, et sont supprimées à la fusion.

```
feat/coach-onglet ──┐
feat/theme-violet ──┤
                    ▼
                 develop ────────────▶ main ──▶ tag v0.3.0 ──▶ déploiement
                 (intégration)         (production)
```

## Pourquoi deux branches et pas une

Avec une seule branche, la question « est-ce que ce qui est en ligne correspond
au dépôt ? » n'a pas de réponse : le dernier commit peut être une expérience de
l'après-midi. Deux branches donnent une réponse permanente — `main` **est** ce
qui tourne en production.

C'est aussi ce qui rend un correctif urgent possible : on repart de `main`, on
corrige, on fusionne dans `main` **et** dans `develop`. Sans branche de
production, il faudrait d'abord démêler ce qui est prêt de ce qui ne l'est pas.

## Le cycle, en pratique

**1. Développer.** Depuis `develop` :

```bash
git checkout develop && git pull origin develop
git checkout -b feat/mon-sujet
# … travail, commits …
git push -u origin feat/mon-sujet
```

Puis une pull request **vers `develop`**. La CI se déclenche sur toute pull
request : elle doit être verte avant la fusion.

Pour un petit changement sans risque, commiter directement sur `develop` est
acceptable — la CI tourne aussi sur les pousses vers `develop`.

**2. Mettre en production.** Quand `develop` est verte et que le lot se tient :

```bash
git checkout main && git pull origin main
git merge --ff-only develop     # aucun commit de fusion : l'histoire reste lisible
git tag -a v0.3.0 -m "Coach IA, thème violet"
git push origin main --follow-tags
```

Le `--ff-only` est volontaire : si la fusion ne peut pas avancer en ligne
droite, c'est que `main` a reçu quelque chose que `develop` n'a pas — un
correctif urgent, typiquement — et il faut le comprendre avant de fusionner,
pas l'écraser.

**3. Correctif urgent.** Depuis `main`, jamais depuis `develop` :

```bash
git checkout main && git checkout -b fix/urgence
# … correctif …
```

Pull request vers `main`, puis **reporter dans `develop`** dans la foulée
(`git checkout develop && git merge main`). Un correctif qui ne redescend pas
revient à la prochaine mise en production : le bogue réapparaît.

## Ce que fait la CI

| Événement                    | Ce qui tourne                                              |
| ---------------------------- | ---------------------------------------------------------- |
| Pull request (toute base)    | `api-ci`, `admin-ci`, `mobile-ci`, `security-ci`            |
| Pousse sur `develop`         | les mêmes, plus la construction de l'**APK de démonstration** |
| Pousse sur `main`            | les mêmes, plus l'APK                                       |
| Chaque lundi 06:00 UTC       | `security-ci` (TruffleHog, `pnpm audit`)                    |

L'APK de démonstration se construit depuis `develop` : c'est la branche qu'on
teste au quotidien. La release `demo-latest` garde une URL de téléchargement
stable.

## Réglages GitHub à poser une fois

Ces réglages ne vivent pas dans le dépôt — ils se posent dans l'interface, et
ce sont eux qui rendent la règle effective plutôt qu'indicative.

**Branche par défaut → `develop`** (_Settings → General → Default branch_).
Les pull requests visent alors `develop` sans avoir à le choisir à chaque fois,
et un clone tombe sur la branche de travail.

**Protection de `main`** (_Settings → Branches → Add rule_, motif `main`) :

- exiger une pull request avant fusion ;
- exiger que les contrôles `api-ci`, `admin-ci`, `mobile-ci`, `security-ci`
  passent ;
- exiger que la branche soit à jour avant fusion ;
- interdire la pousse forcée et la suppression.

**Protection de `develop`** : les mêmes contrôles obligatoires, mais sans
exiger de pull request — le travail quotidien doit rester fluide.

**Suppression automatique des branches fusionnées**
(_Settings → General → Automatically delete head branches_) : sans elle, les
branches de fonctionnalité s'accumulent et on ne sait plus lesquelles sont
vivantes.

## Versions

Les tags suivent le [versionnage sémantique](https://semver.org/lang/fr/) :
`vMAJEUR.MINEUR.CORRECTIF`. Seule `main` porte des tags — un tag sur `develop`
désignerait quelque chose qui n'a jamais été déployé.

## Messages de commit

[Conventional Commits](https://www.conventionalcommits.org/fr/) :
`feat(mobile): …`, `fix(api): …`, `docs: …`, `chore: …`. Le corps du message
explique **pourquoi**, pas **quoi** — le diff dit déjà quoi.
