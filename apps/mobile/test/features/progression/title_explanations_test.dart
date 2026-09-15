@TestOn('vm')
library;

import 'dart:io';

import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/progression_engine.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/domain/title_explanations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/explanation_catalogue.dart';

final File _catalogue = File(
  'lib/features/progression/domain/title_explanations.dart',
);

void main() {
  verifierCatalogue(
    nom: 'titres',
    source: _catalogue,
    toutes: TitleExplanations.toutes,
  );

  group('chaque palier a son sens', () {
    test('les cinq titres sont expliqués, sans exception', () {
      for (final titre in CarlysTitle.values) {
        final explication = TitleExplanations.of(titre);
        expect(
          explication.titre,
          titre.label,
          reason:
              'L’explication de ${titre.name} ne porte pas le libellé affiché '
              'à l’écran : la feuille montrerait deux noms pour un palier.',
        );
        expect(
          explication.cequeCaNeDitPas,
          isNotNull,
          reason:
              'Un titre sans limite écrite se lit comme un jugement. '
              '« ${titre.label} » n’en a pas.',
        );
      }
    });

    test('le seuil cité est celui du moteur, au point près', () {
      // Le vrai risque : quelqu'un déplace un seuil dans l'enum et laisse le
      // texte derrière. L'explication mentirait, et personne ne le verrait.
      for (final titre in CarlysTitle.values) {
        expect(
          TitleExplanations.of(titre).douCaSort,
          contains('${titre.threshold}'),
          reason:
              '« ${titre.label} » vaut ${titre.threshold} points dans '
              'CarlysTitle, mais son explication ne cite pas ce chiffre.',
        );
      }
    });

    test('le total de référence est celui du barème', () {
      // « sur 1 000 » est écrit en toutes lettres ; le nombre vient de
      // maxAxisPoints × 5. Le changer là-haut doit faire tomber ceci.
      //
      // Apprenti est EXEMPT, et volontairement : son seuil est zéro, et
      // « De 0 point sur 1 000 » situerait un départ sur une échelle dont
      // il ne dit rien. Le système, lui, la cite.
      final attendu = '$maxTotal'.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]} ',
      );
      final citent = [
        TitleExplanations.systeme,
        for (final titre in CarlysTitle.values)
          if (titre.threshold > 0) TitleExplanations.of(titre),
      ];
      expect(citent, hasLength(CarlysTitle.values.length));
      for (final explication in citent) {
        expect(
          explication.douCaSort,
          anyOf(contains(attendu), contains('$maxTotal')),
          reason:
              '« ${explication.titre} » ne situe pas son seuil sur le total '
              'réel ($maxTotal points).',
        );
      }
    });

    test('aucun palier ne se raconte sur un registre de supériorité', () {
      // « Maître » et « Icône » sont exactement les mots qui invitent au
      // classement, et Carlys ne compare personne. La garde vaut pour les
      // cinq, mais c'est pour ces deux-là qu'elle existe.
      const interdits = [
        'meilleur que',
        'mieux que les autres',
        'au-dessus des autres',
        'élite',
        'supérieur',
        'plus fort que',
        'domine',
        'classement',
        'podium',
      ];
      // Une NÉGATION dit l'inverse du registre proscrit : « il n'y a pas de
      // classement » est exactement ce qu'on veut lire. On regarde donc ce
      // qui précède le mot, pas sa seule présence.
      bool nie(String texte, int position) {
        final avant = texte.substring(
          position < 24 ? 0 : position - 24,
          position,
        );
        return avant.contains('pas ') ||
            avant.contains('aucun') ||
            avant.contains('jamais') ||
            avant.contains('ni ');
      }

      for (final explication in TitleExplanations.toutes) {
        final texte = [
          explication.cequeCest,
          explication.douCaSort,
          explication.cequeCaNeDitPas ?? '',
        ].join(' ').toLowerCase();
        for (final mot in interdits) {
          for (final trouve in mot.allMatches(texte)) {
            expect(
              nie(texte, trouve.start),
              isTrue,
              reason:
                  '« ${explication.titre} » emploie « $mot » sans le nier : '
                  '...${texte.substring(trouve.start < 40 ? 0 : trouve.start - 40, trouve.end)}',
            );
          }
        }
      }
    });
  });

  group('le sens se retrouve depuis le journal', () {
    test('chaque titre inscrit se relit depuis sa clé', () {
      for (final titre in CarlysTitle.values) {
        expect(titleOfReward('$titleRewardPrefix${titre.name}'), titre);
      }
    });

    test('une clé inconnue rend null au lieu de lever', () {
      // Un journal écrit par une version plus ancienne ne doit pas faire
      // tomber le bandeau de franchissement.
      expect(titleOfReward('titre-legende'), isNull);
      expect(titleOfReward('serie-30'), isNull);
      expect(titleOfReward(''), isNull);
    });

    test('les clés du catalogue sont bien celles que l’on relit', () {
      // La garde qui compte : le catalogue construit les identifiants, ce
      // test les relit. Si les deux divergent, une récompense obtenue
      // deviendrait illisible.
      final titresDuCatalogue = rewardCatalog
          .where((regle) => regle.reward.kind == RewardKind.titre)
          .map((regle) => titleOfReward(regle.reward.id))
          .toList();
      expect(titresDuCatalogue, isNotEmpty);
      expect(
        titresDuCatalogue,
        everyElement(isNotNull),
        reason:
            'Un titre du catalogue porte un identifiant que titleOfReward ne '
            'sait pas relire.',
      );
    });
  });

  group('les affirmations du texte tiennent devant le BARÈME', () {
    // Ces tests rejouent le moteur. Ils existent parce qu'une première
    // rédaction promettait ce que le barème n'exige pas — « les cinq axes
    // qui montent de concert » pour Maître, « des séances terminées » pour
    // Architecte — et qu'aucune relecture de texte n'attrape ça.
    ProgressionProfile profil({
      List<DateTime> jours = const [],
      int commencees = 0,
      int terminees = 0,
      double volume = 0,
      int lecons = 0,
    }) => computeProgression(
      ProgressionFacts(
        today: DateTime(2026, 9, 15),
        completedSessionDays: jours,
        startedSessions: commencees,
        completedSessions: terminees,
        recentVolumeKg: volume,
        lessonsAnswered: lecons,
        lessonsTotal: 38,
      ),
    );

    test('Architecte : vingt leçons SEULES suffisent, sans une séance', () {
      final p = profil(lecons: 20);
      expect(p.title, CarlysTitle.architecte);
      expect(
        TitleExplanations.architecte.douCaSort,
        contains('sans une séance'),
        reason:
            'Le barème donne Architecte pour vingt leçons et rien d’autre. '
            'Si ce n’est plus vrai, c’est le TEXTE qu’il faut reprendre.',
      );
    });

    test(
      'Architecte : une seule séance close le donne dès le premier jour',
      () {
        final p = profil(
          jours: [DateTime(2026, 9, 14)],
          commencees: 1,
          terminees: 1,
          volume: 4000,
        );
        expect(p.title, CarlysTitle.architecte);
        expect(
          TitleExplanations.architecte.douCaSort,
          contains('dès le premier jour'),
        );
      },
    );

    test('Maître : quatre axes pleins l’ouvrent, le cinquième EN ATTENTE', () {
      // Huit semaines de séances closes, aucune charge notée : l'axe de
      // performance reste sans fait, et le titre tombe quand même.
      final jours = [
        for (var i = 0; i < 24; i++)
          DateTime(2026, 9, 15).subtract(Duration(days: i * 2 + 1)),
      ];
      final p = profil(jours: jours, commencees: 12, terminees: 12, lecons: 20);

      expect(p.title, CarlysTitle.maitre);
      expect(
        p.pending.map((axe) => axe.value),
        contains(CarlysValue.performance),
        reason: 'L’axe de performance devait rester en attente.',
      );
      expect(
        TitleExplanations.maitre.cequeCaNeDitPas,
        contains('en attente ne l’empêche pas'),
        reason:
            'Le texte doit dire que Maître s’obtient avec un axe encore '
            'vide : c’est ce que le barème fait.',
      );
    });

    test('Icône : quatre axes pleins ne suffisent PAS', () {
      expect(
        maxAxisPoints * 4,
        lessThan(CarlysTitle.icone.threshold),
        reason:
            'C’est ce qui distingue vraiment Icône de Maître, et le texte le '
            'dit : aucun axe ne peut y rester vide.',
      );
      expect(
        maxAxisPoints * 4,
        greaterThanOrEqualTo(CarlysTitle.maitre.threshold),
      );
      expect(maxAxisPoints * 3, lessThan(CarlysTitle.maitre.threshold));
    });

    test(
      '« plus n’est pas mieux » : au-delà de quatre séances, l’axe baisse',
      () {
        final sept = [
          for (var i = 0; i < 28; i++)
            DateTime(2026, 9, 15).subtract(Duration(days: i)),
        ];
        final quatre = [
          for (var i = 0; i < 16; i++)
            DateTime(2026, 9, 15).subtract(Duration(days: i * 7 ~/ 4)),
        ];
        int equilibre(ProgressionProfile p) => p.axes
            .firstWhere((axe) => axe.value == CarlysValue.equilibre)
            .points;

        expect(
          equilibre(profil(jours: sept, commencees: 28, terminees: 28)),
          lessThan(
            equilibre(profil(jours: quatre, commencees: 16, terminees: 16)),
          ),
          reason:
              'Sept séances par semaine doivent remplir l’axe d’équilibre MOINS '
              'que quatre : c’est la surprise que le texte annonce.',
        );
        expect(
          TitleExplanations.artisan.cequeCaNeDitPas,
          contains('au-delà de quatre séances par semaine'),
        );
      },
    );
  });
}
