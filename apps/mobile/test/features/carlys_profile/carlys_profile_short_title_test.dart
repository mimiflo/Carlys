import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// « Ton profil : Stratège » : le titre sans son article, apostrophe
/// typographique comprise (« L’Athlète »).
void main() {
  test('chaque profil perd son article, et seulement lui', () {
    expect(
      {
        for (final profile in CarlysProfile.values)
          profile: carlysProfileContentOf(profile).shortTitle,
      },
      {
        CarlysProfile.constructeur: 'Constructeur',
        CarlysProfile.challenger: 'Challenger',
        CarlysProfile.athlete: 'Athlète',
        CarlysProfile.stratege: 'Stratège',
      },
    );
  });
}
