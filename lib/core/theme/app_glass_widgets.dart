import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

// Glassmorphism Card Decoration
class GlassDecoration extends BoxDecoration {
  GlassDecoration({
    required BuildContext context,
    bool focused = false,
    double borderRadius = AppTheme.radiusMedium,
    Color? glowColor,
  }) : super(
          borderRadius: BorderRadius.circular(borderRadius),
          color: AppTheme.glassColor,
          border: Border.all(
            color: focused ? (glowColor ?? AppTheme.getPrimaryColor(context)) : AppTheme.glassBorderColor,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: (glowColor ?? AppTheme.getPrimaryColor(context)).withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        );
}

// TV-specific focus decoration with Lotus glow
class TVFocusDecoration extends BoxDecoration {
  TVFocusDecoration({required BuildContext context, bool focused = false})
      : super(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: focused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
            width: focused ? 3 : 0,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.getPrimaryColor(context).withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        );
}

// Glass Card Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool focused;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.focused = false,
    this.borderRadius = AppTheme.radiusMedium,
    this.padding,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: GlassDecoration(
            context: context,
            focused: focused,
            borderRadius: borderRadius,
            glowColor: glowColor,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

