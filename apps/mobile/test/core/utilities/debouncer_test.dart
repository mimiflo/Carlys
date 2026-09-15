import 'package:carlys_mobile/core/utilities/debouncer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : une frappe ne part pas sur le réseau.
///
/// La feuille « Choisir un exercice » — ouverte EN PLEINE SÉANCE — envoyait
/// une requête HTTP par caractère : dix-sept pour « Développé couché », dont
/// seize jetées avant même d'être affichées. La bibliothèque d'exercices,
/// elle, débouncait depuis toujours ; les deux partagent désormais la même
/// mécanique, plutôt que deux minuteries écrites séparément.
void main() {
  test('les appels rapprochés n’en déclenchent qu’UN', () {
    fakeAsync((avancer) {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var appels = 0;

      for (var i = 0; i < 17; i++) {
        debouncer.run(() => appels++);
        avancer.elapse(const Duration(milliseconds: 10));
      }
      // Rien n'est encore parti : chaque frappe a repoussé la précédente.
      expect(appels, 0);

      avancer.elapse(const Duration(milliseconds: 100));
      expect(appels, 1);
    });
  });

  test('deux salves séparées donnent deux appels', () {
    // Contre-épreuve : un anti-rebond qui ne rendrait jamais la main
    // passerait le test précédent tout aussi bien.
    fakeAsync((avancer) {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var appels = 0;

      debouncer.run(() => appels++);
      avancer.elapse(const Duration(milliseconds: 150));
      debouncer.run(() => appels++);
      avancer.elapse(const Duration(milliseconds: 150));

      expect(appels, 2);
    });
  });

  test('cancel abandonne l’action en attente', () {
    // Une minuterie qui survit à son écran réveille un objet détruit.
    fakeAsync((avancer) {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var appels = 0;

      debouncer.run(() => appels++);
      debouncer.cancel();
      avancer.elapse(const Duration(milliseconds: 500));

      expect(appels, 0);
    });
  });

  test('le délai de recherche est celui que les deux écrans emploient', () {
    expect(Debouncer().delay, Debouncer.search);
  });
}
