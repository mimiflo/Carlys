/// Étapes du PARCOURS DE PREMIÈRE OUVERTURE, dans l'ordre où elles sont
/// franchies. L'étape atteinte est persistée : le parcours ne se rejoue
/// jamais une fois terminé.
///
/// L'ordre de déclaration fait foi (`index`) : une étape ne peut qu'avancer.
enum FirstRunStep {
  /// Questions de profil (objectif, sexe, naissance, taille, activité).
  onboarding('onboarding'),

  /// Création de compte (ou connexion pour qui en a déjà un).
  account('compte'),

  /// Proposition Premium, avec repli explicite en version gratuite.
  subscription('abonnement'),

  /// Parcours terminé : l'application démarre directement sur l'accueil.
  done('termine');

  const FirstRunStep(this.storageValue);

  /// Valeur écrite dans les préférences locales.
  final String storageValue;

  static FirstRunStep fromStorage(String? value) =>
      FirstRunStep.values.firstWhere(
        (step) => step.storageValue == value,
        orElse: () => FirstRunStep.onboarding,
      );

  bool get isTunnel => this != FirstRunStep.done;

  /// Étape EFFECTIVE une fois croisée avec l'état de session :
  ///  - une session déjà ouverte satisfait l'étape « compte » (mode démo,
  ///    session restaurée, compte créé juste avant) ;
  ///  - une session absente ramène de « abonnement » vers « compte », la
  ///    proposition Premium n'ayant de sens qu'avec un compte.
  FirstRunStep resolved({required bool authenticated}) => switch (this) {
        FirstRunStep.account ||
        FirstRunStep.subscription =>
          authenticated ? FirstRunStep.subscription : FirstRunStep.account,
        FirstRunStep.onboarding || FirstRunStep.done => this,
      };
}
