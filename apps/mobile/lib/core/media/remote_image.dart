import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_image_cache.dart';

/// Cache des photos distantes — remplacé par un faux dans les tests.
final remoteImageCacheProvider = Provider<RemoteImageCache>(
  (ref) => DiskRemoteImageCache(),
);

/// Octets d'une photo, par URL. `null` = hors d'atteinte, pas une erreur.
final remoteImageProvider = FutureProvider.family<Uint8List?, String>(
  (ref, url) => ref.watch(remoteImageCacheProvider).bytesOf(url),
);

/// Photo distante, avec son repli.
///
/// [placeholder] s'affiche pendant le chargement ET si la photo est hors
/// d'atteinte : hors ligne, une illustration manquante ne doit pas laisser un
/// trou ni un message d'erreur, juste la vignette de marque. C'est un ornement,
/// pas une donnée.
class RemoteImage extends ConsumerWidget {
  const RemoteImage({
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String url;
  final Widget placeholder;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(remoteImageProvider(url));
    return bytes.maybeWhen(
      data: (data) => data == null
          ? placeholder
          : Image.memory(
              data,
              fit: fit,
              semanticLabel: semanticLabel,
              // Une image illisible (fichier tronqué) retombe sur le repli
              // plutôt que d'afficher l'icône d'erreur du framework.
              errorBuilder: (_, __, ___) => placeholder,
            ),
      orElse: () => placeholder,
    );
  }
}
