import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesProvider>().loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (context, provider, _) {
              if (provider.favorites.isEmpty) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClearAll(context, provider),
                tooltip: 'Clear All',
              );
            },
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            );
          }
          
          if (provider.favorites.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildFavoritesList(provider);
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 50,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Favorites Yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long press on a channel to add it to favorites',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          TVFocusable(
            autofocus: true,
            onSelect: () => Navigator.pushNamed(context, AppRouter.channels),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRouter.channels),
              icon: const Icon(Icons.live_tv_rounded),
              label: const Text('Browse Channels'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFavoritesList(FavoritesProvider provider) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = PlatformDetector.getGridCrossAxisCount(size.width);
    
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(20),
      buildDefaultDragHandles: false,
      itemCount: provider.favorites.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderFavorites(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              color: Colors.transparent,
              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final channel = provider.favorites[index];
        
        return ReorderableDragStartListener(
          key: ValueKey(channel.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFavoriteCard(provider, channel, index),
          ),
        );
      },
    );
  }
  
  Widget _buildFavoriteCard(FavoritesProvider provider, dynamic channel, int index) {
    return TVFocusable(
      autofocus: index == 0,
      onSelect: () {
        Navigator.pushNamed(
          context,
          AppRouter.player,
          arguments: {
            'channelUrl': channel.url,
            'channelName': channel.name,
            'channelLogo': channel.logoUrl,
          },
        );
      },
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? AppTheme.focusBorderColor : Colors.transparent,
              width: isFocused ? 2 : 0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.focusColor.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Drag Handle
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Channel Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                image: channel.logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(channel.logoUrl!),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: channel.logoUrl == null
                  ? const Icon(
                      Icons.live_tv_rounded,
                      color: AppTheme.textMuted,
                      size: 28,
                    )
                  : null,
            ),
            
            const SizedBox(width: 16),
            
            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.groupName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      channel.groupName!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play Button
                TVFocusable(
                  onSelect: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.player,
                      arguments: {
                        'channelUrl': channel.url,
                        'channelName': channel.name,
                        'channelLogo': channel.logoUrl,
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Remove Button
                TVFocusable(
                  onSelect: () async {
                    await provider.removeFavorite(channel.id!);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed "${channel.name}" from favorites'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => provider.addFavorite(channel),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmClearAll(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Clear All Favorites',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'Are you sure you want to remove all channels from your favorites?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.clearFavorites();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All favorites cleared'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }
}
