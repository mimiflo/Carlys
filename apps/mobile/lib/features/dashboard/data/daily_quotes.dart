/// Recueil des maximes Carlys — **contenu éditorial de l'application**.
///
/// Ce n'est pas une donnée utilisateur déguisée ni un faux backend : ce sont
/// les mots du produit, au même titre que ses libellés d'écran. Ils vivent
/// donc dans l'application, ce qui garantit qu'une maxime s'affiche **hors
/// ligne, dès le premier lancement**, sans appel réseau — la règle
/// offline-first vaut aussi pour ce qui motive.
///
/// Rien n'est attribué à une personne réelle : ce sont des maximes maison.
/// Prêter une phrase inventée à un athlète ou à un auteur serait une citation
/// fabriquée, donc un mensonge affiché à l'utilisateur.
///
/// ## Le ton, et ce qu'il exclut
///
/// La personnalité de la marque est ÉDUCATIVE (elle explique le pourquoi),
/// EXIGEANTE (elle compte sur la discipline plutôt que sur la motivation) et
/// BIENVEILLANTE (elle accompagne sans juger : essayer vaut mieux que
/// réussir parfaitement).
///
/// Quatre registres sont donc proscrits, et une première série les avait
/// tous adoptés sans qu'on y prenne garde :
///
/// - **la culpabilité** — « le jour où tu n'as pas envie compte double »,
///   « ne romps pas la chaîne » : punir une absence est le contraire
///   d'accompagner, et c'est ce qui fait abandonner ;
/// - **le culte de la douleur** — « écoute la douleur, elle a rarement
///   tort » : un conseil dangereux autant qu'une posture ;
/// - **le perfectionnisme** — « fais-le parfaitement » : la marque dit
///   exactement l'inverse ;
/// - **le jugement du corps** — « le poids ne ment pas ».
///
/// Une maxime Carlys apprend quelque chose, ou allège. Jamais elle ne fait
/// honte. `daily_quotes_test.dart` garde ces interdits par écrit.
///
/// ## L'entrelacement n'est plus une convention, c'est une construction
///
/// Les entrées sont servies **entrelacées par valeur** (constance, maîtrise,
/// performance, discipline, équilibre, puis on recommence) : comme la
/// sélection avance d'un cran par jour, deux jours consécutifs ne servent
/// jamais la même valeur.
///
/// Cet ordre était tenu à la main dans une seule longue liste. Ça marchait
/// tant que personne n'ajoutait une maxime isolée — et rien n'empêchait de
/// le faire, sinon un commentaire. Les maximes vivent désormais en **cinq
/// listes, une par valeur**, et [entrelacer] compose l'ordre. Ajouter une
/// maxime à une seule valeur ne dégrade plus l'alternance en silence : ça
/// déséquilibre les listes, et le composeur refuse.
library;

import 'package:flutter/foundation.dart';

import '../domain/entities/daily_quote.dart';
import '../domain/quote_facts.dart';
import '../domain/quote_selection.dart';
import 'quotes/constance_quotes.dart';
import 'quotes/discipline_quotes.dart';
import 'quotes/equilibre_quotes.dart';
import 'quotes/maitrise_quotes.dart';
import 'quotes/performance_quotes.dart';

/// Les maximes brutes, par valeur, dans l'ordre du manifeste.
///
/// L'ordre des clés EST l'ordre de l'entrelacement : le changer change la
/// rotation. `Map` littérale, donc ordre d'insertion garanti.
const Map<CarlysValue, List<QuoteEntry>> quotesByValue = {
  CarlysValue.constance: constanceQuotes,
  CarlysValue.maitrise: maitriseQuotes,
  CarlysValue.performance: performanceQuotes,
  CarlysValue.discipline: disciplineQuotes,
  CarlysValue.equilibre: equilibreQuotes,
};

/// LE RECUEIL DE ROTATION : un cycle complet de valeurs, puis le suivant.
///
/// Les maximes CONTEXTUELLES n'y sont pas, et c'est tout l'objet : « Après
/// une pause, reprends plus léger » s'affichait un jour sur soixante à qui
/// s'entraîne depuis six mois sans en manquer une. Elles vivent dans
/// [carlysContextualQuotes] et ne sortent que quand leur fait est vrai.
final List<DailyQuote> carlysQuotes = entrelacer(quotesByValue);

