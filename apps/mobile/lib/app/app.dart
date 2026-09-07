import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import '../features/settings/domain/app_theme_setting.dart';
import '../features/settings/presentation/controllers/theme_setting_controller.dart';
import 'router/app_router.dart';

/// Racine de l'application : thèmes, localisation et navigation.
class CarlysApp extends ConsumerWidget {
  const CarlysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeSetting = ref.watch(themeSettingProvider);

    return MaterialApp.router(
      title: 'Carlys',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: themeSetting == AppThemeSetting.oledDark
          ? AppTheme.oledDark()
          : AppTheme.dark(),
      themeMode: switch (themeSetting) {
        AppThemeSetting.system => ThemeMode.system,
        AppThemeSetting.light => ThemeMode.light,
        AppThemeSetting.dark || AppThemeSetting.oledDark => ThemeMode.dark,
      },
      // UNE seule langue déclarée, le français : c'est la seule dans laquelle
      // l'application est écrite. Déclarer `en` en plus ne traduisait rien —
      // aucun fichier de traduction n'existe — mais suffisait à faire basculer
      // les composants Material en anglais sur un téléphone réglé en anglais :
      // le sélecteur de date s'ouvrait alors en anglais au milieu d'un écran
      // français. Une langue s'ajoutera ici le jour où elle sera traduite.
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
