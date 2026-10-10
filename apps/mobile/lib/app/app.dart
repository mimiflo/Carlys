import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import '../features/settings/domain/app_theme_setting.dart';
import '../features/settings/presentation/controllers/theme_setting_controller.dart';
import 'permissions/first_launch_permissions.dart';
import 'router/app_router.dart';

/// Racine de l'application : thèmes, localisation et navigation.
class CarlysApp extends ConsumerStatefulWidget {
  const CarlysApp({super.key});

  @override
  ConsumerState<CarlysApp> createState() => _CarlysAppState();
}

class _CarlysAppState extends ConsumerState<CarlysApp> {
  @override
  void initState() {
    super.initState();
    // Après la première image : la boîte du système se pose sur l'appli,
    // pas sur un écran encore vide. Une fois par installation.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(firstLaunchPermissionsProvider).requestOnce()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeSetting = ref.watch(themeSettingProvider);

    return MaterialApp.router(
      title: 'Carlys',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Sombre, quel que soit le réglage du téléphone : un seul thème est
      // déclaré, il n'y a donc pas de mode clair vers lequel basculer.
      theme: themeSetting == AppThemeSetting.oledDark
          ? AppTheme.oledDark()
          : AppTheme.dark(),
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
