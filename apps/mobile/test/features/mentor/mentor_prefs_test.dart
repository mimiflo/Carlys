import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_prefs.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Les préférences du Mentor sur l'appareil : défauts sûrs, écritures
/// idempotentes, remise à zéro de la visite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = MentorPrefsStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('les défauts : interventions actives, au cran DISCRET', () {
    // Même règle que les catégories de notification : jamais réglé vaut
    // accepté — et le cran par défaut est le moins bavard.
    expect(MentorPrefs.defauts.interventionsActives, isTrue);
    expect(MentorPrefs.defauts.frequence, MentorFrequency.hebdomadaire);
  });

  test(
    'lecture sur préférences vierges : les défauts, jamais une erreur',
    () async {
      final prefs = await store.read();
      expect(prefs.interventionsActives, isTrue);
      expect(prefs.frequence, MentorFrequency.hebdomadaire);
    },
  );

  test('écrire puis relire rend ce qui a été écrit', () async {
    await store.setInterventionsActives(actives: false);
    await store.setFrequence(MentorFrequency.quotidienne);

    final prefs = await store.read();
    expect(prefs.interventionsActives, isFalse);
    expect(prefs.frequence, MentorFrequency.quotidienne);
  });

  test('une fréquence inconnue retombe sur le cran discret', () {
    expect(MentorFrequency.fromWire('minute'), MentorFrequency.hebdomadaire);
    expect(MentorFrequency.fromWire(null), MentorFrequency.hebdomadaire);
  });

  test('un style inconnu rend null : jamais une voix devinée', () {
    expect(MentorStyle.fromWire('SERGENT'), isNull);
    expect(MentorStyle.fromWire(null), isNull);
    expect(MentorStyle.fromWire('EXIGEANT'), MentorStyle.exigeant);
  });

  test(
    'marquer une étape vue est idempotent, la remise à zéro efface tout',
    () async {
      await store.marquerEtapeVue('accueil');
      await store.marquerEtapeVue('accueil');
      await store.marquerEtapeVue('nutrition');
      expect(await store.readVisiteVues(), {'accueil', 'nutrition'});

      await store.reinitialiserVisite();
      expect(await store.readVisiteVues(), isEmpty);
    },
  );

  test('les célébrations dites se gardent, sans doublon', () async {
    await store.marquerCelebrationDite('maitrise-5');
    await store.marquerCelebrationDite('maitrise-5');
    expect(await store.readCelebrationsDites(), {'maitrise-5'});
  });
}
