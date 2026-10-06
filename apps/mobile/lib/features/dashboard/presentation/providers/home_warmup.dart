import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../community/presentation/providers/community_providers.dart';
import '../../../mentor/presentation/providers/mentor_providers.dart';
import '../../../progression/presentation/providers/reward_providers.dart';
import 'form_reading_providers.dart';
import 'home_day_providers.dart';
import 'today_metrics.dart';

/// Les sections de l'accueil qui attendent le RÉSEAU (semaine, records,
/// métabolisme, repas du jour, fil d'amis), par leur provider de tête : en
/// écouter un réveille toute sa chaîne de lectures.
///
/// L'écran de démarrage les écoute pendant ses 2,6 s pour un habitué
/// connecté : avant, rien ne partait avant le premier `build` de l'accueil,
/// et ses sections apparaissaient après coup, l'une après l'autre.
final List<ProviderListenable<Object?>> homeWarmup = [
  weekOverviewProvider,
  formReadingProvider,
  quoteFactsProvider,
  todayMetricsProvider,
  latestEncouragementProvider,
  mentorWordProvider,
  showcaseRewardsProvider,
];
