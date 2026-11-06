import 'package:carlys_mobile/features/nutrition/data/datasources/glycemic_index_pack.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/glycemic_food.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE TABLEAU EST LA TABLE PUBLIÉE, rien d'autre.
///
/// Les lignes ci-dessous sont la Table 1 d'Atkinson, Foster-Powell et
/// Brand-Miller (Diabetes Care 2008), traduite, telle qu'elle a été remise :
/// moyenne ± erreur standard, * = des variétés à IG bas existent, † =
/// moyenne de toutes les données. Le pack embarqué doit en être la copie
/// exacte : une valeur ajoutée, estimée ou mal recopiée fait rougir la CI.
const _source = {
  GlycemicCategory.breadsCereals:
      'pain blanc de blé* 75±2 ; pain complet 74±2 ; pain aux céréales '
      'spéciales 53±2 ; pain de blé sans levain 70±5 ; roti de blé 62±3 ; '
      'chapati 52±4 ; tortilla de maïs 46±4 ; riz blanc bouilli* 73±4 ; riz '
      'complet bouilli 68±4 ; orge 28±2 ; spaghetti blancs 49±2 ; spaghetti '
      'complets 48±5 ; nouilles de riz† 53±7 ; nouilles udon 55±7 ; '
      'couscous† 65±4',
  GlycemicCategory.breakfastCereals:
      'cornflakes 81±6 ; biscuits de flocons de blé 69±2 ; porridge flocons '
      'd\'avoine 55±2 ; porridge d\'avoine instantané 79±3 ; bouillie de riz '
      '(congee) 78±9 ; bouillie de millet 67±5 ; muesli 57±2',
  GlycemicCategory.fruits:
      'pomme crue† 36±2 ; orange crue† 43±3 ; banane crue† 51±3 ; ananas cru '
      '59±8 ; mangue crue† 51±5 ; pastèque crue 76±4 ; dattes crues 42±4 ; '
      'pêches en conserve† 43±5 ; confiture de fraise 49±3 ; jus de pomme '
      '41±2 ; jus d\'orange 50±2',
  GlycemicCategory.vegetables:
      'pomme de terre bouillie 78±4 ; purée instantanée 87±3 ; frites 63±5 ; '
      'carottes bouillies 39±4 ; patate douce bouillie 63±6 ; potiron bouilli '
      '64±7 ; banane plantain/verte 55±6 ; taro bouilli 53±2 ; soupe de '
      'légumes 48±5 ; maïs doux 52±5',
  GlycemicCategory.dairy:
      'lait entier 39±3 ; lait écrémé 37±4 ; glace 51±3 ; yaourt aux fruits '
      '41±2 ; lait de soja 34±4 ; lait de riz 86±7',
  GlycemicCategory.legumes:
      'pois chiches 28±9 ; haricots rouges 24±4 ; lentilles 32±5 ; soja 16±1',
  GlycemicCategory.snacks:
      'chocolat 40±3 ; pop-corn 65±5 ; chips 56±3 ; soda 59±3 ; galettes de '
      'riz soufflé 87±2',
  GlycemicCategory.sugars:
      'fructose 15±4 ; saccharose 65±4 ; glucose 103±3 ; miel 61±3',
};

/// Une entrée de la source, lue comme on la lit : « nom[*|†] moyenne±sem ».
List<String> _attendus() {
  final pattern = RegExp(r'^(.+?)([*†]?) (\d+)±(\d+)$');
  return [
    for (final MapEntry(key: category, value: line) in _source.entries)
      for (final item in line.split(' ; '))
        () {
          final m = pattern.firstMatch(item.trim())!;
          final name = m[1]!;
          final mark = switch (m[2]) {
            '*' => GlycemicMark.lowGiVarieties,
            '†' => GlycemicMark.allDataAverage,
            _ => null,
          };
          return _ligne(
            name[0].toUpperCase() + name.substring(1),
            category,
            int.parse(m[3]!),
            int.parse(m[4]!),
            mark,
          );
        }(),
  ];
}

String _ligne(
  String name,
  GlycemicCategory category,
  int gi,
  int sem,
  GlycemicMark? mark,
) => '$name | ${category.name} | $gi ± $sem | ${mark?.symbol ?? ''}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetGlycemicIndexPackCache);
  tearDown(resetGlycemicIndexPackCache);

  test('62 aliments, ni plus ni moins', () async {
    expect(await loadGlycemicIndexPack(), hasLength(62));
    expect(_attendus(), hasLength(62));
  });

  test('CHAQUE VALEUR EST CELLE DE LA SOURCE, dans son ordre', () async {
    final pack = await loadGlycemicIndexPack();
    expect([
      for (final f in pack) _ligne(f.name, f.category, f.gi, f.sem, f.mark),
    ], _attendus());
  });

  test('chaque catégorie a ses aliments, et les noms sont uniques', () async {
    final pack = await loadGlycemicIndexPack();
    final compte = <GlycemicCategory, int>{
      for (final c in GlycemicCategory.values)
        c: pack.where((f) => f.category == c).length,
    };
    expect(compte, {
      GlycemicCategory.breadsCereals: 15,
      GlycemicCategory.breakfastCereals: 7,
      GlycemicCategory.fruits: 11,
      GlycemicCategory.vegetables: 10,
      GlycemicCategory.dairy: 6,
      GlycemicCategory.legumes: 4,
      GlycemicCategory.snacks: 5,
      GlycemicCategory.sugars: 4,
    });
    expect(pack.map((f) => f.name).toSet(), hasLength(pack.length));
  });

  test('les trois niveaux sont représentés', () async {
    final pack = await loadGlycemicIndexPack();
    expect(pack.map((f) => f.level).toSet(), GlycemicLevel.values.toSet());
  });
}