/// Les maximes ÉTIQUETÉES, toutes valeurs confondues, dans l'ordre des
/// fichiers. Servies par `quote_selection.dart`, jamais par la rotation.
final List<DailyQuote> carlysContextualQuotes = [
  for (final entree in quotesByValue.entries)
    for (final maxime in entree.value)
      if (maxime.contexts.isNotEmpty)
        DailyQuote(
          text: maxime.text,
          value: entree.key,
          contexts: maxime.contexts,
        ),
];

/// Compose l'ordre de rotation : une maxime de chaque valeur, puis on
/// recommence.
///
/// L'invariant porte sur les maximes SANS CONTEXTE, et sur elles seules :
/// ce sont les seules qui tournent. Lève si leur nombre diffère d'une valeur
/// à l'autre — tronquer à la plus courte perdrait des maximes sans le dire,
/// et composer quand même casserait l'alternance sur la fin du cycle. Un
/// déséquilibre est une erreur de rédaction, pas un cas à rattraper.
///
/// Les maximes étiquetées, elles, s'ajoutent librement : trois de plus à la
/// constance ne déséquilibrent rien, puisqu'elles ne passent jamais par ici.
@visibleForTesting
List<DailyQuote> entrelacer(Map<CarlysValue, List<QuoteEntry>> parValeur) {
  final rotation = {
    for (final entree in parValeur.entries)
      entree.key: entree.value.where((m) => m.contexts.isEmpty).toList(),
  };
  final longueurs = rotation.values.map((liste) => liste.length).toSet();
  if (longueurs.length != 1) {
    final detail = rotation.entries
        .map((e) => '${e.key.name} ${e.value.length}')
        .join(', ');
    throw StateError(
      'Les listes de maximes SANS CONTEXTE doivent avoir la même longueur '
      'pour que deux jours consécutifs ne servent jamais la même valeur. '
      'Ici : $detail. Une maxime ÉTIQUETÉE ne compte pas : elle ne tourne '
      'pas. Les maximes de rotation s’ajoutent par cycles de '
      '${parValeur.length}, une par valeur.',
    );
  }

  final cycles = longueurs.single;
  return [
    for (var cycle = 0; cycle < cycles; cycle++)
      for (final entree in rotation.entries)
        DailyQuote(text: entree.value[cycle].text, value: entree.key),
  ];
}

/// Maxime du jour, **déterministe** : la même toute la journée, différente
/// demain, identique sur tous les appareils de l'utilisateur.
///
/// L'index avance d'un cran par jour civil local, ce qui fait tourner le
/// recueil en [carlysQuotes.length] jours et change de valeur chaque matin.
DailyQuote quoteOfTheDay(DateTime day) {
  final index = _daysSinceEpoch(day) % carlysQuotes.length;
  return carlysQuotes[index];
}

/// LA MAXIME DU JOUR, contexte compris : les faits d'abord, le calendrier
/// ensuite.
///
/// L'ORDRE vient du domaine (`activeContexts`), la PHRASE vient d'ici : la
/// règle ne connaît pas le recueil, et le recueil ne décide de rien.
///
/// Déterministe à faits constants : deux appareils de la même personne
/// lisent la même phrase. Le contrat de stabilité n'est plus « la même toute
/// la journée » mais « la même TANT QUE LES FAITS NE CHANGENT PAS » :
/// terminer une séance à 18 h change légitimement la citation, et c'est tout
/// l'objet de l'affichage contextuel.
DailyQuote contextualQuote({required QuoteFacts facts, required DateTime day}) {
  for (final contexte in activeContexts(facts)) {
    final candidates = carlysContextualQuotes
        .where((maxime) => maxime.contexts.contains(contexte))
        .toList();
    if (candidates.isEmpty) {
      // Un contexte sans maxime rédigée n'est pas une erreur : il se saute,
      // et la priorité continue. C'est ce qui permet d'ajouter un contexte
      // avant son corpus sans casser l'accueil.
      continue;
    }
    // Le même repère que la rotation : le numéro de jour civil local.
    return candidates[_daysSinceEpoch(day) % candidates.length];
  }
  return quoteOfTheDay(day);
}

/// Numéro de jour civil local. On repasse par `DateTime.utc` avec les seuls
/// champs de date : le décalage horaire et les changements d'heure ne peuvent
/// donc pas faire sauter — ou rejouer — une journée.
int _daysSinceEpoch(DateTime day) {
  final local = day.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;
}
