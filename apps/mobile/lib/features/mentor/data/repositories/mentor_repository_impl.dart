import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/repositories/mentor_repository.dart';

/// Voix du Mentor servie par l'API — le champ vit sur `PATCH /users/me`,
/// comme le profil Carlys : même chemin, même idempotence.
class MentorRepositoryImpl implements MentorRepository {
  MentorRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> chooseStyle(MentorStyle style) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {'mentorStyle': style.wire},
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final mentorRepositoryProvider = Provider<MentorRepository>(
  (ref) => MentorRepositoryImpl(ref.watch(dioProvider)),
);
