import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../widgets/favorite_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../providers/favorites_provider.dart';
import '../../../core/services/channel_playback.dart';
import '../../../core/models/channel.dart';

class FavoritesScreen extends StatefulWidget {
  final bool embedded;
  
  const FavoritesScreen({super.key, this.embedded = false});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesProvider>().loadFavorites();
  }

  void _playChannel(Channel channel) {
    playChannelFromList(context, channel, logTag: 'FavoritesScreen');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = _buildContent(context);

    if (isTV) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getPrimaryColor(context).withOpacity(0.15),
                            AppTheme.getBackgroundColor(context),
                          ]
                        : [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getBackgroundColor(context).withOpacity(0.9),
                            AppTheme.getPrimaryColor(context).withOpacity(0.08),
                          ],
                  ),
          ),
          child: TVSidebar(
            selectedIndex: 3, // 收藏页
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
      final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
      final topPadding = isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0) : 0.0;
      
      return Column(
        children: [
          // 横屏时添加状态栏间距
          if (isLandscape && topPadding > 0)
            SizedBox(height: topPadding),
          // 简化的标题栏
          Container(
            height: isLandscape ? 24.0 : null,  // 横屏时固定高度24px，与AppBar一致
            padding: EdgeInsets.fromLTRB(
              12,
              isLandscape ? 0 : (topPadding + 8),  // 横屏时不需要额外padding，竖屏保持原样
              12,
              0,  // 底部padding设为0，由height控制
            ),
            alignment: Alignment.centerLeft,  // 垂直居中对齐
            child: Row(
              children: [
                Text(
                  AppStrings.of(context)?.favorites ?? 'Favorites',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 14 : 18,  // 横屏时字体14px
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Consumer<FavoritesProvider>(
                  builder: (context, provider, _) {
                    if (provider.favorites.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        Icons.delete_sweep_rounded, 
                        color: AppTheme.getTextSecondary(context),
                        size: isLandscape ? 14 : 24,  // 横屏时图标更小，与AppBar一致
                      ),
                      padding: isLandscape ? const EdgeInsets.all(2) : null,  // 横屏时减少padding
                      constraints: isLandscape ? const BoxConstraints() : null,  // 移除最小尺寸限制
                      onPressed: () => _confirmClearAll(context, provider),
                      tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // 手机端添加状态栏高度
            if (PlatformDetector.isMobile)
              SizedBox(height: MediaQuery.of(context).padding.top),
            Builder(
              builder: (context) {
                final width = MediaQuery.of(context).size.width;
                final isMobile = PlatformDetector.isMobile;
                final isLandscape = isMobile && width > 600;
                return AppBar(
                  backgroundColor: Colors.transparent,
                  primary: false,  // 禁用自动SafeArea padding
                  toolbarHeight: isLandscape ? 24.0 : 56.0,  // 横屏时减小到24px
                  title: Text(
                    AppStrings.of(context)?.favorites ?? 'Favorites',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 14 : 20,  // 横屏时字体14px
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: isLandscape ? 14 : 24,  // 横屏时图标更小
                    ),
                    padding: isLandscape ? const EdgeInsets.all(2) : null,
                    constraints: isLandscape ? const BoxConstraints() : null,  // 移除最小尺寸限制
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    Consumer<FavoritesProvider>(
                      builder: (context, provider, _) {
                        if (provider.favorites.isEmpty) return const SizedBox.shrink();

                        return IconButton(
                          icon: Icon(
                            Icons.delete_sweep_rounded,
                            size: isLandscape ? 14 : 24,  // 横屏时图标更小
                          ),
                          padding: isLandscape ? const EdgeInsets.all(2) : null,
                          constraints: isLandscape ? const BoxConstraints() : null,  // 移除最小尺寸限制
                          onPressed: () => _confirmClearAll(context, provider),
                          tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (provider.favorites.isEmpty) {
          return _buildEmptyState();
        }

        return _buildFavoritesList(provider);
      },
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
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noFavoritesYet ?? 'No Favorites Yet',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.favoritesHint ?? 'Long press on a channel to add it to favorites',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
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
              label: Text(AppStrings.of(context)?.browseChannels ?? 'Browse Channels'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider provider) {
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

        return Padding(
          key: ValueKey(channel.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFavoriteCard(provider, channel, index),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoritesProvider provider, dynamic channel, int index) {
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    
    return FavoriteCardWrapper(
      index: index,
      channel: channel,
      isLandscape: isLandscape,
      onPlayChannel: () => _playChannel(channel),
      onRemoveFavorite: () async {
        await provider.removeFavorite(channel.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text((AppStrings.of(context)?.removedFromFavorites ?? 'Removed "{name}" from favorites').replaceAll('{name}', channel.name)),
              action: SnackBarAction(
                label: AppStrings.of(context)?.undo ?? 'Undo',
                onPressed: () => provider.addFavorite(channel),
              ),
            ),
          );
        }
      },
    );
  }

  void _confirmClearAll(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.clearAllFavorites ?? 'Clear All Favorites',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            AppStrings.of(context)?.clearFavoritesConfirm ?? 'Are you sure you want to remove all channels from your favorites?',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.clearFavorites();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.allFavoritesCleared ?? 'All favorites cleared'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.clearAll ?? 'Clear All'),
            ),
          ],
        );
      },
    );
  }
}

