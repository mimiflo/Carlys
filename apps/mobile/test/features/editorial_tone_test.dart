import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_source.dart';

/// LA LIGNE ÉDITORIALE, tenue par un test plutôt que par la relecture.
///
/// Deux règles, écrites dans CLAUDE.md et jusqu'ici défendues par personne :
/// l'application TUTOIE, et ses textes visibles n'emploient pas le tiret
/// cadratin — il fait « machine ». `academy_pack_test.dart` fait déjà ce
/// travail, mais pour le seul pack de leçons : les 200 écrans du dossier
/// `lib/` n'avaient aucun filet, et sept vouvoiements ainsi que six cadratins
/// de prose s'y étaient installés.
///
/// Le vouvoiement, lui, a DEUX visages, et la première version de ce fichier
/// n'en voyait qu'un. Les pronoms (« vous », « votre », « vos ») sont le
/// visage évident ; l'impératif de politesse (« Démarrez une séance ») en est
/// un autre, qui ne contient aucun de ces mots. Un « Démarrez » a donc
/// survécu à un balayage déclaré complet, sur l'écran de séance active.
/// Chaque visage a maintenant sa règle.
///
/// Le balayage porte sur les LITTÉRAUX DE CHAÎNE, commentaires retirés :
/// c'est là, et là seulement, que vit le texte affiché. Une prose de
/// commentaire ou de documentation garde donc sa liberté de ponctuation.
void main() {
  test('aucun texte affiché ne vouvoie', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDart()) {
      for (final literal in dartStringLiterals(
        File(fichier).readAsStringSync(),
      )) {
        if (vouvoie(literal.text)) {
          fautes.add('$fichier:${literal.line} : « ${literal.text} »');
        }
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Carlys tutoie. Réécris ces textes à la deuxième personne du '
          'singulier :\n${fautes.join('\n')}',
    );
  });

  test('aucun texte affiché ne donne d’ordre à la deuxième personne du '
      'pluriel', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDart()) {
      for (final literal in dartStringLiterals(
        File(fichier).readAsStringSync(),
      )) {
        for (final ordre in ordresDePolitesse(literal.text)) {
          fautes.add(
            '$fichier:${literal.line} : « $ordre » dans '
            '« ${literal.text} »',
          );
        }
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Carlys tutoie jusque dans ses ordres : « Démarre », pas '
          '« Démarrez ». Un impératif de politesse vouvoie sans employer le '
          'mot « vous » :\n${fautes.join('\n')}',
    );
  });

  test('aucun texte affiché ne porte de tiret de ponctuation', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDart()) {
      for (final literal in dartStringLiterals(
        File(fichier).readAsStringSync(),
      )) {
        final texte = literal.text;
        // SEULE exception : le cadratin SEUL, marque de valeur absente
        // (« — » dans une cellule sans donnée). Ce n'est pas de la prose,
        // c'est un glyphe de tableau, et douze écrans s'en servent.
        //
        // La comparaison est EXACTE, sans `trim()` : l'interpolation découpe
        // les chaînes, et « ${a} — ${b} » laisse le fragment «  — », qu'un
        // `trim()` acquittait — mesuré, un cadratin de prose passait ainsi
        // sous le balai.
        if (texte == '—') {
          continue;
        }
        if (texte.contains('—') ||
            texte.contains('–') ||
            texte.contains(' - ')) {
          fautes.add('$fichier:${literal.line} : « $texte »');
        }
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Les tirets de ponctuation font « machine ». Un deux-points, une '
          'virgule ou un point les remplacent :\n${fautes.join('\n')}',
    );
  });

  // Une règle qui ne dit pas non n'est pas une règle, et une règle qui dit
  // non à tout n'en est pas une non plus : les deux sens sont éprouvés.
  group('la règle du vouvoiement', () {
    test('reconnaît les pronoms de politesse', () {
      expect(vouvoie('Reprends votre séance'), isTrue);
      expect(vouvoie('Vos records'), isTrue);
      expect(vouvoie('On vous prévient'), isTrue);
    });

    test('laisse passer le tutoiement et le nom « rendez-vous »', () {
      expect(vouvoie('Reprends ta séance'), isFalse);
      expect(vouvoie('Tiens le rendez-vous, même au format court.'), isFalse);
      // Un mot n'est pas un pronom parce qu'il en contient un.
      expect(vouvoie('Trouvons mieux'), isFalse);
    });
  });

  group('la règle de l’impératif de politesse', () {
    test('reconnaît l’ordre au pluriel, même sans le mot « vous »', () {
      // Le fautif réel, celui qui a survécu au balayage des pronoms.
      expect(ordresDePolitesse('Démarrez une séance depuis l’accueil.'), [
        'Démarrez',
      ]);
      expect(ordresDePolitesse('Choisissez un exercice'), ['Choisissez']);
      expect(ordresDePolitesse('Renseignez ton poids, puis validez'), [
        'Renseignez',
        'validez',
      ]);
    });

    test('acquitte le tutoiement et les mots en « -ez » qui n’ordonnent '
        'rien', () {
      expect(
        ordresDePolitesse('Démarre une séance depuis l’accueil.'),
        isEmpty,
      );
      // Les trois seuls mots que la règle ramasse sur `lib/` en dehors des
      // ordres — mesurés, pas devinés.
      expect(
        ordresDePolitesse('Assez pour progresser, assez peu pour récupérer.'),
        isEmpty,
      );
      expect(ordresDePolitesse('La discipline te donne rendez-vous.'), isEmpty);
      // Trop courts pour être vus : il leur faut trois lettres avant « ez ».
      expect(ordresDePolitesse('Chez toi, le nez au vent'), isEmpty);
    });

    test('ne confond pas un « rendez » nu avec le nom « rendez-vous »', () {
      // L'exemption ne porte QUE sur le mot composé : l'ordre reste vu.
      expect(ordresDePolitesse('Rendez-moi mes séances'), ['Rendez']);
    });
  });
}

