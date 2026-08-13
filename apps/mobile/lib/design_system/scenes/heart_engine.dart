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

  Isolate? _isolate;
  SendPort? _worker;
  ReceivePort? _inbox;
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

  Future<void> _spawn() async {
    if (_spawning || _isolate != null || _unavailable) {
      return;
    }
    _spawning = true;
    final inbox = ReceivePort();
    inbox.listen(_onMessage);
    try {
      _isolate = await Isolate.spawn(
        _workerMain,
        inbox.sendPort,
        debugName: 'carlys-heart',
      );
    } on Object {
      // Pas d'isolates ici (web) : repli synchrone du peintre, pour toujours.
      inbox.close();
      _unavailable = true;
      _pending = null;
      return;
    } finally {
      _spawning = false;
    }
    _inbox = inbox;
    if (_disposed) {
      // Libéré pendant le lancement : on éteint ce qui vient de naître.
      inbox.close();
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
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
    _inbox?.close();
    _inbox = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _worker = null;
    latest.dispose();
  }
}
