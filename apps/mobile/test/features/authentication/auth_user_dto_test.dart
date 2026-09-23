import 'package:carlys_mobile/features/authentication/data/dto/auth_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

/// « MEMBRE DEPUIS » : la date de création du compte.
///
/// Le contrat la sert depuis toujours (`authUserSchema.createdAt`), c'est ce
/// DTO qui la jetait — le profil affirmait donc, dans ses commentaires, que
/// l'API ne la donnait pas. Elle est lue désormais, en TOLÉRANT son absence :
/// une ligne d'affichage ne doit jamais faire tomber une connexion.
void main() {
  Map<String, dynamic> json({Object? createdAt}) => {
    'id': 'user-1',
    'email': 'camille@example.com',
    'displayName': 'Camille',
    'emailVerified': true,
    'locale': 'fr',
    'timezone': 'Europe/Paris',
    'createdAt': ?createdAt,
  };

  test('servie : lue en UTC, jusqu’à l’entité', () {
    final user = AuthUserDto.fromJson(
      json(createdAt: '2024-03-12T09:30:00.000Z'),
    ).toEntity();

    expect(user.createdAt, DateTime.utc(2024, 3, 12, 9, 30));
    expect(user.createdAt!.isUtc, isTrue);
  });

  test('absente : nulle, et la connexion tient', () {
    expect(AuthUserDto.fromJson(json()).toEntity().createdAt, isNull);
  });

  test('illisible ou mal typée : nulle, jamais une exception', () {
    expect(
      AuthUserDto.fromJson(json(createdAt: 'hier')).toEntity().createdAt,
      isNull,
    );
    expect(
      AuthUserDto.fromJson(json(createdAt: 1710235800)).toEntity().createdAt,
      isNull,
    );
  });
}
