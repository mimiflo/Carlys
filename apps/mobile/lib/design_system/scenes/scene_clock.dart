import 'dart:async';

import 'package:flutter/widgets.dart';

/// L'horloge d'une scène animée : un PAS toutes les 1 / [framesPerSecond]
/// seconde, et rien entre deux.
///
/// Un `Ticker` demande une image à chaque battement de l'écran — 120 par
/// seconde sur un écran 120 Hz — pour une scène qui n'en change que 30 :
/// trois réveils du moteur sur quatre pour redire la même image. Ici, seul
/// le pas réveille la scène, et c'est elle qui demande alors son image
/// (`setState`, ou l'arrivée d'une image calculée ailleurs).
///
/// Le temps est ÉCOULÉ, jamais ramené à zéro, et s'arrête avec [stop] :
/// [start] repart d'où l'on s'était arrêté. La cadence est relue à chaque
/// pas ; quand elle change (une scène qui peine descend à 20 puis 15 i/s),
/// l'horloge repart à la nouvelle cadence, sans saut de temps.
///
/// Application en arrière-plan, écran éteint : une minuterie, elle, ne s'y
/// tait pas seule — le `Ticker` le faisait, puisqu'aucune image n'y est
/// plus dessinée. L'horloge suit donc le cycle de vie : elle s'arrête quand
/// les images s'arrêtent (`hidden`, `paused`, `detached`), et repart au
/// retour si la scène la veut toujours.
class SceneClock with WidgetsBindingObserver {
  SceneClock({required this.framesPerSecond, required this.onStep});

  /// Cadence courante, relue à chaque pas.
  final double Function() framesPerSecond;

  /// Appelé à chaque pas, avec le temps de scène, en secondes.
  final void Function(double seconds) onStep;

  Timer? _timer;
  double _seconds = 0;

  /// La scène veut tourner ([start] sans [stop]) — l'application peut
  /// néanmoins la tenir à l'arrêt.
  bool _wanted = false;
  bool _observing = false;

  /// Temps de scène, en secondes : un multiple du pas courant.
  double get seconds => _seconds;

  bool get isRunning => _timer != null;

  void start() {
    _wanted = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (_awake(WidgetsBinding.instance.lifecycleState)) _run();
  }

  /// Les images sont-elles dessinées dans cet état ? Les mêmes états que
  /// `framesEnabled` ; `null` : l'état n'est pas encore connu, l'application
  /// démarre au premier plan.
  static bool _awake(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };

  void stop() {
    _wanted = false;
    _halt();
  }

  /// À appeler au `dispose` du widget : l'horloge cesse d'écouter le cycle
  /// de vie de l'application.
  void dispose() {
    stop();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awake(state)) {
      _halt();
    } else if (_wanted) {
      _run();
    }
  }

  void _run() {
    if (_timer != null) return;
    final fps = framesPerSecond();
    // À la milliseconde, comme les minuteries de Dart : un pas de 33 ms
    // compté comme 1/30 s ferait battre le cœur 1 % trop vite.
    final period = Duration(milliseconds: (1000 / fps).round());
    final from = _seconds;
    _timer = Timer.periodic(period, (timer) {
      // `tick` compte les pas ÉCOULÉS, ratés compris : un pas en retard ne
      // ralentit pas la scène, il la rattrape.
      _seconds = from + timer.tick * period.inMilliseconds / 1000;
      if (framesPerSecond() != fps) {
        _halt();
        _run();
      }
      onStep(_seconds);
    });
  }

  void _halt() {
    _timer?.cancel();
    _timer = null;
  }
}
