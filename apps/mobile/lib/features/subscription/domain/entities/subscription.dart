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

/// Rythme de facturation d'une offre.
enum OfferPeriod {
  month('month', 'par mois'),
  year('year', 'par an');

  const OfferPeriod(this.apiValue, this.suffix);

  final String apiValue;
  final String suffix;

  static OfferPeriod fromApi(String value) => OfferPeriod.values.firstWhere(
    (period) => period.apiValue == value,
    orElse: () => OfferPeriod.month,
  );
}

/// Une offre du catalogue.
///
/// Les prix viennent du SERVEUR. Une application qui porterait ses propres
/// tarifs mentirait le jour où ils changent, et il faudrait une mise à jour
/// de l'app pour corriger un prix.
class SubscriptionOffer {
  const SubscriptionOffer({
    required this.id,
    required this.name,
    required this.period,
    required this.amountCents,
    required this.currency,
    required this.monthlyEquivalentCents,
    required this.trialDays,
    required this.isRecommended,
    this.savingPercent,
  });

  final String id;
  final String name;
  final OfferPeriod period;
  final int amountCents;
  final String currency;
  final int monthlyEquivalentCents;
  final int trialDays;
  final bool isRecommended;

  /// Économie face au mensuel. `null` quand il n'y en a pas : un badge
  /// « 0 % » décrédibiliserait tout le reste de l'écran.
  final int? savingPercent;
}

/// Le catalogue, et l'état réel du paiement.
class OfferCatalog {
  const OfferCatalog({required this.offers, required this.checkoutAvailable});

  final List<SubscriptionOffer> offers;

  /// Le paiement est-il ouvert côté serveur ? Sinon on montre ce que Premium
  /// apporte sans promettre un achat qui échouerait.
  final bool checkoutAvailable;
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
