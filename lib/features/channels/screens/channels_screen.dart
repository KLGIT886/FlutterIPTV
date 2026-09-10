import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/models/channel.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../../../core/utils/throttled_state_mixin.dart'; // ✅ 导入节流 mixin

import '../providers/channel_provider.dart';
import '../widgets/channel_test_dialog.dart';
import '../widgets/background_test_indicator.dart';
import '../widgets/channels_grid_item.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../widgets/landscape_category_bar.dart';

part 'channels_screen_test_actions.dart';

part 'channels_screen_groups.dart';

class ChannelsScreen extends StatefulWidget {
  final String? groupName;
  final bool embedded; // 是否嵌入到首页底部导航

  const ChannelsScreen({
    super.key,
    this.groupName,
    this.embedded = false,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with ThrottledStateMixin {
  String? _selectedGroup;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _groupScrollController = ScrollController();

  // ✅ 本地缓存频道列表，避免每次 Provider 更新都重建
  List<Channel> _cachedChannels = [];
  bool _isLoadingMore = false;

  // ✅ 追踪上一次选中的分类，用于检测分类变化
  String? _lastSelectedGroup;

  // 用于TV端分类焦点管理
  final List<FocusNode> _groupFocusNodes = [];
  final List<FocusNode> _channelFocusNodes = [];
  int _currentGroupIndex = 0;
  int _lastChannelIndex = 0; // 记住上次聚焦的频道索引

  // 延迟选中分类的定时器
  Timer? _groupSelectTimer;

  // ✅ 滚动状态管理：用于暂停台标加载
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groupName;

    // ✅ 添加滚动监听，滚动时暂停台标加载
    _scrollController.addListener(_onScroll);

    // 嵌入模式下清除分类筛选，显示全部频道
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChannelProvider>().clearGroupFilter();
      });
    } else if (_selectedGroup != null) {
      context.read<ChannelProvider>().selectGroup(_selectedGroup!);

      // 如果是从首页"更多"按钮跳转过来的，延迟跳转焦点到第一个频道
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (PlatformDetector.isTV) {
          // 延迟一点时间确保UI完全构建完成
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              // 找到对应分类的索引
              final provider = context.read<ChannelProvider>();
              final groupIndex =
                  provider.groups.indexWhere((g) => g.name == _selectedGroup);
              if (groupIndex >= 0) {
                // +1 因为第一个是"全部频道"
                _currentGroupIndex = groupIndex + 1;
              }

              // 跳转焦点到第一个频道并记住索引
              if (_channelFocusNodes.isNotEmpty) {
                _lastChannelIndex = 0; // 记住是第一个频道
                _channelFocusNodes[0].requestFocus();
              }
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // 确保退出页面时恢复台标加载
    try {
      if (mounted) {
        context.read<ChannelProvider>().resumeLogoLoading();
      }
    } catch (e) {
      // Ignore provider error on dispose
    }

    _groupSelectTimer?.cancel();
    _scrollEndTimer?.cancel();
    _scrollController.dispose();
    _groupScrollController.dispose();
    for (final node in _groupFocusNodes) {
      node.dispose();
    }
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ✅ 控制台标加载状态
  void setLogoLoadingScrolling(bool isScrolling) {
    if (!mounted) return;
    try {
      final provider = context.read<ChannelProvider>();
      if (isScrolling) {
        provider.pauseLogoLoading();
      } else {
        provider.resumeLogoLoading();
      }
    } catch (_) {}
  }

  /// ✅ 滚动监听：滚动时暂停台标加载 + 滚动到底部时加载更多
  void _onScroll() {
    // 标记为正在滚动
    setLogoLoadingScrolling(true);

    // 取消之前的定时器
    _scrollEndTimer?.cancel();

    // 滚动停止500ms后恢复台标加载
    _scrollEndTimer = Timer(const Duration(milliseconds: 500), () {
      setLogoLoadingScrolling(false);
    });

    // ✅ 检查是否滚动到底部，触发加载更多
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = maxScroll - currentScroll;

    // 距离底部还有1000像素时开始加载下一页
    if (delta < 1000 && mounted && !_isLoadingMore) {
      final provider = context.read<ChannelProvider>();

      if (provider.hasMore) {
        ServiceLocator.log.i(
            '[ChannelsScreen] 触发加载更多: delta=${delta.toStringAsFixed(0)}px, loaded=${provider.loadedChannelCount}/${provider.totalChannelCount}');

        immediateSetState(() => _isLoadingMore = true); // 立即更新加载状态

        // 判断是加载所有频道还是特定播放列表
        Future<void> loadFuture;
        if (provider.selectedGroup == null) {
          ServiceLocator.log.d('[ChannelsScreen] 加载所有频道（分页）');
          loadFuture = provider.loadAllChannels(loadMore: true);
        } else {
          final playlistProvider = context.read<PlaylistProvider>();
          final activePlaylist = playlistProvider.activePlaylist;
          final playlistId = activePlaylist?.id;
          if (playlistId != null) {
            ServiceLocator.log.d('[ChannelsScreen] 加载播放列表 $playlistId 的频道（分页）');
            loadFuture = provider.loadChannels(playlistId, loadMore: true);
          } else {
            ServiceLocator.log.w('[ChannelsScreen] 无法加载更多：playlistId 为 null');
            immediateSetState(() => _isLoadingMore = false); // 立即更新加载状态
            return;
          }
        }

        // 加载完成后更新本地缓存和状态
        loadFuture.then((_) {
          ServiceLocator.log.i('[ChannelsScreen] 加载更多完成，开始更新缓存');
          if (mounted) {
            throttledSetState(() {
              _cachedChannels = provider.filteredChannels;
              ServiceLocator.log
                  .i('[ChannelsScreen] 缓存更新完成: ${_cachedChannels.length} 个频道');
            });

            // ✅ 等待UI渲染完成后再解锁“加载更多”，防止快速连续触发
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                immediateSetState(() {
                  _isLoadingMore = false;
                });
                ServiceLocator.log.d('[ChannelsScreen] "加载更多"已解锁');

                // NEW LOGIC: Check again if we're at the bottom and need to load more
                final currentMaxScroll =
                    _scrollController.position.maxScrollExtent;
                final currentScrollPosition = _scrollController.position.pixels;

                const threshold = 0.9; // Moved threshold declaration here

                bool shouldLoadNextPage = false;
                if (currentMaxScroll == 0.0) {
                  // No scrollable content yet, or very little (e.g., first load)
                  shouldLoadNextPage =
                      true; // Always try to load if nothing loaded yet
                } else {
                  shouldLoadNextPage =
                      (currentScrollPosition / currentMaxScroll) > threshold;
                }

                if (shouldLoadNextPage && provider.hasMore) {
                  ServiceLocator.log.d(
                      '[ChannelsScreen] "加载更多"解锁后再次触发加载 (position/max: ${currentScrollPosition.toStringAsFixed(0)}/${currentMaxScroll.toStringAsFixed(0)}, threshold: ${threshold * 100}%)');
                  _onScroll(); // Recursive call, but now with a guaranteed frame break.
                } else {
                  ServiceLocator.log.d(
                      '[ChannelsScreen] "加载更多"解锁，但不再触发下一页加载 (position/max: ${currentScrollPosition.toStringAsFixed(0)}/${currentMaxScroll.toStringAsFixed(0)}, hasMore: ${provider.hasMore}, threshold: ${threshold * 100}%)');
                }
              }
            });
          }
        }).catchError((e) {
          ServiceLocator.log.e('[ChannelsScreen] 加载更多失败', error: e);
          if (mounted) {
            immediateSetState(() => _isLoadingMore = false); // 立即更新加载状态
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = Row(
      children: [
        // Groups Sidebar (for TV and Desktop)
        if (isTV) _buildGroupsSidebar(),
        // Channels Grid
        Expanded(child: _buildChannelsContent()),
      ],
    );

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
            selectedIndex: 1, // 频道页
            onRight: () {
              // 主菜单按右键，跳转到当前分类
              if (_groupFocusNodes.isNotEmpty &&
                  _currentGroupIndex < _groupFocusNodes.length) {
                _groupFocusNodes[_currentGroupIndex].requestFocus();
              }
            },
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold，直接返回内容
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;
      final statusBarHeight =
          isMobile ? MediaQuery.of(context).padding.top : 0.0;
      final topPadding =
          isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15 : 0.0) : 0.0;

      return Stack(
        children: [
          content,
          // 手机端嵌入模式：竖屏时显示浮动按钮，横屏时不显示（因为有固定分类栏）
          if (!isLandscape)
            Positioned(
              left: 8,
              top: topPadding + 8,
              child: Material(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showMobileGroupsBottomSheet(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_rounded,
                            color: AppTheme.getTextPrimary(context), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedGroup ??
                              (AppStrings.of(context)?.allChannels ?? 'All'),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            color: AppTheme.getTextMuted(context), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
        child: content,
      ),
      // 手机端添加分类抽屉
      drawer: _buildMobileGroupsDrawer(),
    );
  }

  /// 手机端嵌入模式的分类底部弹窗
  Widget _buildChannelsContent() {
    ServiceLocator.log.d('[ChannelsScreen] _buildChannelsContent 被调用');

    // ✅ 使用 Consumer 只监听分组变化，频道列表使用本地缓存
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        ServiceLocator.log.d(
            '[ChannelsScreen] Consumer builder 被调用 - filteredChannels=${provider.filteredChannels.length}, cached=${_cachedChannels.length}');

        // ✅ 检测分类是否变化
        final groupChanged = _selectedGroup != _lastSelectedGroup;

        // 首次加载、切换分类或长度变化时更新缓存
        if (_cachedChannels.isEmpty ||
            groupChanged ||
            provider.filteredChannels.length != _cachedChannels.length) {
          ServiceLocator.log.d(
              '[ChannelsScreen] 需要更新缓存: empty=${_cachedChannels.isEmpty}, groupChanged=$groupChanged, lengthChanged=${provider.filteredChannels.length != _cachedChannels.length}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              throttledSetState(() {
                _cachedChannels = provider.filteredChannels;
                _lastSelectedGroup = _selectedGroup; // ✅ 记录当前分类
                ServiceLocator.log
                    .d('[ChannelsScreen] 缓存已更新: ${_cachedChannels.length} 个频道');
              });

              // ✅ 如果是分类变化，滚动到顶部
              if (groupChanged && _scrollController.hasClients) {
                _scrollController.jumpTo(0);
                ServiceLocator.log.d('[ChannelsScreen] 分类变化，已滚动到顶部');
              }

              // ✅ 检查是否填满屏幕，如果未填满且还有更多数据，自动触发加载下一页
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted && _scrollController.hasClients) {
                  final maxScroll = _scrollController.position.maxScrollExtent;
                  // 如果最大滚动距离很小（说明内容没有填满屏幕），且还有更多数据，则触发加载
                  if (maxScroll < 100 && provider.hasMore && !_isLoadingMore) {
                    ServiceLocator.log.i(
                        '[ChannelsScreen] 内容不足以滚动(maxScroll=$maxScroll)，自动触发加载更多');
                    _onScroll();
                  }
                }
              });
            }
          });
        }

