# `infrastructure/minio/` — MinIO et `mc`, construits depuis leurs sources

Carlys ne tire plus **aucune** image MinIO tierce. Le serveur de stockage objet
(`minio`) et son client (`mc`) sont construits ici, depuis leurs dépôts
officiels, à un tag **et** un commit épinglés, puis servis à la CI, au
développement et au serveur.

## Pourquoi

| Date | Ce qui est tombé |
| --- | --- |
| octobre 2025 | MinIO cesse de distribuer son édition communautaire (images, puis binaires : `dl.min.io` rend 410) |
| 12 septembre 2026 | `minio/minio` et `minio/mc` ont **disparu de Docker Hub** — api-ci rouge sur « pull access denied ». Repli sur `quay.io`, épinglé par empreinte |
| 24 septembre 2026 | `quay.io` cesse de servir les **mêmes** images : « unauthorized: access to the requested resource is not authorized », en une seconde, sur des commits qui ne touchaient pas l'API. api-ci rouge ; tout nouveau déploiement ou nouveau poste aurait échoué de même |

Deux registres tiers, deux pannes : épingler une empreinte protège contre une
image **modifiée**, pas contre une image **retirée**. Les sources, elles,
restent publiques — [github.com/minio/minio](https://github.com/minio/minio)
et [github.com/minio/mc](https://github.com/minio/mc).

## Licence : GNU AGPLv3

`minio` et `mc` sont publiés sous **GNU Affero General Public License v3** (ou
toute version ultérieure). Ce que cela implique ici :

- **Carlys les exécute sans modification**, comme des programmes séparés :
  l'API leur parle en S3, par le réseau, sans rien lier de leur code. Le code
  de Carlys n'en devient pas une œuvre dérivée.
- **Les images publiées sont une distribution** (le registre GHCR). Chacune
  embarque `/licenses/<composant>/` : `LICENSE`, `CREDITS` et `SOURCE` — dépôt,
  tag, commit et version de Go. La source correspondante est ainsi désignée
  au commit près, et elle est publique.
- **Ne jamais patcher ces sources sans publier le correctif.** MinIO est joint
  par les utilisateurs de l'application (`media.<domaine>`) : une version
  modifiée tomberait sous l'article 13 de l'AGPL (source offerte aux
  utilisateurs du réseau). `construire.sh` ne sait d'ailleurs construire que
  le commit épinglé, tel quel.

Ceci résume la licence pour l'exploitation ; ce n'est pas un avis juridique.

## Les fichiers

| Fichier | Rôle |
| --- | --- |
| `versions.env` | **Le seul endroit** où s'écrivent les tags, les commits et la version de Go |
| `construire.sh` | Clone le tag, **refuse** si le commit diffère, construit (`CGO_ENABLED=0 go build -trimpath`, options officielles), vérifie que `--version` annonce ce tag et ce commit ; calcule aussi les étiquettes des images (`etiquettes`) et vérifie que le compose du serveur les référence (`verifier-compose`) |
| `Dockerfile` | Deux cibles : `mc` (client + `/bin/sh`) et `minio` (serveur **+ mc**, pour la sonde `mc ready local`). Images de base épinglées par empreinte |

## Ce que la construction tire

Aucune image MinIO, d'aucun registre. Mais la construction n'est pas pour
autant hors ligne, et un poste neuf a besoin de :

| Source | Pour quoi | Qui en a besoin |
| --- | --- | --- |
| Docker Hub | les images **officielles** `golang` (étage de construction) et `alpine` (image finale), épinglées par empreinte dans le `Dockerfile` | le `Dockerfile` : développement (`docker compose`), images-ci, images-publish |
| github.com | les sources de `minio` et `mc`, au tag épinglé | tous |
| proxy.golang.org | les modules Go (~1,2 Go pour `minio`, à froid) | tous |

api-ci ne passe pas par le `Dockerfile` : il tire Go par `actions/setup-go`
et appelle `construire.sh` directement, donc sans Docker Hub. Un poste sans
accès à Docker Hub, ou limité en débit par lui, peut faire de même
(« Construire et éprouver sur un poste », plus bas) ; `docker compose up`
ne construira pas MinIO sans lui.

## Qui s'en sert

| Consommateur | Comment |
| --- | --- |
| `api-ci.yml` | `construire.sh` en binaires nus, mis en cache (clé : tags, Go, empreinte de la recette) ; `minio server` en arrière-plan, puis les deux buckets — e2e sur le vrai stockage |
| `images-ci.yml`, job `minio` | construit les deux cibles, vérifie leur identité, démarre le serveur, rejoue la sonde de santé et la configuration de `minio-init` (codes HTTP 200 / 403 attendus) |
| `images-publish.yml` | publie `ghcr.io/<propriétaire>/carlys-minio` et `carlys-mc`, **une seule fois par recette**, et **avant** les images de l'application du même commit (voir « Ordre de publication ») |
| `docker-compose.yml` (développement) | `build:` sur ce dossier — aucune image MinIO tierce ; seules les images officielles `golang` et `alpine`, épinglées par empreinte, viennent de Docker Hub (voir « Ce que la construction tire ») |
| `infrastructure/server/compose.yml` | tire les images publiées ; valeurs par défaut de `CARLYS_MINIO_IMAGE` et `CARLYS_MC_IMAGE` |
| `scripts/server/backup.sh` | `mc mirror` dans le conteneur `minio-init` (image `carlys-mc`) |

## Étiquettes des images publiées

`<version de l'amont>-<empreinte de la recette>`, par exemple
`carlys-minio:RELEASE.2025-09-07T16-13-09Z-<12 caractères hexadécimaux>`.
L'empreinte est le SHA-256 de `Dockerfile`, `versions.env` et
`construire.sh`, dans cet ordre :

```bash
sh infrastructure/minio/construire.sh etiquettes
```

**Pourquoi pas `sha-<commit>` comme l'API et l'admin.** Ces deux images suivent
leur recette, pas le code de l'application. Une étiquette par commit aurait
trois défauts, tous vécus sur le serveur : un retour arrière vers un sha
antérieur à ce dossier ne trouverait pas son image MinIO ; chaque déploiement
recréerait le conteneur MinIO — coupure des médias — dès que deux
constructions différeraient d'un octet ; et l'élagage des images `sha-…`
emporterait celle qui tourne.

**Immuables.** `images-publish` ne repousse jamais une étiquette existante :
même recette, même étiquette, rien à refaire. Une poussée sur la branche de
travail ne peut donc pas remplacer en douce l'image que la production tire.

**Ordre de publication.** Dans `images-publish`, les images MinIO passent
**avant** les trois images de l'application, puis une étape vérifie que les
images que `infrastructure/server/compose.yml` tire **existent** dans le
registre ; si non, l'exécution échoue avant de pousser la moindre image de
l'application. D'où l'invariant : un commit qui a ses images `sha-…` a aussi
les images MinIO de son compose. C'est ce que suppose la mise à jour
automatique de la recette (`scripts/server/_update.sh`), qui ne regarde que
les trois images de l'application : publiées après elles, les images d'une
recette nouvelle auraient manqué quelques minutes (près de 3 min de
compilation à froid), `deploy.sh` aurait échoué à son étape 2 et le sha
aurait été mis de côté pour de bon. L'exploitant n'a aucun ordre à respecter.

## Utilisateur : root, délibérément

Comme l'image `quay.io` remplacée. Le volume `minio-data` des serveurs en
service a été rempli par elle, donc par root : un utilisateur non privilégié
n'y écrirait plus, et MinIO refuserait de démarrer sur des médias bien réels.
`backup.sh` fait aussi écrire `mc mirror` dans un répertoire de l'hôte en mode
700, propriété de root. Passer en non-root reste possible, mais c'est un
chantier à part : `chown` du volume sur chaque serveur et répertoire de
sauvegarde accessible — pas l'effet de bord d'un changement de registre.

## Monter de version

1. **Relever le commit du nouveau tag** — la ligne `^{}`, les tags de MinIO
   étant annotés :

   ```bash
   git ls-remote https://github.com/minio/minio 'refs/tags/RELEASE.<…>Z^{}'
   git ls-remote https://github.com/minio/mc    'refs/tags/RELEASE.<…>Z^{}'
   ```

2. **Écrire tag et commit dans `versions.env`**, et nulle part ailleurs. Si le
   `go.mod` du nouveau tag exige un Go plus récent : changer aussi
   `CARLYS_MINIO_GO_VERSION` **et** la ligne `FROM golang:` du `Dockerfile`
   (tag et empreinte). `construire.sh` refuse de construire si les deux
   divergent.
3. **Construire en local** (Go de la version exacte, voir plus bas) :

   ```bash
   sh infrastructure/minio/construire.sh minio /tmp/minio-bin
   sh infrastructure/minio/construire.sh mc    /tmp/minio-bin
   ```

4. **Reporter les nouvelles étiquettes** dans `infrastructure/server/compose.yml`
   (valeurs par défaut de `CARLYS_MINIO_IMAGE` et `CARLYS_MC_IMAGE`). La
   commande suivante dit exactement quoi écrire, et images-ci la rejoue :

   ```bash
   sh infrastructure/minio/construire.sh verifier-compose infrastructure/server/compose.yml
   ```

5. **Développement** : `docker compose build minio minio-init && docker compose up -d`
   (Compose ne reconstruit pas tout seul une image qui existe déjà).
6. **Pousser.** api-ci reconstruit les binaires (cache manqué) et rejoue les
   e2e de stockage dessus ; images-ci construit et éprouve les images ;
   images-publish publie les nouvelles étiquettes, **avant** les images de
   l'application de ce commit. Le serveur les tire au déploiement suivant
   (`deploy.sh`, étape 2) et recrée le conteneur MinIO sur le **même**
   volume.
7. **Sur le serveur, sauvegarder AVANT** (`scripts/server/backup.sh`) : MinIO
   migre son format de données vers l'avant, un retour à une version
   antérieure n'est pas garanti.

Le même geste vaut pour changer d'image de base ou de Go sans changer de
version de MinIO : toute modification de la recette change l'étiquette.

## Construire et éprouver sur un poste

```bash
# Le Go EXACT de versions.env (construire.sh refuse tout autre) :
GOTOOLCHAIN=go1.24.13 go env GOROOT     # télécharge la chaîne depuis proxy.golang.org
export PATH="$(GOTOOLCHAIN=go1.24.13 go env GOROOT)/bin:$PATH"

sh infrastructure/minio/construire.sh minio /tmp/minio-bin
sh infrastructure/minio/construire.sh mc    /tmp/minio-bin

# Le MinIO de la CI, sur le port 9000, avec ses identifiants (factices, publics) :
MINIO_ROOT_USER=carlys-ci MINIO_ROOT_PASSWORD=carlys-ci-secret \
  /tmp/minio-bin/minio server /tmp/minio-data --address 127.0.0.1:9000 &
/tmp/minio-bin/mc alias set ci http://localhost:9000 carlys-ci carlys-ci-secret
/tmp/minio-bin/mc mb --ignore-existing ci/carlys-media
/tmp/minio-bin/mc anonymous set download ci/carlys-media
/tmp/minio-bin/mc mb --ignore-existing ci/carlys-private
/tmp/minio-bin/mc anonymous set none ci/carlys-private
```

Mesuré le 25 septembre 2026, sur 4 cœurs, caches Go vides : **2 min 04 s**
pour `minio` (dont le téléchargement de ~1,2 Go de modules), **16 s** pour
`mc`. Contre ce MinIO — plus PostgreSQL et Redis locaux, et les variables
`env:` du job d'api-ci exportées (`DATABASE_URL`, `REDIS_URL`,
`JWT_ACCESS_SECRET`, `S3_*`) —, les suites e2e qui ne tournaient jusque-là
qu'en CI passent depuis `apps/api` (3 suites, 29 tests) :

```bash
npx jest --config ./test/jest-e2e.json --selectProjects e2e \
  --testPathPatterns 'media|nutrition-photos'
```

## Go 1.24

La ligne qu'exige le `go.mod` de `minio` (`go 1.24.0`), à son dernier
correctif (1.24.13). Cette ligne n'est plus maintenue depuis la sortie de
Go 1.26 : passer à un Go plus récent est possible (le `go.mod` fixe un
minimum, pas un maximum), mais ce serait construire avec une chaîne que
l'amont n'a pas éprouvée pour ce tag. C'est une décision à prendre
délibérément — étape 2 ci-dessus — pas un réglage par défaut.
