import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/app_theme_setting.dart';

const _storageKey = 'apparence.theme';
const _logger = AppLogger('settings');

/// Préférence de thème, persistée localement (préférence UI, non sensible).
/// Dark-first : démarre sur « Sombre » puis restaure la valeur enregistrée —
/// un échec de lecture est journalisé et retombe sur le défaut, jamais
/// bloquant.
class ThemeSettingController extends Notifier<AppThemeSetting> {
  @override
  AppThemeSetting build() {
    Future<void>.microtask(_restore);
    return AppThemeSetting.dark;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = AppThemeSetting.fromStorage(prefs.getString(_storageKey));
      if (stored != state) {
        state = stored;
      }
    } on Exception catch (error) {
      _logger.warning(
        'Préférence de thème illisible, défaut système appliqué',
        error: error,
      );
    }
  }

  Future<void> setTheme(AppThemeSetting setting) async {
    state = setting;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, setting.storageValue);
    } on Exception catch (error) {
      _logger.warning('Préférence de thème non enregistrée', error: error);
    }
  }
}

final themeSettingProvider =
    NotifierProvider<ThemeSettingController, AppThemeSetting>(
  ThemeSettingController.new,
);
