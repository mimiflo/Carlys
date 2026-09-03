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
  evictionTests();
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

  testWidgets('démontée, la vignette libère son entrée de provider',
      (tester) async {
    // Le cache en dessous borne sa mémoire ; la couche provider ne doit pas
    // garder une référence forte aux octets de chaque URL vue. Après
    // démontage, l'entrée disparaît et le budget du cache redevient réel.
    final container = ProviderContainer(
      overrides: [remoteImageCacheProvider.overrideWithValue(_FakeCache(_png))],
    );
    addTearDown(container.dispose);
    Widget app(Widget home) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: home),
        );
    bool held() => container.getAllProviderElements().any(
          (element) => element.origin.from == remoteImageProvider,
        );

    await tester.pumpWidget(
      app(
        const RemoteImage(url: 'http://s/a.png', placeholder: Text('repli')),
      ),
    );
    await tester.pumpAndSettle();
    expect(held(), isTrue);

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(held(), isFalse);
  });

  group('cache réel', () {
    // Le mode démo n'a ni serveur ni stockage objet : ses vignettes voyagent
    // dans le paquet et portent le schéma `asset:`. Le cache doit donc savoir
    // les servir SANS toucher au réseau ni au disque.
    test('schéma asset: : les octets viennent du paquet', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final cache = DiskRemoteImageCache();

      final bytes =
          await cache.bytesOf('${assetImageScheme}assets/muscles/biceps.webp');

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('asset absent : repli silencieux, comme une photo hors d’atteinte',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final cache = DiskRemoteImageCache();

      final bytes =
          await cache.bytesOf('${assetImageScheme}assets/muscles/néant.webp');

      expect(bytes, isNull);
    });
  });
}

/// L'éviction du cache mémoire, observée depuis ses compteurs de test :
/// une image évincée se recharge sans bruit, l'éviction est donc invisible
/// du dehors.
void evictionTests() {
  group('éviction mémoire', () {
    test('le budget est tenu, les plus anciennes partent d’abord', () async {
      // Budget de 40 octets : aucune vignette réelle n'y tient, ce qui force
      // l'éviction à chaque insertion — exactement ce qu'on veut observer.
      final cache = DiskRemoteImageCache(memoryBudgetBytes: 40);
      Future<Object?> putAsset(String name) =>
          cache.bytesOf('$assetImageScheme$name');

      await putAsset('assets/muscles/dos.webp');
      final afterFirst = cache.memoryEntryCount;
      await putAsset('assets/muscles/biceps.webp');

      // L'éviction ne vide JAMAIS tout : la dernière consultée reste posée,
      // même hors budget — un cache qui refuse la seule image affichée à
      // l'écran ne servirait à rien.
      expect(afterFirst, 1);
      expect(cache.memoryEntryCount, 1);
      expect(await putAsset('assets/muscles/dos.webp'), isNotNull);
    });

    test('une image consultée revient en queue d’éviction', () async {
      final cache = DiskRemoteImageCache(memoryBudgetBytes: 1024 * 1024);
      final a =
          await cache.bytesOf('${assetImageScheme}assets/muscles/dos.webp');
      final b =
          await cache.bytesOf('${assetImageScheme}assets/muscles/biceps.webp');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(cache.memoryEntryCount, 2);
      final bytes = cache.memoryBytes;
      // Reconsulter ne doit ni doubler l'occupation ni perdre d'entrée.
      await cache.bytesOf('${assetImageScheme}assets/muscles/dos.webp');
      expect(cache.memoryBytes, bytes);
      expect(cache.memoryEntryCount, 2);
    });
  });
}
