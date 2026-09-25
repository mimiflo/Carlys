# La photo du plat — dépendances et permissions (mobile)

L'écran « Ajouter / Modifier ce repas » laisse joindre une photo au repas
(produit : [`docs/product/nutrition.md`](../product/nutrition.md), « La photo
du plat » ; données personnelles :
[`docs/legal/privacy.md`](../legal/privacy.md), « La photo de tes repas »).
Cette page dit ce que la fonction ajoute à l'application : deux paquets, un
port, et des permissions natives posées par le bootstrap.

## Deux paquets, deux rôles

| Paquet | Rôle | Pourquoi lui |
| --- | --- | --- |
| `image_picker` (^1.2.3) | Ouvrir l'appareil photo ou la galerie et rendre les octets | Greffon OFFICIEL de l'équipe Flutter (flutter.dev) : la porte standard des deux plateformes, rien à réécrire en natif. Il livre déjà une première réduction native à 1 600 px (`maxWidth` / `maxHeight`) : une photo de 12 Mpx n'entre jamais entière en mémoire Dart. |
| `image` (^4.10.1) | Redresser, réduire, réencoder en JPEG sans métadonnées | PUR DART, sans natif : la préparation se TESTE sur de vrais octets (`meal_photo_preparation_test.dart`), et donne le même résultat sur les deux plateformes. Dépendances transitives : `archive` (les codecs zlib / deflate dont `image` a besoin, pour le PNG) et, par `archive`, `posix` (le `chmod` des fichiers qu'`archive` extrait sur le disque : jamais appelé ici, Carlys n'extrait aucune archive). |

Écarté : un compresseur NATIF (`flutter_image_compress`). Il redresse et
compresse vite, mais derrière un greffon : la fonction qui DOIT être juste
(une photo couchée sort droite, aucune métadonnée ne part) ne se testerait
plus qu'au téléphone. Le coût du pur Dart — un décodage — se paie une fois,
dans un isolat (`Isolate.run`), sur une image déjà réduite par
`image_picker` : de l'ordre de la centaine de millisecondes, pendant
lesquelles la vignette montre un indicateur.

Les deux sont justifiés en commentaire dans `apps/mobile/pubspec.yaml`,
comme chaque dépendance du projet.

## Le port : aucun test n'appelle de greffon

```
presentation (MealEditorController.pickPhoto)
      │
      ▼
domain  MealPhotoPicker            ← le port : pick(camera | gallery) → JPEG prêt, ou null
      ▲
data    ImagePickerMealPhotoPicker ← image_picker, puis prepareMealPhoto dans un isolat
        prepareMealPhoto           ← fonction pure (paquet image)
```

- `lib/features/nutrition/domain/services/meal_photo_picker.dart` : le port ;
  `MealPhotoException` (dans `domain/entities/meal_photo.dart`) en nomme les
  échecs : accès refusé, image illisible, trop lourde, appareil photo
  indisponible.
- `lib/features/nutrition/data/services/image_picker_meal_photo_picker.dart` :
  l'implémentation, et `mealPhotoPickerProvider`, que les tests remplacent
  par `test/support/fake_meal_photo_picker.dart`.
- `lib/features/nutrition/data/services/meal_photo_preparation.dart` :
  redresser (l'orientation EXIF appliquée aux pixels), réduire à 1 600 px,
  réencoder en JPEG qualité 80 sans métadonnées, sous 5 Mio (la qualité
  baisse, puis la taille). Les bornes vivent dans `MealBounds`.
- `lib/features/nutrition/data/services/picker_copies.dart` : les copies
  que le greffon laisse sur le disque, effacées dès les octets lus. Il en
  laisse DEUX sous Android pour un choix dans la galerie
  (`image_picker_android` 0.8.13) : l'ORIGINALE, telle quelle, position GPS
  comprise, dans `cache/<uuid>/<nom>`, et la copie réduite
  `cache/scaled_<nom>`, dont il rend le chemin. Il n'efface jamais la
  première (il ne compte que sur `deleteOnExit`, qu'il sait lui-même peu
  fiable sous Android). `discardPickerCopies` efface donc la copie rendue,
  PUIS, sous Android, les dossiers d'originaux du cache : au nom d'UUID et
  ne contenant que des images, la signature exacte de ceux du greffon ;
  ceux d'une prise précédente interrompue partent avec. La prise par
  l'appareil photo efface elle-même son original, et iOS ne fait qu'une
  copie. Testé sur un vrai disque : `test/features/nutrition/picker_copies_test.dart`.

## Les permissions, posées par le bootstrap

`android/` et `ios/` ne sont pas versionnés : les permissions vivent dans
`scripts/android_branding.sh`, appelé par `scripts/bootstrap_mobile.sh` et
par la CI `mobile-recette`. Le script est rejouable : il n'ajoute rien deux
fois, et REMPLACE la valeur d'un motif iOS déjà présent.

**iOS** (`ios/Runner/Info.plist`) — sans motif, iOS ferme l'application au
premier accès, et l'App Store refuse la soumission :

| Clé | Texte |
| --- | --- |
| `NSCameraUsageDescription` | « L’appareil photo sert à scanner le code ami d’un profil Carlys et à photographier tes repas. » |
| `NSPhotoLibraryUsageDescription` | « Carlys n’envoie que la photo de repas que tu choisis : le reste de ta photothèque reste sur ton téléphone. » |

Carlys passe `requestFullMetadata: false` : le sélecteur système (PHPicker)
s'ouvre alors SANS demander l'accès à la photothèque. La clé reste exigée
par l'App Store dès que le greffon est présent.

**Android** (`android/app/src/main/AndroidManifest.xml`) :

- `<uses-feature android:name="android.hardware.camera" android:required="false"/>` :
  la caméra est utile, jamais exigée. Sans cette ligne, le Play Store
  cacherait l'application aux appareils sans caméra, qui peuvent pourtant
  choisir une photo dans la galerie.
- La permission `CAMERA` arrive par fusion du manifeste de `mobile_scanner`
  (le scan du code ami). Quand elle est déclarée, `image_picker` la DEMANDE
  à l'exécution avant d'ouvrir l'appareil photo ; un refus rend
  `camera_access_denied`, que l'écran traduit (« Carlys n'a pas accès à
  l'appareil photo… »).
- La galerie ne demande AUCUNE permission : Android 13 et plus ouvrent le
  sélecteur de photos du système, les versions précédentes un sélecteur de
  fichiers ; `image_picker` déclare lui-même, par fusion, le service qui
  installe le sélecteur récent sur les Android plus anciens.

Un poste déjà amorcé avant cette fonction relance
`./scripts/android_branding.sh` (ou `./scripts/bootstrap_mobile.sh`) pour
recevoir ces lignes.

## Limite connue

Sous forte pression mémoire, Android peut détruire l'application pendant que
l'appareil photo est ouvert ; la photo prise est alors perdue au retour
(l'écran de saisie aussi, reconstruit à neuf). `image_picker` propose
`retrieveLostData()` pour la rattraper au démarrage : ce n'est pas branché,
faute d'un écran de repas à restaurer. Il suffit de reprendre la photo.
