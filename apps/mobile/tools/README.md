# Outils du projet mobile

Rien ici n'est embarqué dans l'application : `pubspec.yaml` ne déclare comme
assets que `assets/**`, jamais `tools/**`.

## `fonts-source/` — les polices COMPLÈTES

Les neuf TTF livrés dans `assets/fonts/` sont **sous-ensemblés** : Flutter ne
le fait pas lui-même pour les polices de texte (seul `--tree-shake-icons`
agit, et uniquement sur les polices d'icônes), et les versions complètes
emportaient 2 993 988 octets dans l'APK et l'IPA — dont du cyrillique, du grec
et du vietnamien, pour une application dont `app.dart` déclare
`supportedLocales: [Locale('fr')]`.

Les originaux restent ici pour que le sous-ensemblage soit **refaisable** :
élargir les plages de `subset_fonts.py` et relancer suffit, sans rien
retélécharger. Les textes de licence (SIL OFL 1.1) les accompagnent.

Licence : les trois familles sont sous OFL **sans nom réservé** — aucun « with
Reserved Font Name » dans leurs en-têtes de copyright — donc le
sous-ensemblage est permis et le nom de famille peut être conservé.

## `subset_fonts.py` — refaire le sous-ensemble

```bash
cd apps/mobile
pip install fonttools      # une fois
python3 tools/subset_fonts.py
```

Le garde-fou, lui, n'a AUCUNE dépendance et tourne en CI :

```bash
python3 scripts/check_mobile_fonts.py    # depuis la racine du dépôt
```

Il lit la table `cmap` à la main et refuse qu'un sous-ensemble ait perdu un
caractère que l'original portait et que le code emploie. C'est nécessaire
parce qu'un glyphe manquant ne se voit pas : Flutter retombe sur la police
système, et seule la forme des lettres change.
