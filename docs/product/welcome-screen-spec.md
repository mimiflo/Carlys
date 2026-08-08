<!-- Spécification livrée par Claude Design avec le paquet de handoff de
     l'écran de bienvenue. Recopiée ici VERBATIM : les assets et le HTML de
     référence ne sont pas versionnés (comme le reste des handoffs), mais les
     valeurs, elles, doivent survivre au dossier de livraison.

     En cas de doute sur un chiffre, c'est ce fichier qui fait foi.
     Les écarts de traduction CSS → Flutter sont notés dans design-conformity.md. -->

# Carlys — Welcome screen · spec d'implémentation Flutter

Cible : `apps/mobile/lib/features/onboarding/presentation/screens/welcome_screen.dart`
Référence visuelle : `Welcome.dc.html` (design validé). Reproduire **exactement** les valeurs ci-dessous.

## 0. Assets à ajouter

| Fichier | Usage |
| --- | --- |
| `assets/images/carlys_mark.png` | Logo (papillon/monogramme), fond transparent, détouré au plus juste |
| `assets/images/carlys_athlete.png` | Photo athlète (dos avec logo Carlys) |

Déclarer dans `pubspec.yaml` sous `flutter: assets:`.

## 1. Tokens utilisés

```
background     #06060C   (fond global)
surface        #101019   (cartes univers)
border         rgba(255,255,255,0.07)  → Color(0x12FFFFFF)
textPrimary    #FFFFFF
textSecondary  #9A9AAE
textTertiary   #7A7A8C
violet         #7B4BF6
magenta        #CD2EDA
rose           #F7708F
indigoGlow     #5B5BF6
gradientBrand  LinearGradient(begin: centerLeft, end: centerRight,
                 colors: [#7B4BF6, #CD2EDA, #F7708F], stops: [0, .5, 1])
```

Typo : **Inter** (300/600/700) + **JetBrains Mono** (500) pour les micro-labels.
Icônes : Material Symbols Rounded — `smartphone`, `school`, `emoji_events`, `checkroom`, taille 26, couleur `#9A9AAE`.

## 2. Structure (Stack plein écran, `SafeArea` en bas uniquement)

Ordre des couches, de l'arrière vers l'avant :

1. **Fond** `Container(color: #06060C)`
2. **Halo marque (haut-droite)** — ellipse floutée
   `Positioned(top: -6%h, right: -14%w, width: 86%w, height: 82%h)`
   `RadialGradient(center: Alignment.center, colors: [#CD2EDA@20%, #7B4BF6@12%, transparent], stops: [0, .46, .78])`
   + `ImageFiltered(blur sigma 14)`
3. **Photo athlète**
   `Positioned(top:0, right:0, width: 62%w, height: 100%h)`
   - `Image.asset(fit: BoxFit.cover, alignment: Alignment(-0.56, -1.0))` ← équivaut à `object-position: 22% top`
   - `brightness(0.9)` : `ColorFiltered(ColorFilter.mode(Color(0x1A000000), BlendMode.darken))` ou `ColorFilter.matrix` scale 0.9
   - **Fondu du bord gauche** : `ShaderMask(blendMode: BlendMode.dstIn)` avec
     `LinearGradient(centerLeft→centerRight, colors: [transparent, white], stops: [0, .30])`
   - Lueur : trois `BoxShadow`/glow — `#F7708F@28% blur 18`, `#CD2EDA@24% blur 46`, `#7B4BF6@20% blur 96`
4. **Voile horizontal** `LinearGradient(left→right, [#06060C, #06060C@78%, transparent], stops:[0,.34,.66])`
5. **Voile bas** `LinearGradient(top→bottom, [transparent, #06060C@60%, #06060C], stops:[.62,.86,1])`
6. **Halo indigo derrière le texte**
   `Positioned(left: -18%w, top: 2%h, width: 78%w, height: 62%h)`
   `RadialGradient([#5B5BF6@20%, #5B5BF6@7%, transparent], stops:[0,.52,.80])` + blur 18
7. **Plaque sombre sous le texte**
   `Positioned(left:0, top:0, width: 82%w, height: 100%h)`
   `RadialGradient(center: Alignment(-0.56, -0.12), radius ≈ 0.78w/0.46h, colors:[#000@92%, #030308@78%, #06060C@42%, transparent], stops:[0,.42,.72,1])`
8. **Contenu** (voir §3)

## 3. Contenu — `Column(mainAxisAlignment: spaceBetween)`

Padding : `EdgeInsets.fromLTRB(22, 16, 22, 16 + safeAreaBottom)`.

### Bloc haut — largeur **64%** de l'écran, `crossAxisAlignment: start`

