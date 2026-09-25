import 'social_provider.dart';

/// Pourquoi l'appareil n'a pas obtenu de jeton — la catégorie qui choisit
/// la PHRASE affichée. Le code, lui, dit la cause exacte.
enum SocialSignInObstacle {
  /// Le fournisseur ne s'ouvre pas sur cette plateforme (Apple sur Android).
  plateforme,

  /// Le build n'a pas de quoi demander un jeton pour notre serveur
  /// (client OAuth absent), ou le SDK n'en a pas rendu.
  configuration,

  /// Le fournisseur REFUSE cette installation : côté Google, le nom de
  /// paquet ou l'empreinte SHA-1 de la clé de signature ne figurent pas
  /// dans le client OAuth Android (`ApiException: 10`, DEVELOPER_ERROR).
  ///
  /// Distingué de [configuration] parce que le geste correctif n'est pas le
  /// même : ici le build est bon, c'est la console Google Cloud qui ne
  /// connaît pas cet APK.
  identiteAppareil,

  /// Le fournisseur n'est pas joignable depuis le téléphone
  /// (`ApiException: 7`, NETWORK_ERROR).
  reseau,

  /// Le fournisseur a répondu, et la connexion n'a pas abouti : écran de
  /// consentement incomplet (`12500`), compte à réautoriser, greffon absent,
  /// erreur imprévue du SDK.
  echec,
}

/// L'appareil ne peut pas obtenir de jeton pour ce fournisseur.
///
/// Porte la RAISON ([obstacle], qui choisit la phrase) et le CODE court et
/// stable ([code]) que la personne recopie : la présentation n'a pas à
/// interroger la plateforme, ce qu'un contrôleur ne doit pas faire et qu'un
/// test ne pourrait pas simuler.
///
/// Levée par la passerelle (`data/datasources/social_sign_in.dart`), qui
/// seule connaît les SDK ; rangée ici, dans le domaine, parce que la
/// présentation la lit et ne doit jamais importer la couche données.
class SocialSignInUnavailable implements Exception {
  const SocialSignInUnavailable(
    this.provider,
    this.obstacle, {
    required this.code,
    this.cause,
  });

  final SocialProvider provider;
  final SocialSignInObstacle obstacle;

  /// `google-12500`, `apple-plateforme`… Liste FERMÉE, documentée dans
  /// `docs/deployment/connexion-sociale.md` (« Diagnostiquer un échec »).
  final String code;

  /// L'erreur d'origine du SDK — pour les logs, jamais pour l'affichage.
  final Object? cause;

  @override
  String toString() =>
      'SocialSignInUnavailable(${provider.name}, ${obstacle.name}, $code, '
      '$cause)';
}
