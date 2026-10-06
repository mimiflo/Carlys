import 'jwt.dart';

/// QUAND renouveler le jeton d'accès d'avance — sans croire l'horloge de
/// l'appareil.
///
/// Comparer `exp` à l'heure du téléphone renouvelait à CHAQUE requête un
/// appareil en avance de quelques minutes : un jeton neuf y paraissait déjà
/// sur le point d'expirer. Or chaque rotation est une occasion de perdre la
/// réponse (réseau coupé, appli tuée), et le serveur prend alors le jeton
/// suivant pour une réutilisation et ferme la session. L'échéance se compte
/// donc en DURÉE DE VIE (`exp − iat`, deux instants du serveur), à partir du
/// moment où l'appareil a vu le jeton pour la première fois.
class TokenDeadline {
  TokenDeadline({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Marge avant l'échéance où le jeton se renouvelle d'avance.
  static const ahead = Duration(seconds: 60);

  /// Après un renouvellement raté (hors ligne, serveur en vrac), on n'en
  /// relance pas d'avance pendant ce délai : chaque requête l'aurait fait.
  static const cooldown = Duration(seconds: 30);

  final DateTime Function() _now;
  String? _token;
  DateTime? _deadline;
  DateTime? _failedAt;

  /// Le jeton est-il à renouveler avant l'envoi ?
  bool due(String token) {
    final failedAt = _failedAt;
    if (failedAt != null && _now().difference(failedAt) < cooldown) {
      return false;
    }
    if (token != _token) _track(token, fresh: false);
    final deadline = _deadline;
    return deadline != null && _now().add(ahead).isAfter(deadline);
  }

  /// Un jeton que l'appareil vient de recevoir du serveur : sa durée de vie
  /// court à partir de maintenant, quoi que dise l'horloge locale.
  void renewed(String token) {
    _failedAt = null;
    _track(token, fresh: true);
  }

  void failed() => _failedAt = _now();

  void _track(String token, {required bool fresh}) {
    _token = token;
    final lifetime = jwtLifetimeOf(token);
    if (lifetime == null) {
      _deadline = null;
      return;
    }
    final byLifetime = _now().add(lifetime);
    // Un jeton RETROUVÉ (trousseau, connexion) a peut-être déjà vécu : son
    // `exp` lu à l'horloge locale peut tomber plus tôt. Au pire, sur une
    // horloge fausse, un seul renouvellement de trop — le jeton qu'il rend
    // est neuf et compte en durée de vie.
    final byClock = jwtExpiryOf(token);
    _deadline = fresh || byClock == null || byClock.isAfter(byLifetime)
        ? byLifetime
        : byClock;
  }
}
