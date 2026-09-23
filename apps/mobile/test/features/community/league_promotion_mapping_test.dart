import 'package:carlys_mobile/features/community/data/mappers/community_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la zone de montée se LIT, elle ne se calcule
/// pas ici — et sa lecture ne casse jamais l'écran de la ligue.
///
/// Le serveur et l'appli ne se déploient pas ensemble : un serveur plus
/// ancien ne sert pas `promotion`, et un bloc mal formé ne doit coûter que
/// la zone, jamais la ligue entière.
void main() {
  /// Une réponse de `GET /community/league`, telle que le serveur la sert.
  Map<String, dynamic> ligue({Object? promotion, bool sansPromotion = false}) =>
      {
        'joined': true,
        'periodKey': '2026-W39',
        'endsAt': '2026-09-28T00:00:00.000Z',
        'division': 'OR',
        'score': 240,
        'standings': [
          {
            'userId': 'moi',
            'displayName': 'Moi',
            'score': 240,
            'rank': 4,
            'isMe': true,
          },
        ],
        'lastResult': null,
        if (!sansPromotion) 'promotion': promotion,
      };

  Map<String, dynamic> zone({
    Object? zoneScore = 200,
    Object? inZone = true,
    Object? pointsToZone = 0,
  }) => {
    'promotedCount': 5,
    'minPlayers': 10,
    'activePlayers': 12,
    'topDivision': false,
    'inZone': inZone,
    'zoneScore': zoneScore,
    'pointsToZone': pointsToZone,
  };

  test('lit chaque champ tel que le serveur l’a calculé', () {
    final promotion = leagueFromJson(ligue(promotion: zone())).promotion;

    expect(promotion, isNotNull);
    expect(promotion!.promotedCount, 5);
    expect(promotion.minPlayers, 10);
    expect(promotion.activePlayers, 12);
    expect(promotion.topDivision, isFalse);
    expect(promotion.inZone, isTrue);
    expect(promotion.zoneScore, 200);
    expect(promotion.pointsToZone, 0);
  });

  test('garde un seuil ABSENT comme tel : un point suffit alors', () {
    // `zoneScore: null` est une information (moins de cinq autres ont
    // marqué), pas un bloc cassé : la zone reste lisible.
    final promotion = leagueFromJson(
      ligue(promotion: zone(zoneScore: null, inZone: false, pointsToZone: 1)),
    ).promotion;

    expect(promotion, isNotNull);
    expect(promotion!.zoneScore, isNull);
    expect(promotion.pointsToZone, 1);
  });

  test('un serveur plus ancien, sans le champ, donne une ligue SANS zone', () {
    final league = leagueFromJson(ligue(sansPromotion: true));

    expect(league.promotion, isNull);
    // Le reste se lit comme avant : l'absence ne coûte que la zone.
    expect(league.score, 240);
    expect(league.me?.rank, 4);
  });

  test('sans adhésion, le serveur envoie null, et on le garde', () {
    expect(leagueFromJson(ligue()).promotion, isNull);
  });

  test('un bloc mal typé donne null, jamais une exception', () {
    // Tout ou rien : lire la moitié d'un bloc inventerait des zéros, et un
    // `inZone` faux par défaut serait une information FAUSSE.
    final malFormes = <Object?>[
      zone(inZone: 'oui'),
      zone(zoneScore: '200'),
      zone(pointsToZone: null),
      {...zone()}..remove('minPlayers'),
      {...zone()}..remove('zoneScore'),
      'dans la zone',
      const [5, 10, 12],
    ];

    for (final bloc in malFormes) {
      expect(
        () => leagueFromJson(ligue(promotion: bloc)),
        returnsNormally,
        reason: '$bloc',
      );
      expect(
        leagueFromJson(ligue(promotion: bloc)).promotion,
        isNull,
        reason: '$bloc',
      );
    }
  });
}
