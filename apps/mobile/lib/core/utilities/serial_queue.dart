import 'dart:async';

/// Une file d'attente : les tâches qu'on lui confie s'exécutent l'une APRÈS
/// l'autre, jamais en parallèle.
///
/// À quoi elle sert ici : toute séquence « lire, modifier, réécrire » qui
/// comporte un `await` entre la lecture et l'écriture perd une écriture dès
/// que deux exécutions se chevauchent (la seconde relit l'état d'avant la
/// première et l'écrase). Ce n'est pas théorique dans cette application :
/// les providers Riverpod sont invalidés en rafale au démarrage, et rien
/// n'annule la future déjà en vol.
///
/// [run] rend le résultat de SA tâche, avec son erreur s'il y en a une ; la
/// file, elle, avale l'échec pour ne pas condamner les tâches suivantes.
class SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final mine = _tail.then((_) => task());
    _tail = mine.then((_) {}, onError: (Object _) {});
    return mine;
  }
}
