import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Une caméra simulée : chaque `start` est compté, et refusé tant que
/// l'autorisation n'est pas donnée — comme Android après un « Refuser ».
class FakeCamera extends MobileScannerPlatform {
  bool authorized = false;
  int starts = 0;
  int stops = 0;

  /// Retient le démarrage tant qu'il n'est pas complété : la boîte
  /// d'autorisation encore ouverte.
  Completer<void>? hold;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    await hold?.future;
    if (!authorized) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(1280, 720),
    );
  }

  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
}
