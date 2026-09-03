import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';
import 'carlys_profile_content.dart';

/// Carte d'un profil, fidèle à la maquette : illustration à gauche, titre en
/// capitales, description courte, chevron cerclé. Les quatre cartes portent
/// le liseré violet léger du thème ; le profil ACTUEL ajoute son badge et un
/// segment accent qui FAIT LE TOUR de la carte — le même langage visuel que
/// l'offre d'abonnement mise en avant. C'est un état, pas un classement.
class CarlysProfileCard extends StatefulWidget {
  const CarlysProfileCard({
    required this.profile,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  final CarlysProfile profile;
  final bool isCurrent;
  final VoidCallback onTap;

  /// Largeur de la case d'illustration : c'est aussi la largeur LOGIQUE à
  /// laquelle l'image se décode, quel que soit l'appelant (l'onboarding pose
  /// les mêmes cartes dans la même case).
  static const double imageWidth = 116;
  static const double _height = 132;

  @override
  State<CarlysProfileCard> createState() => _CarlysProfileCardState();
}

class _CarlysProfileCardState extends State<CarlysProfileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDashBorderPainter.travelDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CarlysProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent != widget.isCurrent) {
      _syncAnimation();
    }
  }

  /// L'anneau ne tourne QUE sur le profil actuel — et se fige (segment posé,
  /// visible) quand le système demande la réduction des animations.
  void _syncAnimation() {
    if (!widget.isCurrent) {
      _controller.stop();
      return;
    }
    final reduced =
        AppMotion.resolve(context, AppDashBorderPainter.travelDuration) ==
            Duration.zero;
    if (reduced) {
      _controller.stop();
      _controller.value = AppDashBorderPainter.restProgress;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = _CardBody(
      profile: widget.profile,
      isCurrent: widget.isCurrent,
      onTap: widget.onTap,
    );

    return Semantics(
      button: true,
      label: '${carlysProfileContentOf(widget.profile).title}'
          '${widget.isCurrent ? ', ton profil actuel' : ''}',
      child: widget.isCurrent
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                foregroundPainter:
                    AppDashBorderPainter(progress: _controller.value),
                child: child,
              ),
              // Le contenu a sa propre couche : seul l'anneau repeint.
              child: RepaintBoundary(child: card),
            )
          : card,
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.profile,
    required this.isCurrent,
    required this.onTap,
  });

  final CarlysProfile profile;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = carlysProfileContentOf(profile);

    return Material(
      color: AppColors.darkSurface,
      borderRadius: AppRadius.cardSecondaryAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Ink(
          height: CarlysProfileCard._height,
          decoration: const BoxDecoration(
            borderRadius: AppRadius.cardSecondaryAll,
            // Le liseré violet léger du thème, sur les QUATRE cartes — la
            // carte actuelle pose son anneau animé par-dessus.
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.primaryLightBorder),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                // Le rayon de la CARTE (moins le liseré) : l'illustration
                // épouse les angles jusqu'au bord — sans quoi un croissant
                // sombre restait entre le coin et l'image.
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.cardSecondary - 1),
                ),
                child: SizedBox(
                  width: CarlysProfileCard.imageWidth,
                  height: double.infinity,
                  child: _ProfileIllustration(content: content),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrent) ...[
                      const AppBadge(
                        label: 'Ton profil',
                        variant: AppBadgeVariant.accent,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    // Bornés : la hauteur de carte est FIXE — sur un écran
                    // étroit (ou avec les glyphes carrés du harnais de test),
                    // un texte libre déborderait sous le badge.
                    Text(
                      content.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheading,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      content.tagline,
                      // Quatre lignes : les quatre descriptions s'affichent
                      // ENTIÈRES à la largeur d'un téléphone — la borne ne
                      // joue que sur les écrans hors norme.
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: AppColors.primaryLightBorder),
                    ),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'illustration ENTIÈRE dans une case plus étroite qu'elle : l'image en
/// `contain`, posée sur elle-même agrandie et floutée pour que la case reste
/// pleine. Un `cover` seul rognait un tiers de la largeur du dessin (le
/// marteau du Constructeur, les pièces du Stratège sortaient du cadre).
class _ProfileIllustration extends StatelessWidget {
  const _ProfileIllustration({required this.content});

  final CarlysProfileContent content;

  /// Flou du fond de case : on doit y lire une matière, plus une image.
  static const double _backdropSigma = 8;

  @override
  Widget build(BuildContext context) {
    // Décodée à la taille de sa CASE, pas à celle du fichier (800 × 598) :
    // sur un écran ×3, 348 pixels de large suffisent — cinq fois moins de
    // mémoire par carte, et l'écran en pose quatre. Le fond flouté et le
    // premier plan partagent le même décodage.
    final decodeWidth =
        (CarlysProfileCard.imageWidth * MediaQuery.devicePixelRatioOf(context))
            .round();

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _backdropSigma,
            sigmaY: _backdropSigma,
          ),
          child: Image.asset(
            content.assetPath,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            // Le fond n'a pas de repli propre : celui du premier plan suffit.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Image.asset(
          content.assetPath,
          fit: BoxFit.contain,
          cacheWidth: decodeWidth,
          // L'illustration manque : repli de marque, jamais un trou ni une
          // icône d'erreur.
          errorBuilder: (_, __, ___) => _Placeholder(icon: content.icon),
        ),
      ],
    );
  }
}

/// Repli d'illustration : dégradé de marque + icône du profil.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.neutral950],
        ),
      ),
      child: Icon(icon, size: 40, color: AppColors.primaryLight),
    );
  }
}
