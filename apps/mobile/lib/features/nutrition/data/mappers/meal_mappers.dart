import '../../domain/entities/nutrition.dart';

/// Lecture et écriture des repas et des aliments (`/nutrition/meals`,
/// `/nutrition/foods`), en fonctions PURES : ni Dio, ni enveloppe.
///
/// TOLÉRANTES à la lecture, pour deux raisons :
///  - un serveur d'une version PRÉCÉDENTE ne connaît ni le moment, ni la
///    composition, ni la photo : un champ absent se lit comme « rien »
///    (`null`, liste vide), jamais comme une panne ;
///  - un serveur d'une version SUIVANTE peut servir une valeur que cette
///    application ignore (un moment, une unité) : elle se lit `null`, et
///    l'écran se tait plutôt que d'afficher une valeur fausse.

MealEntry mealFromJson(Map<String, dynamic> row) {
  final components = (row['components'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(componentFromJson)
      .toList(growable: false);
  final photo = row['photo'];
  return MealEntry(
    id: row['id'] as String,
    name: row['name'] as String,
    moment: MealMoment.fromApi(row['moment']),
    kcal: (row['kcal'] as num).toInt(),
    quantity: (row['quantity'] as num?)?.toDouble(),
    quantityUnit: MealQuantityUnit.fromApi(row['quantityUnit'] as String?),
    proteinG: (row['proteinG'] as num?)?.toInt(),
    carbsG: (row['carbsG'] as num?)?.toInt(),
    fatG: (row['fatG'] as num?)?.toInt(),
    eatenAt: DateTime.parse(row['eatenAt'] as String),
    components: components,
    // Un serveur qui ne dirait pas `computed` : la composition le dit.
    computed: row['computed'] as bool? ?? components.isNotEmpty,
    photoUpdatedAt: photo is Map<String, dynamic>
        ? DateTime.tryParse(photo['updatedAt'] as String? ?? '')
        : null,
  );
}

MealComponent componentFromJson(Map<String, dynamic> row) {
  final name = row['name'] as String? ?? '';
  return MealComponent(
    id: row['id'] as String,
    foodCode: (row['foodCode'] as num).toInt(),
    name: name,
    shortName: row['shortName'] as String? ?? name,
    group: row['group'] as String?,
    sourceVersion: row['sourceVersion'] as String?,
    quantityG: (row['quantityG'] as num).toDouble(),
    kcal: (row['kcal'] as num).toDouble(),
    proteinG: (row['proteinG'] as num?)?.toDouble(),
    carbsG: (row['carbsG'] as num?)?.toDouble(),
    fatG: (row['fatG'] as num?)?.toDouble(),
  );
}

Food foodFromJson(Map<String, dynamic> row) {
  final name = row['name'] as String? ?? '';
  final per100g = row['per100g'] as Map<String, dynamic>? ?? const {};
  return Food(
    code: (row['code'] as num).toInt(),
    name: name,
    shortName: row['shortName'] as String? ?? name,
    group: row['group'] as String?,
    per100g: FoodPer100g(
      kcal: (per100g['kcal'] as num?)?.toDouble() ?? 0,
      proteinG: (per100g['proteinG'] as num?)?.toDouble(),
      carbsG: (per100g['carbsG'] as num?)?.toDouble(),
      fatG: (per100g['fatG'] as num?)?.toDouble(),
    ),
  );
}

/// La mention d'une réponse de repas (`meta.source`), `null` quand aucun
/// repas rendu ne porte d'aliment de la base.
FoodAttribution? attributionFromMeta(Object? meta) {
  final source = meta is Map<String, dynamic> ? meta['source'] : null;
  if (source is! Map<String, dynamic>) {
    return null;
  }
  return FoodAttribution(
    attribution: source['attribution'] as String? ?? '',
    license: source['license'] as String? ?? '',
    url: source['url'] as String? ?? '',
  );
}

/// La mention d'une réponse de la base (`meta.source`), version comprise.
///
/// Absente, elle se lit comme une base VIDE : la licence interdit d'afficher
/// une valeur de la table sans sa mention, et sans mention il n'y a rien à
/// afficher.
FoodSource foodSourceFromMeta(Object? meta) {
  final source = meta is Map<String, dynamic> ? meta['source'] : null;
  final row = source is Map<String, dynamic>
      ? source
      : const <String, dynamic>{};
  return FoodSource(
    attribution: row['attribution'] as String? ?? '',
    license: row['license'] as String? ?? '',
    url: row['url'] as String? ?? '',
    version: row['version'] as String?,
  );
}

/// Le corps d'un `POST /nutrition/meals`.
///
/// Les clés facultatives sont ABSENTES, jamais `null` : le serveur accepte
/// l'absence, et un repas composé ne porte AUCUN total — même à `null`, le
/// serveur le refuserait (400), pour qu'aucun des deux ne soit ignoré en
/// silence.
Map<String, dynamic> mealCreationBody(String id, MealWrite write) {
  return {
    'id': id,
    'name': write.name,
    if (write.moment != null) 'moment': write.moment!.apiValue,
    'eatenAt': write.eatenAt.toUtc().toIso8601String(),
    ...switch (write.content) {
      final ManualMealContent manual => _manualCreation(manual),
      ComposedMealContent(:final components) => {
        'components': componentsBody(components),
      },
      KeptCompositionContent() => throw ArgumentError(
        'Un repas neuf n’a pas de composition à garder.',
      ),
    },
  };
}

/// Le corps d'un `PATCH /nutrition/meals/:id`.
///
/// Le nom, le moment et l'heure partent toujours : l'écran montrait l'entrée
/// entière. Pour un repas SAISI, tous les totaux partent aussi, `null`
/// compris — une case vidée veut dire « on ne sait plus », et seul un
/// `null` explicite l'écrit. Pour un repas COMPOSÉ, aucun total : la liste
/// des aliments remplace la composition ([ComposedMealContent]), ou rien ne
/// part des aliments ([KeptCompositionContent]).
Map<String, dynamic> mealCorrectionBody(MealWrite write) {
  return {
    'name': write.name,
    'moment': write.moment?.apiValue,
    'eatenAt': write.eatenAt.toUtc().toIso8601String(),
    ...switch (write.content) {
      final ManualMealContent manual => _manualCorrection(manual),
      ComposedMealContent(:final components) => {
        'components': componentsBody(components),
      },
      KeptCompositionContent() => const <String, dynamic>{},
    },
  };
}

Map<String, dynamic> _manualCreation(ManualMealContent manual) {
  return {
    'kcal': manual.kcal,
    // La paire quantité / unité va entière, ou pas du tout.
    if (manual.quantity != null && manual.quantityUnit != null) ...{
      'quantity': manual.quantity,
      'quantityUnit': manual.quantityUnit!.apiValue,
    },
    if (manual.proteinG != null) 'proteinG': manual.proteinG,
    if (manual.carbsG != null) 'carbsG': manual.carbsG,
    if (manual.fatG != null) 'fatG': manual.fatG,
  };
}

Map<String, dynamic> _manualCorrection(ManualMealContent manual) {
  // La paire est indivisible : à moitié renseignée, elle s'efface en entier
  // plutôt que de partir en 400 pour une saisie que l'écran a empêchée.
  final pair = manual.quantity != null && manual.quantityUnit != null;
  return {
    'kcal': manual.kcal,
    'quantity': pair ? manual.quantity : null,
    'quantityUnit': pair ? manual.quantityUnit!.apiValue : null,
    'proteinG': manual.proteinG,
    'carbsG': manual.carbsG,
    'fatG': manual.fatG,
    // Le repas ÉTAIT composé : la liste vide retire la composition, et le
    // repas redevient saisi à la main avec ces totaux.
    if (manual.clearsComposition) 'components': const <Object>[],
  };
}

List<Map<String, dynamic>> componentsBody(
  List<MealComponentInput> components,
) => [
  for (final line in components)
    {'id': line.id, 'foodCode': line.foodCode, 'quantityG': line.quantityG},
];
