import 'dart:io';

/// Les chaînes d'une liste du contrat partagé
/// (`packages/api-contracts/src/<fichier>`), lues à la source : `flutter
/// test` part de `apps/mobile`, le contrat vit deux étages plus haut. Une
/// liste recopiée à la main dans un test diverge du serveur en silence.
///
/// [bloc] capture, en groupe 1, le texte entre les crochets de la liste ;
/// ses commentaires `/* */` sont ignorés.
List<String> contractStrings(String fichier, RegExp bloc) {
  var directory = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    final contrat = File(
      '${directory.path}/packages/api-contracts/src/$fichier',
    );
    if (contrat.existsSync()) {
      final liste = bloc.firstMatch(contrat.readAsStringSync())!.group(1)!;
      final sansCommentaires = liste.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return [
        for (final match in RegExp(r"'(\w+)'").allMatches(sansCommentaires))
          match.group(1)!,
      ];
    }
    directory = directory.parent;
  }
  throw StateError('Contrat $fichier introuvable.');
}
