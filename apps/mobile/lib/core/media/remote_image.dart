import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_image_cache.dart';

/// Cache des photos distantes — remplacé par un faux dans les tests.
final remoteImageCacheProvider = Provider<RemoteImageCache>(
  (ref) => DiskRemoteImageCache(),
);

/// Octets d'une photo, par URL. `null` = hors d'atteinte, pas une erreur.
///
/// `autoDispose` : une fois la vignette démontée, l'entrée s'efface avec sa
/// référence aux octets. Sans quoi chaque URL vue restait en mémoire pour la
/// vie de l'application, et le budget de 24 Mo du cache en dessous ne
/// bornait plus rien : un long défilement du catalogue coûtait ce que le
/// cache s'était donné tant de mal à éviter. La conservation est le travail
/// du cache (mémoire bornée, puis disque) : rien n'est retéléchargé.
final remoteImageProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>(
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
    // `contain` par défaut : les photos d'exercices sont des détourages —
    // un appel qui oublierait `fit` doit montrer la figure ENTIÈRE, jamais
    // en rogner un morceau avec un `cover` silencieux.
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.decodeWidth,
    super.key,
  });

  final String url;
  final Widget placeholder;
  final BoxFit fit;
  final String? semanticLabel;

  /// Largeur LOGIQUE à laquelle décoder l'image, quand la taille affichée est
  /// connue (vignette de liste, en-tête plein écran). Une photo servie en
  /// haute définition et décodée entière pour un rond de 58 px coûte de la
  /// mémoire et des à-coups au défilement — le décodage suit donc l'affichage.
  final int? decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(remoteImageProvider(url));
    final logicalWidth = decodeWidth;
    return bytes.maybeWhen(
      data: (data) => data == null
          ? placeholder
          : Image.memory(
              data,
              fit: fit,
              semanticLabel: semanticLabel,
              cacheWidth: logicalWidth == null
                  ? null
                  : (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                      .round(),
              // Une image illisible (fichier tronqué) retombe sur le repli
              // plutôt que d'afficher l'icône d'erreur du framework.
              errorBuilder: (_, __, ___) => placeholder,
            ),
      orElse: () => placeholder,
    );
  }
}
