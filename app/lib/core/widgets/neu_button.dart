import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/neu.dart';

/// A neumorphic button that visually "presses in" on tap.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.gradient,
    this.foreground,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.radius = Neu.rPill,
    this.filled = true,
    this.loading = false,
  });

  /// Primary CTA — teal-to-indigo gradient pill.
  factory NeuButton.primary(
    String label, {
    Key? key,
    VoidCallback? onPressed,
    bool expand = true,
    bool loading = false,
    Widget? trailing,
  }) {
    return NeuButton(
      key: key,
      onPressed: onPressed,
      gradient: const LinearGradient(
        colors: [Color(0xFF1B4F72), Color(0xFF6C63FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      foreground: Colors.white,
      expand: expand,
      filled: true,
      loading: loading,
      child: _LabelRow(label: label, trailing: trailing, color: Colors.white),
    );
  }

  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final Gradient? gradient;
  final Color? foreground;
  final bool expand;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool filled;
  final bool loading;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final hasGradient = widget.gradient != null && widget.filled;
    final bg = widget.filled ? (widget.color ?? AppColors.surface) : AppColors.surface;

    Widget child = widget.loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.foreground ?? AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.foreground ?? AppColors.ink),
              child: widget.child,
            ),
          );

    final borderRadius = BorderRadius.circular(widget.radius);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: widget.expand ? double.infinity : null,
        padding: widget.padding,
        alignment: widget.expand ? Alignment.center : null,
        decoration: BoxDecoration(
          color: hasGradient ? null : bg,
          gradient: hasGradient
              ? (enabled ? widget.gradient : null)
              : null,
          borderRadius: borderRadius,
          boxShadow: _down || !enabled
              ? Neu.small()
              : hasGradient
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(_down ? 0.15 : 0.35),
                        blurRadius: _down ? 6 : 16,
                        offset: Offset(0, _down ? 2 : 6),
                      )
                    ]
                  : Neu.raised(depth: 0.6),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Center(
            child: hasGradient && !enabled
                ? ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        Colors.grey, BlendMode.saturation),
                    child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, this.trailing, required this.color});
  final String label;
  final Widget? trailing;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
