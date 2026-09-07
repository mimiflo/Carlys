import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_source.dart';

/// LE DESIGN SYSTEM EST OBLIGATOIRE, et c'est un test qui le dit.
///
/// CLAUDE.md l'écrit depuis toujours : aucune valeur visuelle en dur dans un
/// écran. La règle n'était pourtant gardée par personne, et neuf couleurs
/// brutes s'étaient posées dans `lib/features/` — un `Color(0x…)` recopié à
/// la main dérive du jeton qu'il imite, et personne ne le voit dériver. La
/// dette a été remboursée ; ce fichier interdit qu'elle revienne, comme
/// `editorial_tone_test.dart` le fait pour la ligne éditoriale.
///
/// Le balayage porte sur `lib/features/**` — les écrans — et sur le CODE,
/// commentaires et chaînes retirés : une couleur citée en commentaire
/// décrit, elle ne peint pas. `lib/design_system/` en est exclu par nature :
/// c'est l'unique endroit où une couleur a le droit d'être écrite, puisque
/// c'est l'endroit qui la nomme.
void main() {
  test('aucun écran ne pose de couleur brute', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDesEcrans()) {
      final code = dartCode(File(fichier).readAsStringSync());
      for (final faute in motifDeCouleurBrute.allMatches(code)) {
        // La ligne se compte sur le code MASQUÉ, qui garde la géométrie du
        // fichier : la citation renvoie donc à la bonne ligne.
        final ligne =
            '\n'.allMatches(code.substring(0, faute.start)).length + 1;
        fautes.add('$fichier:$ligne : « ${faute[0]} »');
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Une couleur d’écran vient du design system, jamais du fichier qui '
          's’en sert : ajoute le jeton dans `packages/design-tokens`, puis '
          'dans `AppColors`, et nomme-le ici :\n${fautes.join('\n')}',
    );
  });

  // Une règle qui ne dit pas non n'est pas une règle, et une règle qui dit
  // non à tout n'en est pas une non plus : les deux sens sont éprouvés.
  group('la règle des couleurs brutes', () {
    test('reconnaît les façons d’écrire une couleur à la main', () {
      expect(couleursBrutes('color: Color(0xFF9B30FF),'), ['Color(0xFF9B30FF']);
      expect(couleursBrutes('const Color.fromARGB(255, 155, 48, 255)'), [
        'Color.fromARGB',
      ]);
      expect(couleursBrutes('const Color.fromRGBO(155, 48, 255, 1)'), [
        'Color.fromRGBO',
      ]);
      expect(couleursBrutes('color: Colors.red,'), ['Colors.red']);
      // Le formateur peut couper l'appel : la parenthèse et le « 0x » ne
      // sont pas toujours collés, et la faute traverse alors deux lignes.
      expect(couleursBrutes('color: Color(\n  0xFF9B30FF,\n),'), [
        'Color(\n  0xFF9B30FF',
      ]);
    });

    test('laisse passer le design system et la seule couleur nue permise', () {
      expect(couleursBrutes('color: AppColors.primary,'), isEmpty);
      expect(
        couleursBrutes('AppColors.primary.withValues(alpha: 0.2)'),
        isEmpty,
      );
      // `Colors.transparent` n'est pas une couleur : c'est l'absence de
      // couleur, et le design system ne nomme pas le vide.
      expect(couleursBrutes('color: Colors.transparent,'), isEmpty);
      // Une variable dont le nom finit par « Color » n'est pas un
      // constructeur.
      expect(couleursBrutes('final Color tint = AppColors.accent;'), isEmpty);
      expect(couleursBrutes('tint.withValues(alpha: 0.5)'), isEmpty);
    });

    test('n’acquitte que le mot exact « transparent »', () {
      expect(couleursBrutes('Colors.transparentish'), [
        'Colors.transparentish',
      ]);
    });
  });
}

/// Les écrans : tout `lib/features/`, code engendré exclu.
Iterable<String> _fichiersDesEcrans() sync* {
  for (final entity in Directory('lib/features').listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.endsWith('.g.dart')) {
      yield entity.path;
    }
  }
}

/// Une couleur écrite à la main, dans du CODE.
///
/// Trois formes, ce sont celles que le dépôt avait laissées entrer :
/// `Color(0x…)`, `Color.fromARGB(…)` et `Colors.<nom>`. La quatrième,
/// `Color.fromRGBO`, est le même constructeur sous un autre nom : la fermer
/// aussi coûte un mot.
///
/// `Colors.transparent` est la SEULE exception, et elle est mesurée : cinq
/// fichiers de `lib/features/` l'emploient — quatre `Material` rendus
/// invisibles sous un `InkWell`, et une extrémité de dégradé. Le design
/// system nomme des couleurs ; il n'a pas à nommer leur absence.
final RegExp motifDeCouleurBrute = RegExp(
  r'Color\(\s*0x[0-9A-Fa-f]+'
  r'|Color\.fromARGB'
  r'|Color\.fromRGBO'
  r'|(?<![A-Za-z_$])Colors\.(?!transparent(?![A-Za-z]))[A-Za-z]+',
);

/// Les couleurs brutes d'un fragment de code, dans l'ordre.
Iterable<String> couleursBrutes(String code) =>
    motifDeCouleurBrute.allMatches(code).map((faute) => faute[0]!);
