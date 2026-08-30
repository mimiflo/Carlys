/// Code ami : l'identité PARTAGEABLE d'un compte, à la Snapchat — on la
/// donne de vive voix, on la tape, on la porte en QR sur son profil.
///
/// Miroir Dart de `apps/api/src/modules/users/domain/friend-code.ts` : les
/// deux côtés doivent normaliser pareil, sans quoi un code dicté au
/// téléphone passerait côté serveur et échouerait côté application.
library;

/// Huit caractères d'un alphabet sans ambiguïté visuelle : ni 0/O, ni
/// 1/I/L, ni B/8, G/6, S/5, Z/2, Q/O — un code se dicte sans épeler.
const String friendCodeAlphabet = '23456789ACDEFHJKMNPRTUVWXY';

const int friendCodeLength = 8;

/// Charge utile des QR de profil : le préfixe distingue un QR Carlys de
/// n'importe quel autre code scanné par erreur.
const String friendCodeQrPrefix = 'carlys:friend:';

final RegExp _canonical = RegExp('^[$friendCodeAlphabet]{$friendCodeLength}\$');

/// Ramène une saisie humaine (ou un QR scanné) à la forme canonique, ou
/// `null` si ce n'en est pas une. Tolère la casse, les espaces, les tirets
/// de la forme affichée `XXXX-XXXX` et le préfixe des QR.
String? normalizeFriendCode(String raw) {
  final stripped = raw
      .replaceFirst(friendCodeQrPrefix, '')
      .replaceAll(RegExp(r'[\s-]'), '')
      .toUpperCase();
  return _canonical.hasMatch(stripped) ? stripped : null;
}

/// Forme affichée : `XXXX-XXXX`, plus lisible et plus facile à dicter.
String formatFriendCode(String code) {
  return '${code.substring(0, 4)}-${code.substring(4)}';
}

/// Ce que le QR de profil encode pour un code donné.
String friendCodeQrPayload(String code) => '$friendCodeQrPrefix$code';

/// Une saisie libre est-elle une adresse e-mail plutôt qu'un code ?
/// Le champ d'ajout accepte les deux : l'arobase tranche.
bool looksLikeEmail(String raw) => raw.contains('@');
