import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouverture d'une adresse HORS de l'application (navigateur système).
///
/// Injectable : un test ne doit jamais lancer un navigateur, et sans greffon
/// `url_launcher` ne répond pas du tout dans un test de widget.
typedef ExternalLinkOpener = Future<bool> Function(Uri url);

/// Seam commun des liens sortants NON MARCHANDS : textes légaux, pages
/// publiques du produit.
///
/// L'achat garde le sien (`urlOpenerProvider`, feature abonnement) : il vit
/// avec la mécanique de caisse, qui a ses propres règles et ses propres
/// tests. Les deux gagneront à n'en faire qu'un, mais pas au prix d'un
/// couplage de la feature profil sur la feature abonnement.
final externalLinkOpenerProvider = Provider<ExternalLinkOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});
