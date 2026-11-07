/// Où en est la santé connectée, pour le compte ouvert sur CET appareil.
enum HealthConnectionStatus {
  /// Jamais activée, ou désactivée : Carlys ne lit rien.
  off,

  /// Les trois lectures (pas, poids, masse grasse) sont accordées.
  connected,

  /// La personne a refusé — à la demande, ou plus tard dans Health Connect.
  refused,

  /// Android sans l'application Health Connect.
  needsInstall,

  /// Ce téléphone ne le permet pas.
  unsupported,
}

class HealthSettings {
  const HealthSettings({
    required this.status,
    this.stepsGoal = defaultStepsGoal,
  });

  /// L'objectif de pas par défaut, RÉGLABLE. Pas 10 000 — un chiffre
  /// publicitaire (un podomètre japonais de 1965) — mais 8 000 : le seuil
  /// où, pour un adulte, le bénéfice des pas sur la mortalité commence à
  /// plafonner (Paluch et al., The Lancet Public Health, 2022).
  static const int defaultStepsGoal = 8000;

  /// Bornes du réglage : en dessous, ce n'est plus un objectif ; au-dessus,
  /// une erreur de frappe.
  static const int minStepsGoal = 1000;
  static const int maxStepsGoal = 50000;

  final HealthConnectionStatus status;
  final int stepsGoal;

  bool get connected => status == HealthConnectionStatus.connected;
}
