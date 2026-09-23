import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../providers/community_tab_state.dart';

/// Le champ de la loupe : il FILTRE l'onglet ouvert, et rien d'autre.
///
/// La Communauté n'énumère personne (`docs/product/community.md`, principes
/// 2 et 3) : on n'y cherche pas des inconnus, on retrouve un prénom dans ce
/// qui est déjà là — ses amis, le classement de sa ligue, les défis.
class CommunitySearchBar extends ConsumerStatefulWidget {
  const CommunitySearchBar({required this.tab, super.key});

  /// L'onglet filtré : c'est lui qui dit ce que le champ cherche.
  final CommunityTab tab;

  @override
  ConsumerState<CommunitySearchBar> createState() => _CommunitySearchBarState();
}

class _CommunitySearchBarState extends ConsumerState<CommunitySearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(communitySearchProvider) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _hint => switch (widget.tab) {
    CommunityTab.defis => 'Filtrer les défis',
    CommunityTab.ligue => 'Chercher un prénom dans ta ligue',
    CommunityTab.amis => 'Chercher parmi tes amis',
  };

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: _controller,
      hint: _hint,
      onChanged: (value) =>
          ref.read(communitySearchProvider.notifier).state = value,
    );
  }
}
