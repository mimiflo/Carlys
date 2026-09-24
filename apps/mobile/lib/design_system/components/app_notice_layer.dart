import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import 'app_button.dart';
import 'app_popup_card.dart';
import 'app_popup_layout.dart';

/// Ce qu'affiche un message passager : le contenu de la carte et ses règles
/// de fermeture, déjà résolus par `AppNotices.show`.
@immutable
class AppNoticeContent {
  const AppNoticeContent({
    required this.message,
    required this.icon,
    required this.tone,
    required this.autoClose,
    required this.laterLabel,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData icon;
  final AppPopupTone tone;

  /// Au bout de combien de temps la popup se ferme d'elle-même.
  final Duration autoClose;

  /// Le bouton qui renonce à l'action (« Plus tard »).
  final String laterLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction => actionLabel != null && onAction != null;
}

/// L'entrée d'overlay d'un message passager : le voile, la carte centrée,
/// et tout ce qui la fait vivre puis partir.
///
/// **Interne au design system**, et non exporté : les écrans passent par
/// `AppNotices`. Le minuteur et l'animation vivent dans l'état de ce widget,
/// si bien que démonter l'overlay les éteint avec lui : aucune minuterie ne
/// survit à la scène qui l'a lancée.
class AppNoticeLayer extends StatefulWidget {
  const AppNoticeLayer({
    required this.notice,
    required this.onClosed,
    super.key,
  });

  final AppNoticeContent notice;

  /// Appelé quand la popup a fini de partir : l'entrée peut être retirée.
  final VoidCallback onClosed;

  @override
  State<AppNoticeLayer> createState() => AppNoticeLayerState();
}

class AppNoticeLayerState extends State<AppNoticeLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _timer;
  ChildBackButtonDispatcher? _back;
  bool _started = false;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Durée nulle quand les animations sont réduites : la popup est alors
    // entière dès la première image.
    _controller.duration = AppMotion.resolve(context, AppMotion.normal);
    unawaited(_controller.forward());
    _armTimer();
    _listenBackButton();
  }

  /// La fermeture automatique, comme un message passager doit en avoir une.
  ///
  /// Sauf une exception, reprise de la barre de message Material : une
  /// popup qui PROPOSE quelque chose reste affichée tant que la navigation
  /// d'accessibilité est active. Un lecteur d'écran met plus de six
  /// secondes à atteindre le bouton ; lui retirer l'action pendant qu'il y
  /// va, c'est la lui refuser.
  void _armTimer() {
    final notice = widget.notice;
    if (notice.hasAction && MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _timer = Timer(notice.autoClose, close);
  }

  /// Le retour arrière d'Android ferme la popup avant de quitter l'écran.
  ///
  /// Possible dès que l'application passe par un `Router` (celle de Carlys,
  /// avec go_router) : le répartiteur de retour accepte un enfant PRIORITAIRE.
  /// Sans routeur, le retour garde son comportement ordinaire et la popup se
  /// ferme d'elle-même : la navigation n'est jamais cassée.
  void _listenBackButton() {
    final root = Router.maybeOf(context)?.backButtonDispatcher;
    if (root == null) return;
    _back = root.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  /// Pris par la popup tant qu'elle est là ; déjà sur le départ, elle
  /// laisse le retour à l'écran.
  Future<bool> _onBack() {
    if (_closing) return SynchronousFuture<bool>(false);
    close();
    return SynchronousFuture<bool>(true);
  }

  /// Fait partir la popup, puis prévient qu'elle est partie. Sans effet si
  /// elle part déjà.
  void close() {
    if (_closing || !mounted) return;
    _timer?.cancel();
    setState(() => _closing = true);
    _controller.reverseDuration = AppMotion.resolve(context, AppMotion.fast);
    unawaited(_controller.reverse().then((_) => widget.onClosed()));
  }

  void _act() {
    final onAction = widget.notice.onAction;
    close();
    onAction?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    final back = _back;
    if (back != null) {
      back.removeCallback(_onBack);
      back.parent.forget(back);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final actionLabel = notice.actionLabel;
    return IgnorePointer(
      // Déjà sur le départ : le doigt atteint l'écran tout de suite.
      ignoring: _closing,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Le voile, SEULEMENT quand la popup propose un choix (« Voir le
          // défi » / « Plus tard ») : il ferme au toucher sans que le doigt
          // atteigne l'écran. Un simple message, lui, ne vole jamais le
          // toucher suivant : en pleine séance, « Série supprimée. » ne doit
          // pas coûter un geste. Muet pour les lecteurs d'écran : la carte
          // porte déjà l'action « fermer ».
          // Sans choix à faire, un voile LÉGER et purement visuel : il
          // détache la carte des cartes de l'écran, et laisse passer le
          // doigt.
          if (!notice.hasAction)
            IgnorePointer(
              child: FadeTransition(
                opacity: _controller,
                child: const ColoredBox(color: AppColors.darkScrimSoft),
              ),
            ),
          if (notice.hasAction)
            ExcludeSemantics(
              child: FadeTransition(
                opacity: _controller,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  child: const ColoredBox(color: AppColors.darkScrim),
                ),
              ),
            ),
          AppPopupLayout(
            child: AppPopupTransition(
              animation: _controller,
              child: Semantics(
                container: true,
                liveRegion: true,
                onDismiss: close,
                // Sans voile, un toucher ailleurs agit sur l'écran ET
                // referme le message : il a été vu.
                child: TapRegion(
                  onTapOutside: notice.hasAction ? null : (_) => close(),
                  child: GestureDetector(
                    onTap: close,
                    child: AppPopupCard(
                      icon: notice.icon,
                      tone: notice.tone,
                      title: notice.title,
                      message: notice.message,
                      actions: [
                        if (actionLabel != null) ...[
                          AppButton(label: actionLabel, onPressed: _act),
                          AppButton(
                            label: notice.laterLabel,
                            variant: AppButtonVariant.ghost,
                            onPressed: close,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
