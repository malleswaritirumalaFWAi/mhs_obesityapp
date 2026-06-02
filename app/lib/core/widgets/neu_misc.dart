import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/neu.dart';

/// Small rounded pill / chip with a soft background.
class NeuPill extends StatelessWidget {
  const NeuPill({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.coralSoft,
        borderRadius: BorderRadius.circular(Neu.rPill),
      ),
      child: child,
    );
  }
}

/// A circular raised icon button (e.g. back / notifications).
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.color,
    this.iconColor,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: Neu.small(),
        ),
        child: Icon(icon, size: size * 0.46, color: iconColor ?? AppColors.inkMid),
      ),
    );
  }
}

/// Circular progress ring used in dashboard "done" indicator.
class NeuProgressRing extends StatelessWidget {
  const NeuProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.stroke = 10,
    this.color = AppColors.coral,
    this.center,
  });
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: stroke,
              valueColor: const AlwaysStoppedAnimation(AppColors.line),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
              backgroundColor: Colors.transparent,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

/// Standard neumorphic text field with an inset look.
class NeuTextField extends StatelessWidget {
  const NeuTextField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.prefix,
    this.maxLines = 1,
    this.style,
    this.onChanged,
    this.textAlign = TextAlign.start,
  });
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final int maxLines;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: Neu.inset(radius: 18),
      child: Row(
        children: [
          if (prefix != null) ...[prefix!, const SizedBox(width: 10)],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: onChanged,
              textAlign: textAlign,
              style: style ??
                  const TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple top bar: back button + title + optional trailing.
class NeuTopBar extends StatelessWidget {
  const NeuTopBar({super.key, this.title, this.onBack, this.trailing, this.showBack = true});
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          NeuIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        if (title != null) ...[
          const SizedBox(width: 14),
          Expanded(
            child: Text(title!,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
        ] else
          const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
