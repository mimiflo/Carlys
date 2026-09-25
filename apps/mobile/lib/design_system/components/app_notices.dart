import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../icons/app_icons.dart';
import 'app_notice_layer.dart';
import 'app_popup_card.dart';

/// Le ton d'un message passager : il choisit le glyphe du médaillon, et sa
/// couleur pour une erreur.
enum AppNoticeTone {
  /// Ce qui vient de se passer, sans jugement.
  info,

  /// Un geste a abouti.
  success,

  /// Un geste n'a PAS abouti : le médaillon passe au rouge sémantique.
  error,
}

/// LES MESSAGES PASSAGERS de l'application : une carte centrée, au thème
/// Carlys, qui se ferme d'elle-même.
///
/// ```dart
/// final notices = AppNotices.of(context); // AVANT l'attente
/// await repository.save(entry);
/// notices.show('Mesure enregistrée.', tone: AppNoticeTone.success);
/// ```
///
/// Elle se CAPTURE avant un `await`, exactement comme l'ancien messager
/// Material : le geste peut refermer une feuille, démonter l'écran et son
/// `context` avec, le message s'affiche quand même. C'est possible parce
/// qu'elle vit dans l'overlay RACINE de l'application, qui survit aux
/// feuilles et aux routes : elle s'affiche par-dessus elles, et fonctionne
/// avec n'importe quel `MaterialApp`, sans `Scaffold` ni messager.
///
/// Une seule à la fois : une nouvelle remplace la courante, deux gestes
/// coup sur coup n'empilent pas deux cartes devant le contenu.
///
/// Fermeture : un toucher sur la carte, un toucher ailleurs (qui, sans
/// action, atteint aussi l'écran : un simple message ne pose pas de voile ;
/// avec une action, le voile arrête le doigt), le retour arrière d'Android,
/// ou le minuteur ([displayDuration], [actionDisplayDuration],
/// [detailDisplayDuration]). Avec une action ou une ligne à recopier, et la
/// navigation d'accessibilité active, la popup attend un geste : on choisit,
/// ou on a fini de noter.
@immutable
class AppNotices {
  const AppNotices._(this._overlay);

  /// Le messager de l'application qui contient [context].
  factory AppNotices.of(BuildContext context) =>
      AppNotices._(Overlay.of(context, rootOverlay: true));

  /// Comme [AppNotices.of], ou `null` hors de toute application (aucun
  /// overlay au-dessus de [context]).
  static AppNotices? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : AppNotices._(overlay);
  }

  /// Le temps de lire une phrase courte, puis la popup s'en va.
  static const Duration displayDuration = Duration(seconds: 3);

  /// Plus long quand la popup PROPOSE quelque chose : il faut lire, puis
  /// décider.
  static const Duration actionDisplayDuration = Duration(seconds: 6);

  /// Plus long encore quand elle porte une ligne à RECOPIER (un code
  /// d'erreur) : lire la phrase, puis noter le code ou faire une capture.
  /// Trois secondes ne laissaient le temps que de voir qu'il y en avait un.
  static const Duration detailDisplayDuration = Duration(seconds: 10);

  /// Le bouton qui renonce à l'action proposée.
  static const String laterLabel = 'Plus tard';

  final OverlayState _overlay;

  /// La popup affichée, par overlay : c'est ce qui en garantit une seule.
  static final Expando<_NoticeSlot> _current = Expando<_NoticeSlot>();

  /// Affiche [message], sous [title] s'il y en a un.
  ///
  /// [icon] remplace le glyphe du ton. [actionLabel] et [onAction] vont
  /// ensemble : la popup propose alors l'action, et « Plus tard ».
  /// [detail] ajoute sous le message une ligne à recopier (un code), que
  /// [detailSemanticsLabel] dit autrement aux lecteurs d'écran au besoin.
  void show(
    String message, {
    String? title,
    AppNoticeTone tone = AppNoticeTone.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    String? detail,
    String? detailSemanticsLabel,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'Une action se donne avec son libellé ET son geste.',
    );
    // L'application a été démontée pendant l'attente : personne à prévenir.
    if (!_overlay.mounted) return;
    _current[_overlay]?.discard();

    final hasAction = actionLabel != null && onAction != null;
    final slot = _NoticeSlot(_overlay);
    final entry = OverlayEntry(
      builder: (_) => AppNoticeLayer(
        key: slot.key,
        onClosed: slot.discard,
        notice: AppNoticeContent(
          message: message,
          title: title,
          detail: detail,
          detailSemanticsLabel: detailSemanticsLabel,
          icon: icon ?? _iconOf(tone),
          tone: tone == AppNoticeTone.error
              ? AppPopupTone.danger
              : AppPopupTone.brand,
          autoClose: hasAction
              ? actionDisplayDuration
              : (detail != null ? detailDisplayDuration : displayDuration),
          laterLabel: laterLabel,
          actionLabel: hasAction ? actionLabel : null,
          onAction: hasAction ? onAction : null,
        ),
      ),
    );
    slot.entry = entry;
    _current[_overlay] = slot;
    // Demandée PENDANT une construction (un écouteur de fournisseur qui se
    // déclenche en plein rendu), l'insertion attend la fin de l'image :
    // l'overlay ne se reconstruit pas au milieu d'une autre construction.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) => slot.insert());
    } else {
      slot.insert();
    }
  }

  /// Fait partir la popup affichée, s'il y en a une.
  void hide() => _current[_overlay]?.close();

  static IconData _iconOf(AppNoticeTone tone) => switch (tone) {
    AppNoticeTone.info => AppIcons.noticeInfo,
    AppNoticeTone.success => AppIcons.noticeSuccess,
    AppNoticeTone.error => AppIcons.noticeError,
  };
}

/// Une popup affichée dans un overlay : son entrée, et la clé qui permet de
/// la faire partir en douceur.
class _NoticeSlot {
  _NoticeSlot(this.overlay);

  final OverlayState overlay;
  final GlobalKey<AppNoticeLayerState> key = GlobalKey<AppNoticeLayerState>();
  OverlayEntry? entry;
  bool _inserted = false;

  /// Pose la popup, sauf si elle a été remplacée ou fermée entre-temps, ou
  /// si l'application a été démontée.
  void insert() {
    final entry = this.entry;
    if (entry == null || _inserted) return;
    if (!overlay.mounted) {
      discard();
      return;
    }
    _inserted = true;
    overlay.insert(entry);
  }

  /// Départ animé ; retrait immédiat si la carte n'est pas (plus) montée.
  void close() {
    final layer = key.currentState;
    if (layer == null) {
      discard();
    } else {
      layer.close();
    }
  }

  /// Retrait immédiat, sans animation : la popup est remplacée, ou elle a
  /// fini de partir. Sans effet la seconde fois.
  void discard() {
    if (AppNotices._current[overlay] == this) {
      AppNotices._current[overlay] = null;
    }
    final entry = this.entry;
    this.entry = null;
    if (entry == null) return;
    if (_inserted) entry.remove();
    entry.dispose();
  }
}
