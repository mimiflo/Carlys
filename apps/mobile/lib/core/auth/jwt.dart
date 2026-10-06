import 'dart:convert';

/// Le claim `sub` d'un JWT, ou `null` si le jeton n'en a pas la forme.
///
/// Aucune vérification de signature : le jeton vient du trousseau, on n'en
/// lit qu'un identifiant pour un rangement local (à qui appartiennent les
/// données de cet appareil, sous quel compte une opération a été écrite).
/// C'est le serveur qui vérifie le jeton à l'envoi.
String? jwtSubjectOf(String token) {
  final subject = _claimsOf(token)?['sub'];
  return subject is String && subject.isNotEmpty ? subject : null;
}

/// L'échéance (`exp`) d'un JWT, ou `null` s'il n'en porte pas. Même réserve
/// que [jwtSubjectOf] : une lecture pour anticiper, jamais une vérification.
DateTime? jwtExpiryOf(String token) => _instant(_claimsOf(token)?['exp']);

/// La durée de vie d'un JWT (`exp − iat`, deux instants du SERVEUR, donc
/// insensible à l'horloge de l'appareil), ou `null`.
Duration? jwtLifetimeOf(String token) {
  final claims = _claimsOf(token);
  final exp = _instant(claims?['exp']);
  final iat = _instant(claims?['iat']);
  if (exp == null || iat == null || !exp.isAfter(iat)) return null;
  return exp.difference(iat);
}

/// Un instant en secondes Unix, dans une plage plausible — une valeur
/// aberrante ne doit pas faire lever chaque requête.
DateTime? _instant(Object? seconds) =>
    seconds is int && seconds > 0 && seconds < 100000000000
    ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
    : null;

Map<String, dynamic>? _claimsOf(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return claims is Map<String, dynamic> ? claims : null;
  } on FormatException {
    // Pas un JWT : traité comme un jeton sans contenu lisible.
    return null;
  }
}