Ombre commune à tout le bloc texte : `[Shadow(color: #06060C@85%, offset (0,2), blur 18), Shadow(color: #06060C@60%, offset (0,1), blur 3)]`

| Élément | Spécification | Espace après |
| --- | --- | --- |
| Logo | `Image.asset(carlys_mark, height: 120, fit: contain)` + glow `#CD2EDA@35% blur 26` | 12 |
| `CARLYS` | Inter 40 / w300 / letterSpacing **10** / #FFFFFF / height 1.0 | 12 |
| `L'ART DE DEVENIR` | Inter 13 / w600 / letterSpacing **5** / #9A9AAE | 24 |
| **Slogan 3D** | voir §4 | 16 |
| 3 phrases | Inter 14 / height **1.75** / #9A9AAE — les mots `TON`/`TON`/`TA` en w700 #FFFFFF | 40 |
| Motif barres | voir §5 | — |

Texte des 3 phrases :
```
Ton corps est TON œuvre.
Ton parcours est TON histoire.
Ta discipline est TA signature.
```

### Bloc bas — `Column(gap 16)`

**a) Grille 4 univers** — `Row` de 4 `Expanded`, gap 8

Carte : `padding EdgeInsets.symmetric(vertical: 12, horizontal: 4)`, `color #101019`,
`border: 1px #12FFFFFF`, `borderRadius: 20`, contenu centré :
icône (26, #9A9AAE) → gap 8 → `CARLYS` (Mono 9 / w500 / ls 1.2 / #7A7A8C) → gap 2 → libellé (Mono 9 / w500 / ls 1.2 / #9A9AAE)

| Icône | Libellé |
| --- | --- |
| `smartphone` | APP |
| `school` | ACADEMY |
| `emoji_events` | EVENTS |
| `checkroom` | WEAR |

**b) Bouton principal**
`height 58`, `borderRadius 999`, `gradientBrand`, texte `COMMENCER MON PARCOURS`
Inter 15 / w700 / letterSpacing **1.4** / #FFFFFF.
Pressed : `scale 0.985` + `brightness 1.08`, durée 160 ms.

## 4. Slogan en relief 3D

Texte (4 lignes, `<br>` explicites) :
```
SCULPTE
TON PARCOURS.
SIGNE TON
CHEF-D'ŒUVRE.   ← cette ligne en #CD2EDA
```
Style : Inter **24** / w700 / letterSpacing **-0.44** / height **1.24** / #FFFFFF.

**Extrusion** — 5 ombres pleines (blur 0) empilées + 1 ombre portée :
```dart
shadows: const [
  Shadow(color: Color(0xFF4A3A5E), offset: Offset(1, 1)),
  Shadow(color: Color(0xFF3D2F4E), offset: Offset(2, 2)),
  Shadow(color: Color(0xFF31253E), offset: Offset(3, 3)),
  Shadow(color: Color(0xFF251C2E), offset: Offset(4, 4)),
  Shadow(color: Color(0xFF1A1420), offset: Offset(5, 5)),
  Shadow(color: Color(0xD1000000), offset: Offset(6, 7), blurRadius: 13),
],
```

**Perspective** — équivalent de `perspective(700px) rotateY(-8deg) rotateX(4deg)`, origine **gauche/centre** :
```dart
Transform(
  alignment: Alignment.centerLeft,
  transform: Matrix4.identity()
    ..setEntry(3, 2, 1 / 700)
    ..rotateY(-8 * math.pi / 180)
    ..rotateX(4 * math.pi / 180),
  child: sloganText,
)
```

## 5. Motif barres (sous les 3 phrases)

`Row(gap 9)`, toutes les barres `height 4`, `borderRadius 4` :

| # | Largeur | Couleur |
| --- | --- | --- |
| 1 | 40 | gradient `#7B4BF6 → #CD2EDA` (gauche→droite) |
| 2 | 24 | `#CD2EDA` |
| 3 | 14 | `#F7708F` @ 75% |
| 4 | 8 | `#F7708F` @ 45% |
| 5 | 5 | `#9A9AAE` @ 35% |

## 6. Points de vigilance

- Le **cadrage de la photo** est la valeur la plus sensible : `Alignment(-0.56, -1.0)`. Plus négatif en X = le sujet se décale vers la droite. Le logo dans le dos de l'athlète doit rester visible et ne pas empiéter sur la colonne de texte.
- Le fondu du bord gauche de la photo (`ShaderMask`) est **indispensable** : sans lui, la découpe rectangulaire se voit.
- Aucune couche décorative ne doit intercepter les taps → toutes en `IgnorePointer`.
- Tester sur petit écran (iPhone SE / 360×640) : la colonne de texte à 64% peut nécessiter un `FittedBox` ou une réduction du slogan à 22px.
