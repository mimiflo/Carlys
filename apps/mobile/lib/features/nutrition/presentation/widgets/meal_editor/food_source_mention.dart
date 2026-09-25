import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';

/// « Source : Anses, Table … Ciqual (version 2020-07-07), Licence Ouverte
/// Etalab 2.0, ciqual.anses.fr. »
///
/// La mention que la licence de la table exige près des valeurs qui en
/// viennent, AVEC la date de mise à jour — la version. UN SEUL dessin pour
/// les deux endroits qui la doivent : la feuille où l'on cherche (une
/// version, celle de la base chargée) et la carte des aliments d'un repas
/// (celle de CHAQUE ligne : deux lignes ajoutées de part et d'autre d'une
/// mise à jour de la table en portent deux).
///
/// L'ADRESSE de la source (`meta.source.url`) finit la mention, lisible en
/// texte, sans son préfixe `https://` : de quoi retrouver la table. Elle
/// n'est pas un lien — la licence demande de citer la source, pas d'y
/// renvoyer, et un appui distrait ouvrirait le navigateur au milieu d'une
/// saisie de repas.
class FoodSourceMention extends StatelessWidget {
  const FoodSourceMention({
    required this.attribution,
    required this.versions,
    super.key,
  });

  final FoodAttribution attribution;
  final Iterable<String> versions;

  @override
  Widget build(BuildContext context) {
    final dates = versions.toSet().toList()..sort();
    final dated = dates.isEmpty
        ? ''
        : ' (version${dates.length > 1 ? 's' : ''} ${dates.join(', ')})';
    final address = _address(attribution.url);
    return Text(
      '${attribution.attribution}$dated, ${attribution.license}'
      '${address.isEmpty ? '' : ', $address'}.',
      style: AppTypography.label.copyWith(
        color: AppColors.darkTextTertiary,
        height: AppTypography.body.height,
      ),
    );
  }

  /// « https://ciqual.anses.fr/ » s'écrit « ciqual.anses.fr » ; une adresse
  /// illisible, telle quelle ; aucune, rien.
  static String _address(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) {
      return url.trim();
    }
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return '${uri.host}$path';
  }
}
