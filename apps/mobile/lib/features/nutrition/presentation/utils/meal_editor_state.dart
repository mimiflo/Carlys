/// L'ÉTAT de l'écran « Ajouter / Modifier ce repas », sans Riverpod : ce que
/// la personne a sous les yeux, et ce qu'on en déduit.
///
/// Les cases de saisie y sont gardées en TEXTE, telles qu'elles sont
/// tapées : « 1,5 », une case vide, une saisie hors bornes. C'est
/// l'enregistrement qui les lit ([toWrite]) ; avant, l'écran doit pouvoir
/// montrer une saisie fautive sans la perdre.
library;

import '../../domain/entities/nutrition.dart';
import '../../domain/services/meal_composition.dart';

/// Ce que fait l'écran en ce moment : la saisie, ou un geste qui l'attend
/// (l'enregistrement, la suppression, la préparation d'une photo neuve).
enum MealEditorPhase { editing, saving, deleting, preparingPhoto }

class MealEditorState {
  const MealEditorState({
    required this.id,
    required this.name,
    required this.eatenAt,
    required this.unit,
    this.original,
    this.moment,
    this.lines = const [],
    this.linesChanged = false,
    this.kcalText = '',
    this.proteinText = '',
    this.carbsText = '',
    this.fatText = '',
    this.quantityText = '',
    this.attribution,
    this.photo = const KeepMealPhoto(),
    this.phase = MealEditorPhase.editing,
    this.showErrors = false,
  });

  /// Un repas NEUF, sous un identifiant né sur l'appareil à l'ouverture.
  factory MealEditorState.fresh({
    required String id,
    required DateTime eatenAt,
  }) => MealEditorState(
    id: id,
    name: '',
    eatenAt: eatenAt,
    unit: MealQuantityUnit.gram,
  );

  /// Un repas ENREGISTRÉ, rouvert pour être corrigé : l'écran le montre en
  /// entier, et c'est ce qu'il montre qui s'enregistrera.
  factory MealEditorState.fromMeal(
    MealEntry meal, {
    FoodAttribution? attribution,
  }) => MealEditorState(
    id: meal.id,
    original: meal,
    name: meal.name,
    moment: meal.moment,
    eatenAt: meal.eatenAt.toLocal(),
    unit: meal.quantityUnit ?? MealQuantityUnit.gram,
    lines: [for (final part in meal.components) MealLine.fromComponent(part)],
    kcalText: '${meal.kcal}',
    proteinText: _integer(meal.proteinG),
    carbsText: _integer(meal.carbsG),
    fatText: _integer(meal.fatG),
    quantityText: formatQuantityInput(meal.quantity),
    attribution: attribution,
  );

  /// L'identifiant du repas : celui du serveur, ou l'UUID né sur l'appareil.
  final String id;

  /// Le repas tel qu'il a été lu ; `null` pour un repas neuf.
  final MealEntry? original;
  final String name;

  /// Le moment CHOISI ; `null` tant que personne n'a choisi (voir
  /// [displayedMoment]).
  final MealMoment? moment;

  /// L'instant du repas, en heure LOCALE : c'est celle que la personne règle.
  final DateTime eatenAt;
  final List<MealLine> lines;

  /// Vrai dès qu'un aliment a été ajouté, retiré ou requantifié : la
  /// composition part alors en entier, et les totaux affichés sont l'aperçu.
  final bool linesChanged;
  final String kcalText;
  final String proteinText;
  final String carbsText;
  final String fatText;
  final String quantityText;
  final MealQuantityUnit unit;

  /// La mention de la base d'aliments, à afficher près des valeurs qui en
  /// viennent.
  final FoodAttribution? attribution;

  /// Ce qui arrivera à la photo à l'ENREGISTREMENT : rien, une photo neuve
  /// (déjà préparée), ou son retrait. Rien ne part avant.
  final MealPhotoChange photo;
  final MealEditorPhase phase;

  /// Vrai après une première tentative d'enregistrement : les erreurs de
  /// saisie s'affichent alors, et pas avant (une case vide n'est pas une
  /// faute tant qu'on n'a pas fini).
  final bool showErrors;

  bool get isNew => original == null;

  /// Le repas a des aliments : ses totaux se calculent, ils ne se tapent pas.
  bool get isComposed => lines.isNotEmpty;

  /// Le repas ENREGISTRÉ avait des aliments.
  bool get wasComposed => original?.components.isNotEmpty ?? false;
  bool get isBusy => phase != MealEditorPhase.editing;

