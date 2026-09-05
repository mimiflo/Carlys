import 'dart:async';

import 'package:carlys_mobile/demo/demo_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le catalogue de la démo doit se lire SOUS L'HORLOGE SIMULÉE d'un test de
/// widget — c'est-à-dire sans isolat et sans minuterie.
///
/// Ce que ce test garde : `rootBundle.loadString` délègue le décodage à un
/// isolat dès 50 Kio de texte, et cet isolat ne s'achève jamais quand le temps
/// est simulé. Le catalogue a franchi ce seuil en passant à 89 exercices ; la
/// bibliothèque est alors restée bloquée sur son indicateur de chargement,
/// alors que les tests ordinaires du catalogue, eux, passaient : un `test` sans
/// widget tourne en asynchrone RÉEL et ne voit pas le problème.
///
/// Fichier séparé À DESSEIN : `loadDemoCatalog()` mémorise sa lecture, et
/// chaque fichier de test tourne dans son propre isolat. Rangé à côté des
/// autres, ce test tomberait sur un catalogue déjà chargé et ne vérifierait
/// plus rien.
void main() {
  testWidgets('le catalogue se charge sans échapper au temps simulé', (
    tester,
  ) async {
    DemoCatalog? loaded;
    unawaited(loadDemoCatalog().then((catalog) => loaded = catalog));

    // Deux images suffisent : la lecture d'un asset se résout en microtâches.
    await tester.pump();
    await tester.pump();

    expect(
      loaded,
      isNotNull,
      reason:
          'lecture bloquée — un isolat ou une minuterie s’est glissé '
          'dans le chargement du catalogue',
    );
    expect(loaded!.exercises, isNotEmpty);
  });
}