/// Tous les fichiers Dart écrits à la main sous `lib/`.
Iterable<String> _fichiersDart() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        // Le code engendré (Drift) n'est pas de notre plume.
        !entity.path.endsWith('.g.dart')) {
      yield entity.path;
    }
  }
}

/// Le texte, débarrassé de ce qui ressemble à du vouvoiement sans en être.
///
/// « rendez-vous » est un NOM, pas une politesse : trois citations du jour et
/// une valeur de marque l'emploient à bon droit. Le retrait vaut pour les
/// DEUX règles — le mot porte à la fois un « vous » et un « rendez ».
String _prose(String texte) =>
    texte.replaceAll(RegExp('rendez-vous', caseSensitive: false), '');

/// Le texte vouvoie-t-il par ses PRONOMS ?
bool vouvoie(String texte) => RegExp(
  r'\b(vous|votre|vos)\b',
  caseSensitive: false,
).hasMatch(_prose(texte));

/// Les ordres donnés à la deuxième personne du pluriel dans `texte`.
///
/// L'impératif pluriel se termine en « -ez », et c'est tout ce qui le
/// distingue à la lecture. La règle ramasse donc les mots en « -ez » — trois
/// lettres au moins devant, sans quoi « chez » et « nez » entreraient — puis
/// écarte le peu de mots français qui finissent ainsi sans rien ordonner.
///
/// MESURÉ sur tout `lib/` avant d'être figé : la règle y trouve TROIS mots
/// distincts — « assez » (2 fois), « rendez » (3 fois, toujours dans
/// « rendez-vous », déjà retiré par [_prose]) et l'unique vrai fautif,
/// « Démarrez ». La liste d'exemptions tient donc en un seul mot : elle
/// n'acquitte pas tout, elle acquitte ce qui est mesuré. Si elle devait
/// enfler — noms propres en « -ez », vocabulaire nouveau —, c'est la règle
/// qu'il faudrait revoir, pas la liste qu'il faudrait rallonger.
Iterable<String> ordresDePolitesse(String texte) =>
    RegExp(r'\b[A-Za-zÀ-ÿ]{3,}ez\b', caseSensitive: false)
        .allMatches(_prose(texte))
        .map((correspondance) => correspondance[0]!)
        .where((mot) => !_motsEnEzSansOrdre.contains(mot.toLowerCase()));

/// Les mots en « -ez » qui ne donnent aucun ordre. Un seul, mesuré.
const Set<String> _motsEnEzSansOrdre = {'assez'};
