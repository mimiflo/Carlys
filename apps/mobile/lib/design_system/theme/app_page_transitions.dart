import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Transitions de page du thème : le GESTE de chaque plateforme, la DURÉE du
/// design system.
///
/// Flutter fixe la durée dans chaque `PageTransitionsBuilder` (800 ms pour le
/// fondu Android, 500 ms pour le glissement iOS). Le token `motion.route` en
/// décide autrement, et c'est lui qui fait foi : ce délégué garde le dessin
/// de la transition native (retour prédictif Android, glissement iOS avec son
/// geste de bord) et n'en remplace que le tempo. Le routeur n'a rien à
/// déclarer : chaque page poussée hérite du thème.
abstract final class AppPageTransitions {
  /// Le thème de transitions, plateforme par plateforme, à la durée donnée.
  static PageTransitionsTheme theme(Duration duration) => PageTransitionsTheme(
        builders: {
          for (final entry in _platformBuilders.entries)
            entry.key: _TimedPageTransitionsBuilder(entry.value, duration),
        },
      );

  /// Les mêmes bâtisseurs que Flutter par défaut : seul le tempo change.
  static const Map<TargetPlatform, PageTransitionsBuilder> _platformBuilders = {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
  };
}

/// Délègue le dessin de la transition et impose sa durée.
class _TimedPageTransitionsBuilder extends PageTransitionsBuilder {
  const _TimedPageTransitionsBuilder(this.inner, this.duration);

  final PageTransitionsBuilder inner;
  final Duration duration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      inner.buildTransitions<T>(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
}
