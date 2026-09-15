/// Maximes de la valeur Discipline.
///
/// « Tiens-tu ce que tu as prévu ? » Le fait mesuré est le respect des séances prévues.
///
/// Les maximes ne sont QUE du texte ici : la valeur leur est attachée à la
/// recomposition, dans `daily_quotes.dart`. Une liste par valeur rend
/// l'entrelacement structurel au lieu de le confier à la vigilance de qui
/// ajoute une entrée, et c'est la seule raison du découpage.
///
/// Les cinq listes doivent garder la MÊME longueur : `entrelacer` refuse de
/// composer autrement, et c'est ce qui garantit que deux jours consécutifs
/// ne servent jamais la même valeur.
library;

const List<String> disciplineQuotes = [
  'La discipline te donne rendez-vous. La motivation, elle, ne '
      'prévient pas.',
  'Décide la veille : le matin, tu n’auras plus qu’à y aller.',
  'Une séance écourtée mais faite tient l’engagement.',
  'Tu n’as pas besoin d’avoir envie. Tu as besoin d’avoir prévu.',
  'Le plan existe pour les jours sans. Les jours avec se débrouillent '
      'seuls.',
  'Commence par l’échauffement. La suite se décide après.',
  'Essayer compte déjà. Le reste vient tout seul.',
  'Prévois la version courte de chaque séance : les jours chargés la '
      'prendront.',
  'Choisis d’avance ce que tu fais si la machine est prise : tu auras un '
      'plan B.',
  'Quand le plan tombe à l’eau, garde l’horaire : c’est lui qui tient '
      'l’habitude.',
  'Une séance abandonnée en cours se reprend le lendemain, pas la semaine '
      'd’après.',
  'Carlys compte les séances que tu termines, pas celles que tu commences.',
];
