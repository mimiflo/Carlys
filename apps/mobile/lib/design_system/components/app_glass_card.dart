import 'dart:ui';

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';

/// Carte « glass » — à réserver EXCLUSIVEMENT aux cartes posées sur une
/// scène 3D (fond translucide + blur 24). Ailleurs : carte opaque
/// `darkSurface` + bordure, sans ombre.
class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = AppRadius.cardMainAll,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkGlass,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
