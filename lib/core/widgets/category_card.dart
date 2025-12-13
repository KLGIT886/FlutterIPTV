import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// A category/group card for the home screen
class CategoryCard extends StatelessWidget {
  final String name;
  final int channelCount;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  
  const CategoryCard({
    super.key,
    required this.name,
    required this.channelCount,
    this.icon = Icons.folder_rounded,
    this.color,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.primaryColor;
    
    return TVFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      onSelect: onTap,
      focusScale: 1.06,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFocused
                  ? [
                      cardColor.withOpacity(0.9),
                      cardColor.withOpacity(0.7),
                    ]
                  : [
                      cardColor.withOpacity(0.6),
                      cardColor.withOpacity(0.3),
                    ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isFocused ? Colors.white.withOpacity(0.5) : Colors.transparent,
              width: isFocused ? 2 : 0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: cardColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            
            const Spacer(),
            
            // Name and count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$channelCount channels',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get an icon for a category name
  static IconData getIconForCategory(String name) {
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('sport') || lowerName.contains('football')) {
      return Icons.sports_soccer_rounded;
    }
    if (lowerName.contains('movie') || lowerName.contains('cinema') || lowerName.contains('film')) {
      return Icons.movie_rounded;
    }
    if (lowerName.contains('news')) {
      return Icons.newspaper_rounded;
    }
    if (lowerName.contains('music') || lowerName.contains('mtv')) {
      return Icons.music_note_rounded;
    }
    if (lowerName.contains('kid') || lowerName.contains('cartoon') || lowerName.contains('child')) {
      return Icons.child_care_rounded;
    }
    if (lowerName.contains('document') || lowerName.contains('discovery') || lowerName.contains('nature')) {
      return Icons.explore_rounded;
    }
    if (lowerName.contains('entertainment') || lowerName.contains('general')) {
      return Icons.tv_rounded;
    }
    if (lowerName.contains('education') || lowerName.contains('learn')) {
      return Icons.school_rounded;
    }
    if (lowerName.contains('religious') || lowerName.contains('church')) {
      return Icons.church_rounded;
    }
    if (lowerName.contains('food') || lowerName.contains('cook')) {
      return Icons.restaurant_rounded;
    }
    if (lowerName.contains('travel')) {
      return Icons.flight_rounded;
    }
    if (lowerName.contains('adult') || lowerName.contains('xxx')) {
      return Icons.no_adult_content_rounded;
    }
    
    return Icons.live_tv_rounded;
  }
  
  /// Get a color for a category index
  static Color getColorForIndex(int index) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];
    return colors[index % colors.length];
  }
}
