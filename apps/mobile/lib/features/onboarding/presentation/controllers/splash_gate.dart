import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Combien de temps l'écran de démarrage reste affiché, au MINIMUM.
///
/// C'est un plancher, jamais une addition : la restauration de session et
/// la lecture des préférences courent pendant ce temps, et l'application
/// s'ouvre dès que les deux sont satisfaites. Sur un téléphone rapide,
/// l'attente est donc exactement cette durée ; sur un téléphone lent, c'est
/// la restauration qui commande et le plancher ne coûte rien.
///
/// Assez long pour que la marque s'installe, assez court pour ne pas se
/// mettre en travers : au-delà, une page de démarrage devient une porte
/// fermée.
const Duration splashHold = Duration(milliseconds: 2600);

/// Le plancher de l'écran de démarrage est-il écoulé ?
///
/// Séparé de l'étape de parcours et de l'état de session, qui disent ce que
/// l'application SAIT ; celui-ci dit seulement ce qu'elle a le droit de
/// MONTRER. Les mélanger rendrait « étape inconnue » ambigu.
class SplashGate extends Notifier<bool> {
  Timer? _timer;
  bool _disposed = false;

  @override
  bool build() {
    // Une session de test qui coupe les animations ne veut pas non plus
    // d'un temps mort : le plancher tombe avec elles.
    if (_animationsDisabled) {
      return true;
    }
    _timer = Timer(splashHold, () {
      if (!_disposed) {
        state = true;
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    return false;
  }

  /// Ouvre le passage sans attendre — l'écran de démarrage le fait lui-même
  /// quand son animation se termine, ce qui évite de compter deux fois la
  /// même durée si la courbe venait à changer.
  void open() {
    _timer?.cancel();
    if (!state) {
      state = true;
    }
  }
}

bool get _animationsDisabled => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

final splashGateProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);
