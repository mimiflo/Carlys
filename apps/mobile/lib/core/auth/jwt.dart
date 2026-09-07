import 'dart:convert';

/// Le claim `sub` d'un JWT, ou `null` si le jeton n'en a pas la forme.
///
/// Aucune vérification de signature : le jeton vient du trousseau, on n'en
/// lit qu'un identifiant pour un rangement local (à qui appartiennent les
/// données de cet appareil, sous quel compte une opération a été écrite).
/// C'est le serveur qui vérifie le jeton à l'envoi.
String? jwtSubjectOf(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload);
    if (claims is Map<String, dynamic>) {
      final subject = claims['sub'];
      if (subject is String && subject.isNotEmpty) {
        return subject;
      }
    }
  } on FormatException {
    // Pas un JWT : traité comme un jeton sans propriétaire lisible.
  }
  return null;
}
