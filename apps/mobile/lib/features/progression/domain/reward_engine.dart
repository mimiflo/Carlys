/// Le catalogue des récompenses, et la fonction PURE qui dit lesquelles sont
/// méritées.
///
/// Pure au sens strict : ni horloge, ni base, ni réseau. Les faits entrent,
/// une liste sort. C'est ce qui permet d'éprouver chaque seuil au cas par
/// cas, et ce qui garantit que deux appareils accordent les mêmes
/// récompenses pour la même histoire.
///
/// Les seuils sont ATTEIGNABLES, et espacés pour raconter quelque chose :
/// un premier pas, un cap, un engagement. Un palier hors de portée n'est pas
/// une exigence, c'est une carotte.
library;

import 'progression.dart';
import 'reward.dart';

/// Les faits qui décident des récompenses.
///
/// Ils regardent la vie ENTIÈRE, là où le profil ne regarde qu'une fenêtre
/// récente : une médaille se gagne une fois, un score se recalcule.
class RewardFacts {
  const RewardFacts({
    required this.reachedTitle,
    this.completedSessions = 0,
    this.bestWeekStreak = 0,
    this.balancedWeeks = 0,
    this.lessonsAnswered = 0,
    this.lessonsTotal = 0,
    this.academyDomainsCompleted = 0,
    this.academyDomainsServed = 0,
    this.personalRecords = 0,
  });

  /// Titre atteint aujourd'hui par le profil dérivé.
  final CarlysTitle reachedTitle;

  /// Séances terminées depuis toujours.
  final int completedSessions;

  /// Plus longue suite de semaines consécutives avec au moins une séance.
  /// Le RECORD, pas la série en cours : une série cassée reste gagnée.
  final int bestWeekStreak;

  /// Semaines passées entre deux et quatre séances — le rythme que l'axe
  /// « Équilibre » considère comme tenable.
  final int balancedWeeks;

  final int lessonsAnswered;
  final int lessonsTotal;

  /// Domaines de l'Academy entièrement abordés, et domaines qui contiennent
  /// au moins une leçon.
  ///
  /// Deux ENTIERS, pas l'énumération des domaines : le moteur de
  /// récompenses n'a pas à connaître l'Academy pour décider d'un palier, et
  /// lui passer ses types ferait dépendre la progression d'une autre
  /// fonctionnalité. Le nom du domaine achevé, lui, se célèbre DANS
  /// l'Academy, là où il veut dire quelque chose.
  final int academyDomainsCompleted;
  final int academyDomainsServed;

  /// Records personnels connus. Ils viennent du serveur : hors ligne on en
  /// compte zéro, et le journal continue d'afficher ceux déjà obtenus.
  final int personalRecords;
}

/// Une règle du catalogue : la récompense, et ce qu'il faut pour l'avoir.
class RewardRule {
  const RewardRule(this.reward, this.isEarned);

  final Reward reward;
  final bool Function(RewardFacts facts) isEarned;
}

