import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouverture d'une adresse HORS de l'application (navigateur système).
///
/// Injectable : un test ne doit jamais lancer un navigateur, et sans greffon
/// `url_launcher` ne répond pas du tout dans un test de widget.
typedef ExternalLinkOpener = Future<bool> Function(Uri url);

/// Seam UNIQUE des liens sortants : textes légaux, pages publiques du
/// produit, page de paiement et portail de facturation.
///
/// Les features ne se couplent pas entre elles pour autant : elles dépendent
/// toutes de `core`, qui est partagé par construction. Un seul endroit à
/// substituer dans un test, un seul endroit à changer le jour où l'ouverture
/// d'un lien doit se comporter autrement.
final externalLinkOpenerProvider = Provider<ExternalLinkOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});