        final channels = _cachedChannels.isNotEmpty
            ? _cachedChannels
            : provider.filteredChannels;
        ServiceLocator.log.d('[ChannelsScreen] 使用频道列表: ${channels.length} 个');
        final isMobile = PlatformDetector.isMobile;
        final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;

        // 参考首页的设置，手机端获取状态栏高度并减少间距
        final statusBarHeight =
            isMobile ? MediaQuery.of(context).padding.top : 0.0;
        final topPadding = isMobile
            ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0)
            : 0.0;

        return CustomScrollView(
          controller: _scrollController,
          // ✅ 性能优化：限制缓存范围，减少内存占用
          cacheExtent: 500,
          slivers: [
            // 手机竖屏：添加顶部间距
            if (isMobile && !isLandscape)
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding),
              ),

            // 手机横屏：使用 SliverPersistentHeader 实现固定分类栏（不遮挡状态栏）
            if (isLandscape && widget.embedded)
              SliverPersistentHeader(
                pinned: true,
                delegate: LandscapeCategoryBarDelegate(
                  provider: provider,
                  selectedGroup: _selectedGroup,
                  channels: channels,
                  statusBarHeight: statusBarHeight,
                  onGroupSelected: (groupName) {
                    immediateSetState(
                        () => _selectedGroup = groupName); // 立即更新分类选择
                    if (groupName == null) {
                      provider.clearGroupFilter();
                    } else {
                      provider.selectGroup(groupName);
                    }
                  },
                  onTestChannels: () =>
                      _showChannelTestDialog(context, channels),
                  onShowBackgroundTest: () =>
                      _showBackgroundTestProgress(context),
                  onDeleteUnavailable: _selectedGroup ==
                              ChannelProvider.unavailableGroupName &&
                          channels.isNotEmpty
                      ? () => _confirmDeleteAllUnavailable(context, provider)
                      : null,
                ),
              ),

            // 竖屏或非嵌入模式：使用普通 AppBar
            if (!isLandscape || !widget.embedded)
              SliverAppBar(
                pinned: false,
                floating: true,
                primary: false, // 禁用自动SafeArea
                backgroundColor: Colors.transparent,
                toolbarHeight: 56.0,
                expandedHeight: 0,
                collapsedHeight: 56.0,
                titleSpacing: 0,
                leadingWidth: 56,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [
                              const Color(0xFF0A0A0A).withOpacity(0.95),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.15),
                            ]
                          : [
                              const Color(0xFFE0E0E0).withOpacity(0.95),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.12),
                            ],
                    ),
                  ),
                ),
                leading: isMobile && !widget.embedded
                    ? IconButton(
                        icon: Icon(Icons.menu_rounded,
                            color: AppTheme.getTextPrimary(context), size: 24),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      )
                    : null,
                title: widget.embedded
                    ? null
                    : Text(
                        _selectedGroup ??
                            (AppStrings.of(context)?.allChannels ??
                                'All Channels'),
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                actions: [
                  // Background test progress indicator
                  BackgroundTestIndicator(
                    onTap: () => _showBackgroundTestProgress(context),
                  ),
                  // Test channels button
                  IconButton(
                    icon: const Icon(Icons.speed_rounded),
                    iconSize: 24,
                    color: AppTheme.getTextSecondary(context),
                    tooltip: '测试频道',
                    onPressed: channels.isEmpty
                        ? null
                        : () => _showChannelTestDialog(context, channels),
                  ),
                  // Delete all unavailable channels button
                  if (_selectedGroup == ChannelProvider.unavailableGroupName &&
                      channels.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      iconSize: 24,
                      color: AppTheme.errorColor,
                      tooltip: '删除所有失效频道',
                      onPressed: () =>
                          _confirmDeleteAllUnavailable(context, provider),
                    ),
                  // Channel count
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      margin: EdgeInsets.only(right: isLandscape ? 8 : 16),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.getSurfaceColor(context).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLandscape
                            ? '${channels.length}'
                            : '${channels.length} ${AppStrings.of(context)?.channels ?? 'channels'}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: isLandscape ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Channels Grid
            if (channels.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.live_tv_outlined,
                        size: 64,
                        color: AppTheme.getTextMuted(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)?.noChannelsFound ??
                            'No channels found',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: isMobile ? (isLandscape ? 4 : 8) : 20,
                  right: isMobile ? (isLandscape ? 4 : 8) : 20,
                  top: isMobile ? (isLandscape ? 4 : 8) : 20, // 横屏时顶部间距4px
                  bottom: isMobile ? (isLandscape ? 4 : 8) : 20,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.crossAxisExtent;
                    final crossAxisCount =
                        CardSizeCalculator.calculateCardsPerRow(availableWidth);

                    ServiceLocator.log.d(
                        '[ChannelsScreen] SliverLayoutBuilder - 宽度=$availableWidth, 每行=$crossAxisCount 张卡片');

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: CardSizeCalculator.aspectRatio(),
                        crossAxisSpacing: CardSizeCalculator.spacing,
                        mainAxisSpacing: CardSizeCalculator.spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // ✅ 只在前10个和最后10个卡片打印日志，避免日志过多
                          // if (index < 10 || index >= channels.length - 10) {
                          //   ServiceLocator.log.d(
                          //       '[ChannelsScreen] 构建卡片 #$index/${channels.length}');
                          // }

                          final channel = channels[index];

                          // TV端：确保焦点节点数量正确
                          if (PlatformDetector.isTV) {
                            while (_channelFocusNodes.length <= index) {
                              _channelFocusNodes.add(FocusNode());
                            }
                          }

                          // TV端：判断是否是第一列（需要处理左键导航）
                          final isFirstColumn = index % crossAxisCount == 0;

                          // TV端：判断是否是最后一行（需要处理下键切换分类）
                          final totalRows =
                              (channels.length / crossAxisCount).ceil();
                          final currentRow = index ~/ crossAxisCount;
                          final isLastRow = currentRow == totalRows - 1;

                          return ChannelGridItem(
                            channel: channel,
                            isFirstColumn: isFirstColumn,
                            isLastRow: isLastRow,
                            crossAxisCount: crossAxisCount,
                            focusNode: PlatformDetector.isTV &&
                                    index < _channelFocusNodes.length
                                ? _channelFocusNodes[index]
                                : null,
                            onFocused: PlatformDetector.isTV
                                ? () {
                                    // 记住当前聚焦的频道索引
                                    _lastChannelIndex = index;
                                  }
                                : null,
                            onLeft: (PlatformDetector.isTV && isFirstColumn)
                                ? () {
                                    // 第一列按左键，跳转到当前选中的分类
                                    ServiceLocator.log.d(
                                        'ChannelsScreen: onLeft pressed, _currentGroupIndex=$_currentGroupIndex, _selectedGroup=$_selectedGroup');
                                    if (_currentGroupIndex <
                                        _groupFocusNodes.length) {
                                      _groupFocusNodes[_currentGroupIndex]
                                          .requestFocus();
                                    }
                                  }
                                : null,
                            onDown: (PlatformDetector.isTV && isLastRow)
                                ? () {
                                    // 最后一行按下键，不做任何事（阻止跳转）
                                  }
                                : null,
                            onTest: () => _testSingleChannel(context, channel),
                            onShowOptions: (ch) =>
                                _showChannelOptions(context, ch),
                          );
                        },
                        childCount: channels.length,
                        // ✅ 性能优化：不保持已滚动出视口的卡片状态
                        addAutomaticKeepAlives: false,
                        // ✅ 性能优化：添加重绘边界，避免不必要的重绘
                        addRepaintBoundaries: true,
                      ),
                    );
                  },
                ),
              ),

            // ✅ 加载更多指示器
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '加载更多频道... (${channels.length}/${provider.filteredChannels.length})',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ 已加载全部提示
            if (!provider.hasMore && channels.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text(
                    '已加载全部 ${channels.length} 个频道',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

}

/// 横屏分类栏 Delegate（固定在状态栏下方）


