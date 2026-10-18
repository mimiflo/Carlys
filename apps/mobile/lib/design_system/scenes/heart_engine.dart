import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'heart_frame.dart';

/// Moteur du cœur : un ISOLATE dédié calcule les images (déformation,
/// projection, tri, éclairage — voir `computeHeartFrame`), le fil
/// d'interface ne fait plus que les dessiner. C'est ce qui rend le
/// défilement indépendant du cœur : les deux ne partagent plus un budget.
///
/// Les demandes se COALESCENT : si l'isolate est occupé, seule la plus
/// récente attend son tour. Sur un appareil lent, le maillage se met à jour
/// moins souvent — jamais de file d'attente, jamais de retard qui s'accumule.
///
/// Si la plateforme n'a pas d'isolates (web), le moteur se déclare
/// indisponible et le peintre garde son repli synchrone : mêmes pixels.
class HeartEngine {
  /// Dernière image prête. Le widget l'écoute et repeint à son arrivée.
  final ValueNotifier<HeartFrame?> latest = ValueNotifier<HeartFrame?>(null);

  SendPort? _worker;
  HeartFrameRequest? _pending;
  bool _busy = false;
  bool _spawning = false;
  bool _unavailable = false;
  bool _disposed = false;

  /// Demande une image ; la réponse arrive par [latest]. La toute première
  /// demande lance l'isolate — d'ici sa réponse, le peintre calcule seul.
  void request(HeartFrameRequest request) {
    if (_disposed || _unavailable) {
      return;
    }
    _pending = request;
    _flush();
  }

  void _flush() {
    if (_disposed || _busy) {
      return;
    }
    final worker = _worker;
    if (worker == null) {
      unawaited(_spawn());
      return;
    }
    final pending = _pending;
    if (pending == null) {
      return;
    }
    _pending = null;
    _busy = true;
    worker.send(pending);
  }

  /// Un isolate lancé D'AVANCE, que le prochain moteur adopte : l'écran de
  /// démarrage le lance pendant son plancher ([prewarm]). Sans lui, le cœur
  /// de l'accueil lançait le sien à sa première image, et le peintre
  /// calculait seul, sur le fil d'interface, le temps de la poignée de main.
  static _Worker? _spare;

  /// Lance l'isolate du prochain cœur, s'il n'y en a pas déjà un d'avance.
  // ponytail: un isolate préparé qu'aucun cœur n'adopte (accueil jamais
  // ouvert après le démarrage) reste au repos jusqu'à la fin du processus ;
  // le tuer après un délai le jour où ce coût compterait.
  static void prewarm() => _spare ??= _Worker.spawn();

  /// Un isolate attend d'être adopté.
  @visibleForTesting
  static bool get hasSpare => _spare != null;

  _Worker? _own;

  Future<void> _spawn() async {
    if (_spawning || _own != null || _unavailable) {
      return;
    }
    _spawning = true;
    final worker = _own = _spare ?? _Worker.spawn();
    _spare = null;
    worker.onMessage = _onMessage;
    final port = worker.port;
    if (port != null) _onMessage(port);
    final ok = await worker.ready;
    _spawning = false;
    if (!ok) {
      // Pas d'isolates ici (web) : repli synchrone du peintre, pour toujours.
      _unavailable = true;
      _pending = null;
      return;
    }
    if (_disposed) {
      // Libéré pendant le lancement : on éteint ce qui vient de naître.
      worker.kill();
    }
  }

  void _onMessage(Object? message) {
    // Premier message : le port de travail de l'isolate (poignée de main).
    if (message is SendPort) {
      _worker = message;
      _flush();
      return;
    }
    if (message is HeartFrame) {
      _busy = false;
      if (!_disposed) {
        latest.value = message;
      }
      _flush();
    }
  }

  /// Boucle de l'isolate : reçoit un instant, renvoie des tampons prêts.
  static void _workerMain(SendPort out) {
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    inbox.listen((Object? message) {
      if (message is HeartFrameRequest) {
        out.send(computeHeartFrame(message));
      }
    });
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pending = null;
    _own?.kill();
    _own = null;
    _worker = null;
    latest.dispose();
  }
}

/// Un isolate de calcul et sa boîte aux lettres. Né avant d'avoir un
/// moteur (voir [HeartEngine.prewarm]) : il garde la poignée de main
/// ([port]) jusqu'à ce qu'un moteur l'adopte en posant [onMessage].
class _Worker {
  _Worker._(this._inbox) {
    _inbox.listen((message) {
      if (message is SendPort) port = message;
      onMessage?.call(message);
    });
  }

  factory _Worker.spawn() {
    final worker = _Worker._(ReceivePort());
    // `Future.sync` : sans isolates (web), `spawn` lève tout de suite — le
    // refus doit arriver par [ready], pas casser l'appelant.
    worker.ready =
        Future.sync(
          () => Isolate.spawn(
            HeartEngine._workerMain,
            worker._inbox.sendPort,
            debugName: 'carlys-heart',
          ),
        ).then(
          (isolate) {
            worker._isolate = isolate;
            return true;
          },
          onError: (Object _) {
            worker._inbox.close();
            return false;
          },
        );
    return worker;
  }

  final ReceivePort _inbox;
  Isolate? _isolate;

  /// Vrai quand l'isolate est né ; faux sur une plateforme sans isolates.
  late final Future<bool> ready;

  SendPort? port;
  void Function(Object? message)? onMessage;

  void kill() {
    _inbox.close();
    onMessage = null;
    _isolate?.kill(priority: Isolate.immediate);
    // Né après la libération : éteint dès sa naissance.
    unawaited(ready.then((_) => _isolate?.kill(priority: Isolate.immediate)));
  }
}
