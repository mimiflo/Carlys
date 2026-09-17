/// Le MOT du Mentor : une phrase sur l'accueil, à sa voix, jamais un flux.
///
/// FONCTION PURE : style + fréquence + jour civil (+ récompense à fêter)
/// rendent le mot — ni horloge interne, ni stockage, ni réseau. La rotation
/// est DÉTERMINISTE par période, comme la question du jour : au cran
/// quotidien le mot change chaque jour, au cran hebdomadaire il tient la
/// semaine — aucune date à retenir, donc rien à désynchroniser.
///
/// Une récompense fraîchement gagnée prend la parole en priorité : c'est la
/// célébration TRANSVERSE du plan Mentor, au franchissement (elle s'appuie
/// sur `EarnedReward.isNew`, qui ne vaut vrai que dans la session du
/// franchissement — la garde de première lecture du journal des récompenses
/// est déjà passée en amont).
library;

import '../../academy/domain/daily_lesson.dart' show dayOfYearIndex;
import '../../progression/domain/reward.dart';
import 'entities/mentor_prefs.dart';
import 'entities/mentor_style.dart';

/// Ce que le Mentor dit, et ce qu'il fête si c'est une célébration.
class MentorWord {
  const MentorWord({required this.message, this.celebratedRewardId});

  final String message;

  /// Identifiant de la récompense fêtée, `null` pour un mot ordinaire.
  final String? celebratedRewardId;

  bool get estCelebration => celebratedRewardId != null;
}

/// Les mots ordinaires, par voix. TROIS par voix : assez pour ne pas
/// radoter, assez peu pour que chaque phrase reste écrite avec soin.
/// La voix neutre sert tant qu'aucun style n'est choisi.
const Map<MentorStyle?, List<String>> _mots = {
  null: [
    'Une séance moyenne faite vaut mieux qu’une séance parfaite remise.',
    'Regarde ta semaine, pas ta journée : c’est elle qui progresse.',
    'Ce que tu notes existe. Ce que tu ne notes pas s’oublie.',
  ],
  MentorStyle.bienveillant: [
    'Tu es venu, c’est déjà la partie difficile. Le reste suit.',
    'Compare-toi à toi d’il y a trois mois : c’est le seul juge honnête.',
    'Un jour sans séance n’efface rien de ce que tu as construit.',
  ],
  MentorStyle.exigeant: [
    'La séance prévue, pas la séance rêvée. Fais-la, note-la, passe.',
    'Tu connais l’exercice que tu évites. Commence par lui.',
    'La régularité ne se négocie pas : décide l’heure, tiens l’heure.',
  ],
  MentorStyle.athlete: [
    'Échauffement, travail, retour au calme. Trois temps, aucun en option.',
    'Aujourd’hui : une charge propre, une amplitude pleine. Le reste suivra.',
    'Ta prochaine série vaut plus que ton dernier record. Va la chercher.',
  ],
  MentorStyle.philosophe: [
    'Le corps que tu construis est la somme de journées ordinaires.',
    'La discipline libère : ce qui est décidé n’est plus à décider.',
    'Progresser lentement n’est pas un défaut du chemin, c’est le chemin.',
  ],
};

/// Toutes les listes de mots, exposées pour les tests d'intégrité
/// (chaque voix a les siens, aucun doublon, ton éditorial).
Map<MentorStyle?, List<String>> get mentorWordCatalog => _mots;

/// Le mot du jour (ou de la semaine), à la voix choisie.
///
/// [aFeter] est la récompense fraîchement gagnée à relayer, s'il y en a
/// une : elle prend la parole, à la voix du style, et son identifiant part
/// avec le mot pour que l'appelant puisse la marquer « dite ».
MentorWord mentorWord({
  required MentorStyle? style,
  required MentorFrequency frequence,
  required DateTime now,
  EarnedReward? aFeter,
}) {
  if (aFeter != null) {
    return MentorWord(
      message: _celebration(style, aFeter),
      celebratedRewardId: aFeter.reward.id,
    );
  }
  final mots = _mots[style] ?? _mots[null]!;
  final periode = switch (frequence) {
    MentorFrequency.quotidienne => dayOfYearIndex(now),
    // La semaine ISO approchée : le jour de l'année ramené à sa semaine.
    // Deux appareils au même jour civil rendent le même mot, c'est tout ce
    // qui est demandé.
    MentorFrequency.hebdomadaire => dayOfYearIndex(now) ~/ 7,
  };
  return MentorWord(message: mots[periode % mots.length]);
}

/// La célébration, dite à la voix du style : même fait, autre ton.
String _celebration(MentorStyle? style, EarnedReward recompense) {
  final label = recompense.reward.label;
  return switch (style) {
    MentorStyle.bienveillant =>
      '« $label », c’est à toi. Prends deux secondes pour le savourer.',
    MentorStyle.exigeant =>
      '« $label » : acquis. C’était le palier, pas le sommet.',
    MentorStyle.athlete => '« $label » au tableau. On enchaîne.',
    MentorStyle.philosophe =>
      '« $label » : la trace visible d’un travail qui ne l’était pas.',
    null => 'Nouveau cap : « $label ». Il est au journal des récompenses.',
  };
}
