# Icône de lanceur Carlys

Déclinaisons de l'icône d'application, générées depuis le sceau de la marque
(`assets/brand/carlys-mark.png`) sur le fond sombre de l'application
(`#08050E`, `AppColors.darkBackground`).

Le sceau est rendu en **gris anthracite** (demande produit) : luminance du
sceau d'origine conservée — le modelé et les reflets restent — puis remappée
sur une rampe graphite (ombres `#171B20`, corps `#4A525B`, reflets `#C6CDD4`,
autocontraste masqué sur la zone opaque). Pour revenir au sceau coloré, il
suffit de régénérer les PNG sans ce remappage.

Contenu :

- `res/mipmap-anydpi-v26/ic_launcher.xml` — icône **adaptative** (API 26+) :
  fond couleur + sceau en premier plan, dans la zone sûre ;
- `res/mipmap-*/ic_launcher_foreground.png` — premiers plans adaptatifs
  (108 dp, densités m/h/x/xx/xxx) ;
- `res/mipmap-*/ic_launcher.png` — icône **héritée** (avant API 26), fond
  sombre plein.

`android/` n'étant pas versionné, ces fichiers sont copiés dans
`android/app/src/main/res/` par `scripts/android_branding.sh` (appelé par
`scripts/bootstrap_mobile.sh` et la CI `demo-apk`), qui règle aussi le nom
affiché (« Carlys ») et la permission de notification.
