part of 'home_screen.dart';

/// 首页顶部紧凑头部（继续观看/添加/刷新/主题等）从 _HomeScreenState 抽出的扩展。
extension _HomeScreenHeader on _HomeScreenState {
  Widget _buildCompactHeader(ChannelProvider provider) {
    // 获取上次播放的频道 - 使用 watch 来监听变化
    final settingsProvider = context.watch<SettingsProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final activePlaylist = playlistProvider.activePlaylist;
    Channel? lastChannel;
    final bool isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' &&
        settingsProvider.hasMultiScreenState;

    // ServiceLocator.log.d(
    //     'HomeScreen: lastPlayMode=${settingsProvider.lastPlayMode}, hasMultiScreenState=${settingsProvider.hasMultiScreenState}, isMultiScreenMode=$isMultiScreenMode');
    // ServiceLocator.log.d(
    //     'HomeScreen: lastMultiScreenChannels=${settingsProvider.lastMultiScreenChannels}');

    if (settingsProvider.rememberLastChannel &&
        settingsProvider.lastChannelId != null) {
      try {
        lastChannel = provider.channels.firstWhere(
          (c) => c.id == settingsProvider.lastChannelId,
        );
      } catch (_) {
        // 频道不存在，使用第一个频道
        lastChannel =
            provider.channels.isNotEmpty ? provider.channels.first : null;
      }
    } else {
      lastChannel =
          provider.channels.isNotEmpty ? provider.channels.first : null;
    }

    // 构建播放列表信息
    String playlistInfo = '';
    if (activePlaylist != null) {
      final type = activePlaylist.isRemote ? 'URL' : '本地';
      playlistInfo = ' · [$type] ${activePlaylist.name}';
      if (activePlaylist.url != null && activePlaylist.url!.isNotEmpty) {
        String url =
            activePlaylist.url!.replaceFirst(RegExp(r'^https?://'), '');
        if (url.length > 30) {
          url = '${url.substring(0, 30)}...';
        }
        playlistInfo += ' · $url';
      }
    }

    // 继续播放按钮 - 名字固定为 "Continue"，不根据模式变化
    final continueLabel =
        AppStrings.of(context)?.continueWatching ?? 'Continue';
    final isMobile = PlatformDetector.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = isMobile && screenWidth > 700; // 手机端横屏

    // 手机端获取状态栏高度，并减少一些间距让内容更靠近状态栏
    final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
    final topPadding = isMobile
        ? (statusBarHeight > 0 ? statusBarHeight - 10.0 : 0.0)
        : 16.0; // 状态栏高度 + 4px

    return Container(
      // 手机端添加状态栏高度的padding，其他平台使用SafeArea
      padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          topPadding, // 使用计算后的顶部间距
          isMobile ? 12 : 24,
          isMobile ? 2 : 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.getGradient(context).createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Lotus IPTV',
                          style: TextStyle(
                              fontSize: isLandscape ? 16 : (isMobile ? 18 : 28),
                              fontWeight: FontWeight.bold,
                              color: Colors.white)), // 横屏16，竖屏18
                      const SizedBox(width: 8),
                      Text('v$_appVersion',
                          style: TextStyle(
                              fontSize: isLandscape ? 10 : (isMobile ? 11 : 11),
                              fontWeight: FontWeight.normal,
                              color: Colors.white70)), // 横屏12，竖屏13，桌面14
                      if (_availableUpdate != null) ...[
                        const SizedBox(width: 8),
                        TVFocusable(
                          onSelect: () => Navigator.pushNamed(
                              context, AppRouter.settings,
                              arguments: {'autoCheckUpdate': true}),
                          focusScale: 1.0,
                          showFocusBorder: false,
                          builder: (context, isFocused, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: isFocused
                                    ? AppTheme.getGradient(context)
                                    : LinearGradient(
                                        colors: [
                                          Colors.orange.shade600,
                                          Colors.deepOrange.shade600
                                        ],
                                      ),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusPill),
                                border: isFocused
                                    ? Border.all(
                                        color:
                                            AppTheme.getPrimaryColor(context),
                                        width: 2)
                                    : null,
                              ),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.system_update_rounded,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text('v${_availableUpdate!.version}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 手机端横屏时隐藏副标题，节省空间
                if (!isMobile || MediaQuery.of(context).size.width <= 700) ...[
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    '${provider.totalChannelCount} ${AppStrings.of(context)?.channels ?? "频道"} · ${provider.groups.length} ${AppStrings.of(context)?.categories ?? "分类"} · ${context.watch<FavoritesProvider>().count} ${AppStrings.of(context)?.favorites ?? "收藏"}$playlistInfo',
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderButton(
                  Icons.play_arrow_rounded,
                  continueLabel,
                  true,
                  (lastChannel != null || isMultiScreenMode)
                      ? () => _continuePlayback(provider, lastChannel,
                          isMultiScreenMode, settingsProvider)
                      : null,
                  focusNode: _continueButtonFocusNode), // 添加焦点节点
              SizedBox(width: isMobile ? 6 : 10),
              _buildHeaderButton(
                  Icons.playlist_add_rounded,
                  AppStrings.of(context)?.playlists ?? 'Playlists',
                  false,
                  () => _showAddPlaylistDialog()),
              SizedBox(width: isMobile ? 6 : 10),
              _buildHeaderButton(
                  Icons.refresh_rounded,
                  AppStrings.of(context)?.refresh ?? 'Refresh',
                  false,
                  activePlaylist != null
                      ? () =>
                          _refreshCurrentPlaylist(playlistProvider, provider)
                      : null),
              SizedBox(width: isMobile ? 6 : 10),
              _buildThemeToggleButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// 继续播放 - 支持单频道和分屏模式
}