/// Le catalogue, dans l'ordre où il se raconte.
final List<RewardRule> rewardCatalog = [
  // ── CONSTANCE : revenir, semaine après semaine ─────────────────────────
  RewardRule(
    const Reward(
      id: 'constance-2',
      kind: RewardKind.badge,
      label: 'Deux semaines de suite',
      story: 'Deux semaines consécutives avec au moins une séance.',
      value: CarlysValue.constance,
    ),
    (facts) => facts.bestWeekStreak >= 2,
  ),
  RewardRule(
    const Reward(
      id: 'constance-4',
      kind: RewardKind.medaille,
      label: 'Un mois sans lâcher',
      story: 'Quatre semaines consécutives avec au moins une séance.',
      value: CarlysValue.constance,
    ),
    (facts) => facts.bestWeekStreak >= 4,
  ),
  RewardRule(
    const Reward(
      id: 'constance-8',
      kind: RewardKind.medaille,
      label: 'Deux mois de suite',
      story: 'Huit semaines consécutives avec au moins une séance.',
      value: CarlysValue.constance,
    ),
    (facts) => facts.bestWeekStreak >= 8,
  ),
  RewardRule(
    const Reward(
      id: 'constance-24',
      kind: RewardKind.certificat,
      label: 'Une saison entière',
      story: 'Vingt-quatre semaines consécutives. Six mois de présence.',
      value: CarlysValue.constance,
    ),
    (facts) => facts.bestWeekStreak >= 24,
  ),

  // ── MAÎTRISE : comprendre le pourquoi avant le combien ─────────────────
  RewardRule(
    const Reward(
      id: 'maitrise-5',
      kind: RewardKind.badge,
      label: 'Cinq leçons',
      story: 'Cinq questions de l’Academy abordées.',
      value: CarlysValue.maitrise,
    ),
    (facts) => facts.lessonsAnswered >= 5,
  ),
  RewardRule(
    const Reward(
      id: 'maitrise-moitie',
      kind: RewardKind.medaille,
      label: 'La moitié du pack',
      story: 'La moitié des leçons de l’Academy abordées.',
      value: CarlysValue.maitrise,
    ),
    (facts) =>
        facts.lessonsTotal > 0 &&
        facts.lessonsAnswered * 2 >= facts.lessonsTotal,
  ),
  RewardRule(
    const Reward(
      id: 'maitrise-pack',
      kind: RewardKind.certificat,
      label: 'Academy terminée',
      story:
          'Toutes les leçons du pack abordées, bonnes ou mauvaises '
          'réponses confondues.',
      value: CarlysValue.maitrise,
    ),
    (facts) =>
        facts.lessonsTotal > 0 && facts.lessonsAnswered >= facts.lessonsTotal,
  ),

  // Achever un DOMAINE est un jalon différent d'avoir abordé N leçons : on
  // y a fait le tour d'un sujet. Trois paliers et non un par domaine — douze
  // récompenses de plus noieraient la vitrine, et « Hyrox terminé » après
  // deux questions vaudrait autant qu'« Academy terminée ». Le domaine
  // PRÉCIS se célèbre dans l'Academy, au moment où il se termine.
  RewardRule(
    const Reward(
      id: 'domaines-1',
      kind: RewardKind.badge,
      label: 'Un domaine bouclé',
      story: 'Toutes les leçons d’un domaine de l’Academy abordées.',
      value: CarlysValue.maitrise,
    ),
    (facts) => facts.academyDomainsCompleted >= 1,
  ),
  RewardRule(
    const Reward(
      id: 'domaines-moitie',
      kind: RewardKind.medaille,
      label: 'La moitié des domaines',
      story: 'La moitié des domaines de l’Academy bouclés.',
      value: CarlysValue.maitrise,
    ),
    (facts) =>
        facts.academyDomainsServed > 0 &&
        facts.academyDomainsCompleted * 2 >= facts.academyDomainsServed,
  ),
  RewardRule(
    const Reward(
      id: 'domaines-tous',
      kind: RewardKind.certificat,
      label: 'Tous les domaines',
      story: 'Chaque domaine de l’Academy bouclé, du premier au dernier.',
      value: CarlysValue.maitrise,
    ),
    (facts) =>
        facts.academyDomainsServed > 0 &&
        facts.academyDomainsCompleted >= facts.academyDomainsServed,
  ),

  // ── PERFORMANCE : demander un peu plus, régulièrement ──────────────────
  RewardRule(
    const Reward(
      id: 'performance-1',
      kind: RewardKind.badge,
      label: 'Premier record',
      story: 'Un premier record personnel inscrit.',
      value: CarlysValue.performance,
    ),
    (facts) => facts.personalRecords >= 1,
  ),
  RewardRule(
    const Reward(
      id: 'performance-5',
      kind: RewardKind.badge,
      label: 'Cinq records',
      story: 'Cinq records personnels sur cinq mouvements.',
      value: CarlysValue.performance,
    ),
    (facts) => facts.personalRecords >= 5,
  ),
  RewardRule(
    const Reward(
      id: 'performance-15',
      kind: RewardKind.medaille,
      label: 'Quinze records',
      story: 'Quinze records personnels. Le corps a changé d’échelle.',
      value: CarlysValue.performance,
    ),
    (facts) => facts.personalRecords >= 15,
  ),

  // ── DISCIPLINE : tenir le rendez-vous ──────────────────────────────────
  RewardRule(
    const Reward(
      id: 'discipline-10',
      kind: RewardKind.badge,
      label: 'Dix séances',
      story: 'Dix séances menées jusqu’au bout.',
      value: CarlysValue.discipline,
    ),
    (facts) => facts.completedSessions >= 10,
  ),
  RewardRule(
    const Reward(
      id: 'discipline-50',
      kind: RewardKind.medaille,
      label: 'Cinquante séances',
      story: 'Cinquante séances menées jusqu’au bout.',
      value: CarlysValue.discipline,
    ),
    (facts) => facts.completedSessions >= 50,
  ),
  RewardRule(
    const Reward(
      id: 'discipline-150',
      kind: RewardKind.certificat,
      label: 'Cent cinquante séances',
      story:
          'Cent cinquante séances terminées. Ce n’est plus une habitude, '
          'c’est un métier.',
      value: CarlysValue.discipline,
    ),
    (facts) => facts.completedSessions >= 150,
  ),

  // ── ÉQUILIBRE : récupérer fait partie de l'entraînement ────────────────
  RewardRule(
    const Reward(
      id: 'equilibre-4',
      kind: RewardKind.medaille,
      label: 'Quatre semaines à bon rythme',
      story:
          'Quatre semaines entre deux et quatre séances : assez pour '
          'progresser, assez peu pour récupérer.',
      value: CarlysValue.equilibre,
    ),
    (facts) => facts.balancedWeeks >= 4,
  ),
  RewardRule(
    const Reward(
      id: 'equilibre-12',
      kind: RewardKind.certificat,
      label: 'Trois mois d’équilibre',
      story:
          'Douze semaines au rythme tenable. La récupération fait partie '
          'du travail.',
      value: CarlysValue.equilibre,
    ),
    (facts) => facts.balancedWeeks >= 12,
  ),

  // ── TITRES : le palier atteint, gardé pour toujours ────────────────────
  //
  // Les inscrire au journal est ce qui rend la promesse tenable : le titre
  // AFFICHÉ suit les points et peut redescendre, le titre ATTEINT ne se
  // reprend pas.
  ...CarlysTitle.values
      .where((title) => title != CarlysTitle.apprenti)
      .map(
        (title) => RewardRule(
          Reward(
            id: '$titleRewardPrefix${title.name}',
            kind: RewardKind.titre,
            label: title.label,
            story: 'Titre atteint à ${title.threshold} points.',
            figure: title.roman,
          ),
          (facts) => facts.reachedTitle.index >= title.index,
        ),
      ),
];

