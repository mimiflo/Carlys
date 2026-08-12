import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/carlys_profile.dart';
import '../../domain/repositories/carlys_profile_repository.dart';

/// Profil Carlys servi par l'API — le champ vit sur `PATCH /users/me`,
/// comme le reste de l'identité.
class CarlysProfileRepositoryImpl implements CarlysProfileRepository {
  CarlysProfileRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> choose(CarlysProfile profile) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {'carlysProfile': profile.wire},
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final carlysProfileRepositoryProvider = Provider<CarlysProfileRepository>(
  (ref) => CarlysProfileRepositoryImpl(ref.watch(dioProvider)),
);
