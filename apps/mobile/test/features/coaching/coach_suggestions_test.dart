import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les amorces de conversation.
///
/// La règle vérifiée ici est celle qui les rend honnêtes : **rien n'est codé
/// en dur**. Sans donnée, il ne reste qu'une puce générique ; avec des
/// données, chaque puce nomme quelque chose que l'utilisateur possède
/// vraiment.
/// Les phrases seules : ce que la plupart des épreuves comparent.
List<String> _texts(CoachContext context) => [
  for (final suggestion in coachSuggestions(context)) suggestion.text,
];

void main() {
  test('sans aucune donnée, une seule puce, et elle n’invente rien', () {
    final suggestions = _texts(const CoachContext());

    expect(suggestions, hasLength(1));
    // Aucun nom d'exercice, aucun modèle, aucune tendance : rien qui
    // prétende connaître un utilisateur dont on ne sait rien.
    expect(suggestions.single, isNot(contains('«')));
  });

  test(
    'un modèle disponible donne la puce la plus actionnable, en premier',
    () {
      final suggestions = _texts(
        const CoachContext(templateName: 'Push A', hasHistory: true),
      );

      expect(suggestions.first, contains('Push A'));
    },
  );

  test(
    'sans modèle mais avec un historique, la séance courte prend le relais',
    () {
      final suggestions = _texts(const CoachContext(hasHistory: true));

      expect(suggestions.first, 'Propose-moi une séance courte');
    },
  );

  test('un record récent invite à continuer, un record ancien à débloquer', () {
    final recent = _texts(
      const CoachContext(
        recordExerciseName: 'Développé couché',
        recordAgeDays: 3,
      ),
    );
    final old = _texts(
      const CoachContext(
        recordExerciseName: 'Développé couché',
        recordAgeDays: 90,
      ),
    );

    expect(recent.first, contains('continuer'));
    expect(old.first, contains('stagne'));
  });

  test('une variation de poids sous le bruit de balance ne dit rien', () {
    // 200 g d'écart, c'est l'heure de la pesée, pas une tendance.
    final noise = _texts(const CoachContext(weightTrendKg: 0.2));
    final real = _texts(const CoachContext(weightTrendKg: 1.4));

    expect(noise, hasLength(1));
    expect(noise.single, isNot(contains('poids')));
    expect(real.first, contains('poids'));
  });

  test('la hausse et la baisse ne posent pas la même question', () {
    final up = _texts(const CoachContext(weightTrendKg: 1.2));
    final down = _texts(const CoachContext(weightTrendKg: -1.2));

    expect(up.single, isNot(down.single));
  });

  test(
    'l’identité Carlys ajoute son amorce, différente pour chaque profil',
    () {
      final byProfile = {
        for (final profile in CarlysProfile.values)
          profile: _texts(CoachContext(carlysProfile: profile)),
      };

      // Chaque profil a la sienne, et elles ne se ressemblent pas.
      final chips = byProfile.values.map((s) => s.first).toSet();
      expect(chips, hasLength(CarlysProfile.values.length));

      // Sans profil : rien n'apparaît — null n'est jamais un défaut.
      final none = _texts(const CoachContext());
      expect(none.single, 'Par où je commence ?');
    },
  );

  test('l’amorce du profil vient après la plus actionnable', () {
    final suggestions = _texts(
      const CoachContext(
        carlysProfile: CarlysProfile.challenger,
        templateName: 'Push A',
      ),
    );

    expect(suggestions.first, contains('Push A'));
    expect(suggestions[1], 'Rends ma prochaine séance plus exigeante');
  });

  test('la bande ne dépasse jamais trois puces', () {
    final suggestions = _texts(
      const CoachContext(
        templateName: 'Push A',
        recordExerciseName: 'Squat',
        recordAgeDays: 5,
        weightTrendKg: -1.1,
        hasHistory: true,
      ),
    );

    expect(suggestions, hasLength(maxCoachSuggestions));
  });
}
