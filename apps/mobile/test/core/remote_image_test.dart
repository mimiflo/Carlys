import 'dart:typed_data';

import 'package:carlys_mobile/core/media/remote_image.dart';
import 'package:carlys_mobile/core/media/remote_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG 1×1 valide : de vrais octets, pas un tampon de zéros que le décodeur
/// refuserait — sinon on testerait le chemin d'erreur en croyant tester le bon.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

class _FakeCache implements RemoteImageCache {
  _FakeCache(this._bytes);

  final Uint8List? _bytes;
  final List<String> asked = [];

  @override
  Future<Uint8List?> bytesOf(String url) async {
    asked.add(url);
    return _bytes;
  }
}

Widget _harness(RemoteImageCache cache, {required String url}) {
  return ProviderScope(
    overrides: [remoteImageCacheProvider.overrideWithValue(cache)],
    child: MaterialApp(
      home: RemoteImage(
        url: url,
        placeholder: const Text('repli'),
        semanticLabel: 'Photo',
      ),
    ),
  );
}

void main() {
  testWidgets('photo disponible : elle remplace le repli', (tester) async {
    final cache = _FakeCache(_png);

    await tester.pumpWidget(_harness(cache, url: 'http://s/image/a.png'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('repli'), findsNothing);
    expect(cache.asked, ['http://s/image/a.png']);
  });

  testWidgets('photo hors d’atteinte : le repli reste, sans erreur affichée',
      (tester) async {
    // Hors ligne, une illustration manquante ne doit ni trouer la page ni
    // afficher un message : c'est un ornement, pas une donnée.
    await tester.pumpWidget(_harness(_FakeCache(null), url: 'http://s/x.png'));
    await tester.pumpAndSettle();

    expect(find.text('repli'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le repli tient pendant le chargement', (tester) async {
    await tester.pumpWidget(_harness(_FakeCache(_png), url: 'http://s/a.png'));

    // Première image : la future n'a pas encore abouti.
    expect(find.text('repli'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
