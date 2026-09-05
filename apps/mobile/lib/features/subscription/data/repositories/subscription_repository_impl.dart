import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PlanStatus> planStatus() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/subscriptions/me',
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      final subscription = body['subscription'] as Map<String, dynamic>?;
      return PlanStatus(
        planName: body['planName'] as String? ?? 'Gratuit',
        isPremium: body['isPremium'] as bool? ?? false,
        subscription: subscription == null
            ? null
            : SubscriptionInfo(
                planName: subscription['planName'] as String,
                state: SubscriptionState.fromApi(
                  subscription['status'] as String,
                ),
                cancelAtPeriodEnd:
                    subscription['cancelAtPeriodEnd'] as bool? ?? false,
                currentPeriodEnd: subscription['currentPeriodEnd'] == null
                    ? null
                    : DateTime.parse(
                        subscription['currentPeriodEnd'] as String,
                      ),
              ),
      );
    });
  }

  @override
  Future<List<EntitlementEntry>> entitlements() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/entitlements');
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      return (body['entitlements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => EntitlementEntry(
              key: json['key'] as String,
              isActive: json['isActive'] as bool? ?? false,
              expiresAt: json['expiresAt'] == null
                  ? null
                  : DateTime.parse(json['expiresAt'] as String),
            ),
          )
          .toList();
    });
  }

  @override
  Future<OfferCatalog> offers() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/subscriptions/offers',
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      return OfferCatalog(
        checkoutAvailable: body['checkoutAvailable'] as bool? ?? false,
        offers: (body['offers'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => SubscriptionOffer(
                id: json['id'] as String,
                name: json['name'] as String,
                period: OfferPeriod.fromApi(json['period'] as String),
                amountCents: json['amountCents'] as int,
                currency: json['currency'] as String,
                monthlyEquivalentCents: json['monthlyEquivalentCents'] as int,
                trialDays: json['trialDays'] as int? ?? 0,
                isRecommended: json['isRecommended'] as bool? ?? false,
                savingPercent: json['savingPercent'] as int?,
              ),
            )
            .toList(),
      );
    });
  }

  @override
  Future<String> startCheckout({required String offerId, required String id}) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/subscriptions/checkout',
        data: {'id': id, 'offerId': offerId},
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      return body['url'] as String;
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl(ref.watch(dioProvider));
});
