import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/account_bound_cache.dart';
import '../controllers/account_session.dart';

/// ÉCRITURES D'AVANCE sur un [AccountBoundCache] : le geste se VOIT sous le
/// doigt, puis s'écrit au serveur. Une écriture réussie laisse au serveur ce
/// que l'écran montre déjà : pas de relecture — avant, chaque geste
/// attendait l'écriture PUIS la relecture, deux allers-retours de délai.
///
/// Partagé par les entrées de génération et le partage de progression :
/// les quatre règles ci-dessous ont chacune corrigé un défaut, une copie
/// en oublierait une.
class AheadWrites<T> {
  AheadWrites(this._ref, this._cache);

  final Ref _ref;
  final AsyncNotifierProvider<AccountBoundCache<T>, T> _cache;

  /// 1. SÉRIALISÉES : les écritures arrivent au serveur dans l'ordre des
  /// gestes, la dernière gagne. La chaîne avale l'échec ; l'appelant, lui,
  /// voit le sien.
  Future<void> _chain = Future<void>.value();
  int _inFlight = 0;

  /// Une écriture est en vol : une relecture lancée maintenant pourrait
  /// revenir avec la valeur d'AVANT et écraser le geste montré.
  bool get busy => _inFlight > 0;

  /// 2. Ce que le serveur tient, d'après les écritures revenues : la valeur
  /// montrée quand la file a commencé, plus chaque écriture réussie. Un
  /// refus y REVIENT avant de relire — une relecture qui échoue aussi (hors
  /// ligne) garderait sinon le choix refusé à l'écran, Riverpod conservant
  /// la dernière valeur dans l'erreur.
  T? _confirmed;
  bool _refused = false;

  /// 3. La session de la file en cours. Chaque écriture capture LA SIENNE :
  /// le compte qui arrive ne reçoit ni les écritures ni la valeur confirmée
  /// de celui qui part, et son propre geste, posé pendant qu'une écriture de
  /// l'autre est encore en vol, part bel et bien.
  int? _session;

  /// Montre `apply(montré)` tout de suite, puis [send] à son tour dans la
  /// file. [apply] sert deux fois : sur ce qui est montré, puis sur ce qui
  /// est confirmé.
  Future<void> write(T Function(T base) apply, Future<void> Function() send) =>
      whenShown((shown) {
        final session = _ref.read(accountSessionProvider);
        if (_inFlight++ == 0 || session != _session) {
          // Une file neuve : rien de confirmé ni de refusé ne passe d'un
          // compte à l'autre.
          _confirmed = shown;
          _session = session;
          _refused = false;
        }
        _ref.read(_cache.notifier).show(apply(shown));
        bool mine() => session == _session;
        final task = _chain.then((_) async {
          if (_ref.read(accountSessionProvider) != session) return;
          await send();
          if (mine()) _confirmed = apply(_confirmed ?? shown);
        });
        _chain = task.then((_) {}, onError: (Object _) {});
        return task.then(
          (_) => _settle(),
          onError: (Object error, StackTrace stack) {
            if (mine()) _refused = true;
            _settle();
            Error.throwWithStackTrace(error, stack);
          },
        );
      });

  /// 4. Lance [gesture] sur ce que l'écran montre. Rien de montré, ou une
  /// lecture en vol (elle reviendrait ÉCRASER le geste montré d'avance) :
  /// on l'attend d'abord — les gestes ainsi retenus partent dans l'ordre.
  /// Une lecture restée en ERREUR se rejouerait telle quelle (`.future`
  /// rend l'échec en cache) : on la relance.
  Future<void> whenShown(Future<void> Function(T shown) gesture) {
    final cache = _ref.read(_cache);
    if (cache.hasValue && !cache.isLoading) return gesture(cache.requireValue);
    if (cache.hasError) _ref.invalidate(_cache);
    return _ref.read(_cache.future).then((_) => whenShown(gesture));
  }

  /// La dernière écriture revenue : après un refus, l'écran revient à la
  /// valeur confirmée, puis relit.
  void _settle() {
    if (--_inFlight > 0) return;
    final confirmed = _confirmed;
    final refused = _refused;
    _confirmed = null;
    _refused = false;
    if (!refused || _ref.read(accountSessionProvider) != _session) return;
    if (confirmed != null) _ref.read(_cache.notifier).show(confirmed);
    _ref.invalidate(_cache);
  }
}
