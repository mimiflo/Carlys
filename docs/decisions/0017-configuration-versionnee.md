# ADR 0017 — La configuration du serveur versionnée, le `.env` réduit aux secrets

## Statut

Acceptée — 2026-10-04, à la demande du propriétaire (« ne plus avoir tout
ce qui est config dans le env, juste les mots de passe et choses secrètes ;
un vrai fichier config pour le projet, bien structuré »).

## Contexte

Le `.env` de chaque environnement (`/srv/carlys/<env>/.env`) portait tout à
la fois : une vingtaine de secrets, une centaine de réglages (ports, plafonds
mémoire, coach, abonnements, URL publiques) et deux valeurs d'ÉTAT réécrites
par les scripts (`CARLYS_TAG`, `CARLYS_API_REPLICAS`). Trois conséquences,
toutes vécues :

- un réglage oublié ne se voyait qu'en panne : le scan d'assiette a répondu
  « erreur interne » parce que `COACH_VISION_MODEL` manquait au `.env` de la
  recette, commenté dans le gabarit (4 octobre 2026) ;
- changer un réglage demandait d'éditer un fichier de secrets sur le
  serveur, à la main, sans historique ni relecture ;
- recette et production dérivaient sans que rien ne le dise.

## Décision

1. **Les réglages vivent dans le dépôt**, sous
   `infrastructure/server/config/` :
   - `commun.conf` : ce qui vaut pour les deux environnements ;
   - `staging.conf`, `production.conf` : ce qui les distingue, et seulement
     cela (un réglage est dans `commun.conf` OU dans un fichier
     d'environnement, jamais les deux).

   Rangés par sections commentées (pile, base de données, API, coach,
   stockage, e-mail…), relus et versionnés comme le code.
2. **Le format reste `CLE=valeur`**, celui que Compose lit nativement
   (`--env-file`, `env_file:`) et que `env_value` lit sans l'exécuter. Un
   YAML ou un TOML aurait demandé un lecteur sur le serveur (ni Python ni
   Node n'y sont garantis hors des conteneurs) et une étape de conversion
   avant chaque `docker compose` : une pièce de plus qui peut casser un
   déploiement, pour une structure que des sections donnent déjà.
3. **L'état va dans `/srv/carlys/<env>/etat.env`**, écrit par `carlysctl`
   seul (version déployée, nombre d'exemplaires). Ni secret ni réglage : il
   ne se versionne pas.
4. **Le `.env` ne garde que les secrets** : mots de passe, clés, jetons, et
   les adresses qui en contiennent un (`DATABASE_URL`, les clés S3 qui
   reprennent celles de MinIO).
5. **Ordre de chargement**, du moins au plus prioritaire : `commun.conf`,
   `<env>.conf`, `etat.env`, `.env`. Le même pour Compose (une suite de
   `--env-file`, et la liste `env_file:` de l'API) et pour les scripts
   (`env_value` lit les couches d'un `.env` d'environnement, la dernière
   valeur l'emporte).

   Le `.env` passe EN DERNIER pour une raison : la migration ne change
   aucune valeur en service. Tant qu'un ancien réglage y reste, c'est lui
   qui joue, exactement comme avant. Contrepartie acceptée : un réglage
   remis à la main dans le `.env` masquerait la configuration versionnée ;
   `carlysctl doctor` le signale.

   Compose ne résout une référence `${…}` que vers un fichier DÉJÀ chargé
   (mesuré : une `DATABASE_URL` posée dans `commun.conf` ne voit pas le mot
   de passe du `.env`). C'est pourquoi les adresses qui portent un secret
   restent dans le `.env`, après ce qu'elles citent.
6. **La configuration est FIGÉE au déploiement**, pas lue dans le clone.
   La supervision avance le clone seule, dès qu'une CI est verte : lue là,
   une configuration poussée toucherait la production à la passe suivante,
   sans passer par la recette, et un retour arrière ne la ramènerait pas
   (relevé par la relecture du 4 octobre 2026). `deploy.sh` lit donc
   `commun.conf` et `<env>.conf` DANS LE COMMIT déployé (`git show
   <sha>:…`) et les copie dans `/srv/carlys/<env>/config/` ; `dc`,
   `env_value` et l'API ne lisent que cette copie. Une bascule ratée et le
   retour arrière remettent la précédente. Un commit que le clone ignore, ou
   antérieur à cet ADR, garde la configuration en service (avertissement,
   pas de blocage : le retour vers un ancien sha doit rester possible).
   Avant le premier déploiement qui la fige, c'est celle du clone.
7. **Migration : `carlysctl config-migrer <env>`.** À blanc, elle range
   chaque ligne du `.env` : secret (reste), état (part dans `etat.env`),
   réglage IDENTIQUE à la configuration versionnée (part), réglage
   DIFFÉRENT (reste, valeur du serveur et du dépôt affichées : ce ne sont
   pas des secrets), réglage inconnu du dépôt (reste, signalé, valeur
   jamais affichée : il peut être un secret mal rangé). Avec
   `--appliquer`, elle sauvegarde le `.env` (600), retire les réglages
   identiques et déplace l'état — puis compare l'EMPREINTE de la pile rendue
   par Compose avant et après : une seule différence (un `${…}` qui se
   résoudrait autrement), et tout est remis. Un réglage différent ne part
   jamais seul : on reporte d'abord sa valeur réelle dans le dépôt, puis on
   relance. Sans gabarit de secrets lisible, elle refuse de classer.

## Conséquences

- Changer un réglage = un commit, puis un déploiement — en recette d'abord,
  la production le reçoit en promouvant le même sha. Le propriétaire n'a
  plus à éditer de fichier sur le serveur, sauf pour un secret.
- Les gabarits `staging.env.example` et `production.env.example` ne portent
  plus que des secrets ; `env-sync` n'ajoute donc plus que des secrets.
- `docker compose` tapé à la main ne voit plus la configuration : passer par
  `carlysctl compose <env> …`, qui charge les couches dans l'ordre.
- La CI (compose_test, rejoué par infra-ci dès que config/, les gabarits ou
  le schéma de l'API changent) vérifie : format strict `CLE=valeur`, aucun
  secret (par le gabarit, par le nom, par l'allure de la valeur), aucune clé
  en double, et chaque variable du schéma de l'API portée par la
  configuration ou par le gabarit de secrets. `doctor` refait la garde des
  secrets sur le serveur.
