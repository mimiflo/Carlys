/// Entités du domaine abonnement (immuables, écrites à la main).
///
/// Le serveur DÉCIDE des droits ; l'app ne fait qu'afficher cet état.
library;

enum SubscriptionState {
  trialing('TRIALING', 'Essai en cours'),
  active('ACTIVE', 'Actif'),
  pastDue('PAST_DUE', 'Paiement en attente'),
  canceled('CANCELED', 'Résilié'),
  expired('EXPIRED', 'Expiré');

  const SubscriptionState(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SubscriptionState fromApi(String value) =>
      SubscriptionState.values.firstWhere(
        (state) => state.apiValue == value,
        orElse: () => SubscriptionState.expired,
      );
}

/// Abonnement courant tel que projeté par le serveur.
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.planName,
    required this.state,
    required this.cancelAtPeriodEnd,
    this.currentPeriodEnd,
  });

  final String planName;
  final SubscriptionState state;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;
}

/// Plan effectif de l'utilisateur.
class PlanStatus {
  const PlanStatus({
    required this.planName,
    required this.isPremium,
    this.subscription,
  });

  final String planName;
  final bool isPremium;
  final SubscriptionInfo? subscription;
}

/// Droit individuel, évalué côté serveur.
class EntitlementEntry {
  const EntitlementEntry({
    required this.key,
    required this.isActive,
    this.expiresAt,
  });

  final String key;
  final bool isActive;
  final DateTime? expiresAt;

  static const Map<String, String> _labels = {
    'unlimited_programs': 'Programmes illimités',
    'advanced_statistics': 'Statistiques avancées',
    'premium_exercises': 'Exercices premium du catalogue',
    'health_sync': 'Synchronisation santé (à venir)',
    'cloud_backup': 'Sauvegarde cloud',
    'ai_coaching': 'Coach IA',
    'coach_dashboard': 'Espace coach (à venir)',
    'custom_animations': 'Animations avancées (à venir)',
    'priority_support': 'Support prioritaire',
  };

  String get label => _labels[key] ?? key;
}
