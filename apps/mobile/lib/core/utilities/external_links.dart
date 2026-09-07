import 'package:flutter/material.dart';
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

/// Ouvre [url] et, si aucun navigateur ne répond, le DIT.
///
/// Un lien légal qui ne s'ouvre pas et ne dit rien laisse croire à un appui
/// sans effet, sur les seuls textes que l'utilisateur a le droit de lire. La
/// phrase est écrite ICI, une fois : les trois surfaces qui posent ces liens
/// (réglages, consentement d'inscription, récapitulatif de suppression) la
/// doivent à l'utilisateur dans les mêmes termes.
///
/// [messenger] est passé par l'appelant, capturé AVANT l'attente : le widget
/// peut être démonté quand l'ouverture rend la main, et son `context` avec.
Future<void> openExternalLink(
  Uri url, {
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
}) async {
  final opened = await ref.read(externalLinkOpenerProvider)(url);
  if (opened) return;
  messenger.showSnackBar(
    const SnackBar(content: Text('Aucun navigateur n’a pu ouvrir cette page.')),
  );
}
