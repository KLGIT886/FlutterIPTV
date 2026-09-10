part of 'multi_screen_player.dart';

/// 频道选择器（分类 + 频道网格 + 卡片）从 _MultiScreenPlayerState 抽出的扩展。
extension _MultiScreenChannelSelector on _MultiScreenPlayerState {
  Widget _buildChannelSelector(
      BuildContext context, MultiScreenProvider multiScreenProvider) {
    final channelProvider = context.watch<ChannelProvider>();

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Row(
        children: [
          // 左侧晶制嗙被制楄〃
          Container(
            width: 200,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 栏囬栏?
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.getCardColor(context),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            refreshMultiScreenUi(() => _showChannelSelector = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppTheme.getTextPrimary(context),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (AppStrings.of(context)?.screenNumber ??
                                  'Screen {number}')
                              .replaceAll(
                                  '{number}', '${_targetScreenIndex + 1}'),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 全部频道选择
                _buildCategoryItem(
                  context,
                  name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                  count: channelProvider.totalChannelCount,
                  isSelected: _selectedCategory == null,
                  onTap: () => refreshMultiScreenUi(() => _selectedCategory = null),
                ),
                Divider(color: AppTheme.getCardColor(context), height: 1),
                // 制嗙被制楄〃
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: channelProvider.groups.length,
                    itemBuilder: (context, index) {
                      final group = channelProvider.groups[index];
                      return _buildCategoryItem(
                        context,
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedCategory == group.name,
                        onTap: () =>
                            refreshMultiScreenUi(() => _selectedCategory = group.name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 监听频道网格
          Expanded(
            child: Container(
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
              child: _buildChannelGrid(
                  context, channelProvider, multiScreenProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextPrimary(context),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextMuted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelGrid(
      BuildContext context,
      ChannelProvider channelProvider,
      MultiScreenProvider multiScreenProvider) {
    // 使用 allChannels 获取全部频道，而不是分页的 channels
    List channels;
    if (_selectedCategory == null) {
      channels = channelProvider.allChannels;
    } else {
      channels = channelProvider.allChannels
          .where((c) => c.groupName == _selectedCategory)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部儴栏囬
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _selectedCategory ??
                    (AppStrings.of(context)?.allChannels ?? 'All Channels'),
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${channels.length} ${AppStrings.of(context)?.channels ?? 'channels'}',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 频道网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _buildChannelCard(context, channel, multiScreenProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard(BuildContext context, dynamic channel,
      MultiScreenProvider multiScreenProvider) {
    final forceAutoScroll = PlatformDetector.isWindows || PlatformDetector.isTV;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          multiScreenProvider.playChannelOnScreen(_targetScreenIndex, channel);
          refreshMultiScreenUi(() => _showChannelSelector = false);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.getGlassBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo区定煙 - 鍥定畾高度害
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0A0A0A)
                        : const Color(0xFFB8B8B8),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ChannelLogoWidget(
                          channel: channel,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 频道名称区域
              Expanded(
                flex: 1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Center(
                    child: AutoScrollText(
                      text: channel.name,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      scrollSpeed: 30.0,
                      scrollDelay: const Duration(milliseconds: 500),
                      textAlign: TextAlign.center,
                      forceScroll: forceAutoScroll,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
