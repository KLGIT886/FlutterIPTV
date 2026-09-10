part of 'channels_screen.dart';

/// 频道测试与失效频道操作（从 _ChannelsScreenState 抽出的扩展）。
extension _ChannelsScreenTestActions on _ChannelsScreenState {
  Future<void> _confirmDeleteAllUnavailable(
      BuildContext context, ChannelProvider provider) async {
    final count = provider.unavailableChannelCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除所有失效频道',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          '确定要删除全部 $count 个失效频道吗？此操作不可撤销。',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final deletedCount = await provider.deleteAllUnavailableChannels();

      // 切换到全部频道
      immediateSetState(() {
        _selectedGroup = null;
      });
      provider.clearGroupFilter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 $deletedCount 个失效频道'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testSingleChannel(BuildContext context, dynamic channel) async {
    final testService = ChannelTestService();
    final channelObj = channel as Channel;

    // 显示测试中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('正在测试: ${channelObj.name}'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    final result = await testService.testChannel(channelObj);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 如果测试通过且是失效频道，自动恢复到原分类
      if (result.isAvailable &&
          ChannelProvider.isUnavailableChannel(channelObj.groupName)) {
        final provider = context.read<ChannelProvider>();
        final originalGroup =
            ChannelProvider.extractOriginalGroup(channelObj.groupName);
        await provider.restoreChannel(channelObj.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${channelObj.name} 可用，已恢复到 "$originalGroup" 分类'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.isAvailable ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.isAvailable
                        ? '${channelObj.name} 可用 (${result.responseTime}ms)'
                        : '${channelObj.name} 不可用: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor:
                result.isAvailable ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showChannelTestDialog(
      BuildContext context, List<dynamic> channels) async {
    final result = await showDialog<ChannelTestDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChannelTestDialog(
        channels: channels.cast<Channel>(),
      ),
    );

    if (result == null || !mounted) return;

    // 如果转入后台执行
    if (result.runInBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('测试已转入后台，剩余 ${result.remainingCount} 个频道'),
            ],
          ),
          backgroundColor: AppTheme.getPrimaryColor(context),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '查看进度',
            textColor: Colors.white,
            onPressed: () => _showBackgroundTestProgress(context),
          ),
        ),
      );
      return;
    }

    // 如果用户选择移动到失效分类
    if (result.movedToUnavailable) {
      final unavailableCount =
          result.results.where((r) => !r.isAvailable).length;

      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '已将 $unavailableCount 个失效频道移至"${ChannelProvider.unavailableGroupName}"分类'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: '查看',
            textColor: Colors.white,
            onPressed: () {
              // 跳转到失效分类
              immediateSetState(() {
                _selectedGroup = ChannelProvider.unavailableGroupName;
              });
              context
                  .read<ChannelProvider>()
                  .selectGroup(ChannelProvider.unavailableGroupName);
            },
          ),
        ),
      );

      // 自动跳转到失效分类
      immediateSetState(() {
        _selectedGroup = ChannelProvider.unavailableGroupName;
      });
      context
          .read<ChannelProvider>()
          .selectGroup(ChannelProvider.unavailableGroupName);
    }
  }

  void _showBackgroundTestProgress(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BackgroundTestProgressDialog(),
    );
  }

  // ignore: unused_element
  Future<void> _deleteUnavailableChannels(
      List<ChannelTestResult> results) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '确认删除',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          '确定要删除 ${results.length} 个不可用的频道吗？此操作不可撤销。',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 删除不可用频道
        for (final result in results) {
          if (result.channel.id != null) {
            await ServiceLocator.database.delete(
              'channels',
              where: 'id = ?',
              whereArgs: [result.channel.id],
            );
          }
        }

        // 刷新频道列表
        if (mounted) {
          context.read<ChannelProvider>().loadAllChannels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除 ${results.length} 个不可用频道'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showChannelOptions(BuildContext context, dynamic channel) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final isFavorite = favoritesProvider.isFavorite(channel.id ?? 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel name
              Text(
                channel.name,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Options
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? AppTheme.accentColor
                      : AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  isFavorite
                      ? (AppStrings.of(context)?.removeFavorites ??
                          'Remove from Favorites')
                      : (AppStrings.of(context)?.addFavorites ??
                          'Add to Favorites'),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () async {
                  await favoritesProvider.toggleFavorite(channel);
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  AppStrings.of(context)?.channelInfo ?? 'Channel Info',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show channel info dialog
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.speed_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  '测试频道',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _testSingleChannel(context, channel);
                },
              ),

              // 如果是失效频道，显示恢复选项
              if (ChannelProvider.isUnavailableChannel(channel.groupName))
                ListTile(
                  leading: const Icon(
                    Icons.restore_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(
                    '恢复到原分类 (${ChannelProvider.extractOriginalGroup(channel.groupName)})',
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final provider = context.read<ChannelProvider>();
                    final success = await provider.restoreChannel(channel.id!);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已恢复 ${channel.name} 到原分类'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
