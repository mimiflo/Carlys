/// Cycle de vie de l'application, simulé comme la PLATEFORME le fait.
///
/// Les états passent par le canal système `flutter/lifecycle`, exactement
/// comme sur un téléphone, et dans le même ordre : `AppLifecycleListener`
/// vérifie chaque transition et refuserait un saut direct de « en pause » à
/// « au premier plan ».
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'utilisateur quitte l'application (le navigateur de paiement s'ouvre
/// par-dessus), puis y revient.
Future<void> leaveAndComeBack(WidgetTester tester) async {
  const roundTrip = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];
  for (final state in roundTrip) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage(state.toString()),
      (_) {},
    );
  }
  await tester.pump();
}