  /// Un ENVOI est en cours (enregistrement, suppression) : ce qui part est
  /// déjà figé, donc la saisie l'est aussi. Pendant la préparation d'une
  /// photo, au contraire, rien n'est parti : on peut continuer d'écrire.
  bool get isSending =>
      phase == MealEditorPhase.saving || phase == MealEditorPhase.deleting;

  /// La photo que la vignette MONTRE : la date de celle du serveur, tant
  /// qu'on ne l'a ni remplacée ni retirée ; `null` sinon (la vignette
  /// montre alors la photo neuve, ou le dessin violet).
  DateTime? get savedPhotoAt => switch (photo) {
    KeepMealPhoto() => original?.photoUpdatedAt,
    NewMealPhoto() || RemoveMealPhoto() => null,
  };

  /// Le repas a une photo, ou en aura une à l'enregistrement.
  bool get hasPhoto => photo is NewMealPhoto || savedPhotoAt != null;

  /// Le moment choisi, sinon celui que l'heure propose : pour un repas neuf,
  /// et pour un repas noté avant que le moment existe. Il s'enregistre avec
  /// le repas.
  MealMoment get displayedMoment => moment ?? MealMoment.suggestFor(eatenAt);

  /// Les totaux d'un repas composé : ceux du serveur tant que la
  /// composition n'a pas bougé, l'aperçu calculé ici dès qu'elle bouge.
  MealTotals get totals {
    final saved = original;
    if (saved != null && saved.computed && !linesChanged) {
      return MealTotals(
        kcal: saved.kcal,
        proteinG: saved.proteinG,
        carbsG: saved.carbsG,
        fatG: saved.fatG,
        quantityG:
            saved.quantity ??
            lines.fold(0, (sum, line) => sum + line.quantityG),
      );
    }
    return compositionPreview(lines);
  }

  MealEditorState copyWith({
    String? name,
    MealMoment? moment,
    DateTime? eatenAt,
    List<MealLine>? lines,
    bool? linesChanged,
    String? kcalText,
    String? proteinText,
    String? carbsText,
    String? fatText,
    String? quantityText,
    MealQuantityUnit? unit,
    FoodAttribution? attribution,
    MealPhotoChange? photo,
    MealEditorPhase? phase,
    bool? showErrors,
  }) => MealEditorState(
    id: id,
    original: original,
    name: name ?? this.name,
    moment: moment ?? this.moment,
    eatenAt: eatenAt ?? this.eatenAt,
    lines: lines ?? this.lines,
    linesChanged: linesChanged ?? this.linesChanged,
    kcalText: kcalText ?? this.kcalText,
    proteinText: proteinText ?? this.proteinText,
    carbsText: carbsText ?? this.carbsText,
    fatText: fatText ?? this.fatText,
    quantityText: quantityText ?? this.quantityText,
    unit: unit ?? this.unit,
    attribution: attribution ?? this.attribution,
    photo: photo ?? this.photo,
    phase: phase ?? this.phase,
    showErrors: showErrors ?? this.showErrors,
  );

  /// Ce qui s'écrit, lu dans les cases. À n'appeler que sur un état VALIDE
  /// (`validateMealEditor`) : une case illisible y vaut « inconnu ».
  MealWrite toWrite() {
    final MealContent content;
    if (isComposed) {
      content = !isNew && wasComposed && !linesChanged
          ? const KeptCompositionContent()
          : ComposedMealContent([for (final line in lines) line.toInput()]);
    } else {
      final quantity = parseDecimalInput(quantityText);
      content = ManualMealContent(
        kcal: int.parse(kcalText.trim()),
        proteinG: int.tryParse(proteinText.trim()),
        carbsG: int.tryParse(carbsText.trim()),
        fatG: int.tryParse(fatText.trim()),
        quantity: quantity,
        // La paire est indivisible : sans nombre, l'unité ne part pas.
        quantityUnit: quantity == null ? null : unit,
        clearsComposition: wasComposed,
      );
    }
    return MealWrite(
      name: name.trim(),
      moment: displayedMoment,
      eatenAt: eatenAt,
      content: content,
    );
  }

  static String _integer(int? value) => value == null ? '' : '$value';
}

/// La virgule est la séparatrice décimale française : l'accepter évite un
/// refus incompréhensible sur un clavier numérique français. Vide ou
/// illisible : `null`.
double? parseDecimalInput(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  return text.isEmpty ? null : double.tryParse(text);
}

/// Une quantité telle qu'elle s'écrit dans une case : sans décimale quand
/// elle est entière, à la virgule sinon, sans zéro de fin (« 1,5 », jamais
/// « 1.50 »).
String formatQuantityInput(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}
