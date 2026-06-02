import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Neumorphic shadow + decoration helpers.
///
/// Mirrors the prototype shadows:
///  raised  = 10/10/24 dark + -10/-10/24 light
///  small   = 6/6/14
///  inset   = inset 6/6/14 (pressed)
class Neu {
  Neu._();

  static const double rCard = 28;
  static const double rChip = 14;
  static const double rPill = 999;

  static List<BoxShadow> raised({double depth = 1}) => [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: Offset(10 * depth, 10 * depth),
          blurRadius: 24 * depth,
        ),
        BoxShadow(
          color: AppColors.shadowLight,
          offset: Offset(-10 * depth, -10 * depth),
          blurRadius: 24 * depth,
        ),
      ];

  static List<BoxShadow> small() => const [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: Offset(6, 6),
          blurRadius: 14,
        ),
        BoxShadow(
          color: AppColors.shadowLight,
          offset: Offset(-6, -6),
          blurRadius: 14,
        ),
      ];

  /// A convex surface decoration (the default "raised" card look).
  static BoxDecoration card({
    double radius = rCard,
    Color? color,
    double depth = 0.7,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: raised(depth: depth),
      );

  /// A pressed / inset look. Flutter can't render true inner shadows cheaply,
  /// so we approximate with a subtle border + soft inner gradient.
  static BoxDecoration inset({
    double radius = rChip,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.bg,
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.shadowDark.withValues(alpha: 0.55),
            AppColors.shadowLight.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5],
        ),
        border: Border.all(color: AppColors.line, width: 1),
      );
}
