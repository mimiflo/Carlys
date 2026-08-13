# Icône de lanceur Carlys

Déclinaisons de l'icône d'application, générées depuis le sceau de la marque
(`assets/brand/carlys-mark.png`) sur le fond sombre de l'application
(`#08050E`, `AppColors.darkBackground`) :

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
