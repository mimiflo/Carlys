import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/repositories/carlys_profile_repository.dart';

/// Dépôt pilotable des tests : enregistre les choix, peut simuler la panne.
class FakeCarlysProfileRepository implements CarlysProfileRepository {
  FakeCarlysProfileRepository({this.failChoose = false});

  bool failChoose;
  final List<CarlysProfile> chosen = [];

  @override
  Future<void> choose(CarlysProfile profile) async {
    if (failChoose) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    chosen.add(profile);
  }
}