/// Préfixe des identifiants de journal des titres.
///
/// GELÉ, comme tous les identifiants de récompense : le changer effacerait
/// des récompenses déjà obtenues chez les gens qui les ont gagnées. Il est
/// nommé ici pour que [titleOfReward] et le catalogue ne puissent pas
/// diverger — la seule façon sûre de relire une clé est de la construire au
/// même endroit qu'on l'écrit.
const String titleRewardPrefix = 'titre-';

/// Le titre derrière un identifiant de récompense, ou `null` si l'entrée
/// n'est pas un titre.
///
/// Sert au bandeau de franchissement, qui n'a qu'une récompense en main et
/// doit retrouver le palier pour en dire le SENS. Tolérant par construction :
/// un identifiant inconnu rend `null` au lieu de lever, parce qu'un journal
/// écrit par une version plus ancienne ne doit pas faire tomber l'écran.
CarlysTitle? titleOfReward(String rewardId) {
  if (!rewardId.startsWith(titleRewardPrefix)) {
    return null;
  }
  final nom = rewardId.substring(titleRewardPrefix.length);
  for (final titre in CarlysTitle.values) {
    if (titre.name == nom) {
      return titre;
    }
  }
  return null;
}

/// Les récompenses méritées par ces faits, dans l'ordre du catalogue.
List<Reward> earnedRewards(RewardFacts facts) {
  return [
    for (final rule in rewardCatalog)
      if (rule.isEarned(facts)) rule.reward,
  ];
}

/// La prochaine récompense à portée, pour chaque axe encore ouvert.
///
/// Elle sert à dire QUOI FAIRE plutôt qu'à afficher un vide. Une vitrine qui
/// ne montre que l'obtenu ne donne aucune direction.
List<Reward> nextRewards(RewardFacts facts, {int limit = 3}) {
  final pending = <Reward>[];
  final seenValues = <CarlysValue>{};
  for (final rule in rewardCatalog) {
    if (rule.isEarned(facts)) continue;
    final value = rule.reward.value;
    // Une seule par valeur : trois paliers du même axe diraient trois fois
    // la même chose.
    if (value != null && !seenValues.add(value)) continue;
    if (value == null) continue;
    pending.add(rule.reward);
    if (pending.length >= limit) break;
  }
  return pending;
}
