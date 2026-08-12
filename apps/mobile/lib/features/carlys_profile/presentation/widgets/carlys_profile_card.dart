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

  static const double _imageWidth = 116;
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
          '${widget.isCurrent ? ' — ton profil actuel' : ''}',
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
                  width: CarlysProfileCard._imageWidth,
                  height: double.infinity,
                  child: Image.asset(
                    content.assetPath,
                    fit: BoxFit.cover,
                    // L'illustration manque : repli de marque, jamais un
                    // trou ni une icône d'erreur.
                    errorBuilder: (_, __, ___) =>
                        _Placeholder(icon: content.icon),
                  ),
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
                    Text(
                      content.title.toUpperCase(),
                      style: AppTypography.subheading,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      content.tagline,
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
