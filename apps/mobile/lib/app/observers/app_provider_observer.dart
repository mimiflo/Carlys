import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';

/// Journalise le cycle de vie des providers en debug uniquement.
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  static const _logger = AppLogger('riverpod');

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _logger.error(
      'Provider en échec: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      _logger.debug('Mise à jour: ${provider.name ?? provider.runtimeType}');
    }
  }
}
