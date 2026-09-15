import 'dart:async';

/// Repousse une action tant que les appels s'enchaînent.
///
/// POURQUOI AU CŒUR. La bibliothèque d'exercices débouncait déjà sa
/// recherche ; la feuille « Choisir un exercice » — ouverte EN PLEINE SÉANCE,
/// donc au pire moment — ne le faisait pas : chaque frappe repoussait un état
/// qui sert de clé à un `FutureProvider`, soit un aller-retour HTTP par
/// caractère. « Développé couché » représentait dix-sept requêtes dont seize
/// jetées, sur un réseau de salle de sport.
///
/// Le délai et la mécanique vivent donc en un seul endroit : deux minuteries
/// écrites séparément auraient fini par diverger, et c'est la seconde qui
/// avait simplement été oubliée.
class Debouncer {
  Debouncer({this.delay = search});

  /// Le délai d'une recherche à la frappe. Assez long pour qu'un mot entier
  /// ne déclenche qu'une requête, assez court pour ne pas donner
  /// l'impression que l'écran ne répond pas.
  static const Duration search = Duration(milliseconds: 350);

  final Duration delay;
  Timer? _timer;

  /// Programme [action], en annulant celle qui attendait encore.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Abandonne l'action en attente. À appeler dans `dispose` : une minuterie
  /// qui survit à son écran réveille un objet détruit.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
