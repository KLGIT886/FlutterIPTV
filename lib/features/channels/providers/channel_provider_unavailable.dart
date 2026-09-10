part of 'channel_provider.dart';

/// 失效频道相关逻辑（从 ChannelProvider 抽出的扩展）。
/// 通过 part 共享同一 library，可直接访问 ChannelProvider 的私有状态。
extension ChannelProviderUnavailable on ChannelProvider {
  // 将频道标记为失效（移动到失效分类，保留原始分组信息）
  Future<void> markChannelsAsUnavailable(List<int> channelIds) async {
    if (channelIds.isEmpty) return;

    try {
      // 批量更新频道分组，保存原始分组名
      for (final id in channelIds) {
        final channel = _allChannels.firstWhere((c) => c.id == id,
            orElse: () => _allChannels.first);
        final originalGroup = channel.groupName ?? 'Uncategorized';
        // 如果已经是失效频道，不重复标记
        if (ChannelProvider.isUnavailableChannel(originalGroup)) continue;

        final newGroupName = '$ChannelProvider.unavailableGroupPrefix|$originalGroup';

        await ServiceLocator.database.update(
          'channels',
          {'group_name': newGroupName},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 更新内存中的频道数据
      for (int i = 0; i < _allChannels.length; i++) {
        if (channelIds.contains(_allChannels[i].id)) {
          final originalGroup = _allChannels[i].groupName ?? 'Uncategorized';
          if (!ChannelProvider.isUnavailableChannel(originalGroup)) {
            _allChannels[i] = _allChannels[i].copyWith(
              groupName: '$ChannelProvider.unavailableGroupPrefix|$originalGroup',
            );
          }
        }
      }

      _updateGroups();
      _immediateNotify(); // 立即通知标记完成

      ServiceLocator.log.d('DEBUG: 已将 ${channelIds.length} 个频道标记为失效');
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 标记失效频道时出错: $e');
      _error = 'Failed to mark channels as unavailable: $e';
      _immediateNotify(); // 立即通知错误
    }
  }

  // 恢复失效频道到原分组
  Future<bool> restoreChannel(int channelId) async {
    try {
      final channel = _allChannels.firstWhere((c) => c.id == channelId);
      final originalGroup = ChannelProvider.extractOriginalGroup(channel.groupName);

      if (originalGroup == null) {
        ServiceLocator.log.d('DEBUG: 频道不是失效频道，无需恢复');
        return false;
      }

      await ServiceLocator.database.update(
        'channels',
        {'group_name': originalGroup},
        where: 'id = ?',
        whereArgs: [channelId],
      );

      final index = _allChannels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _allChannels[index] = _allChannels[index].copyWith(groupName: originalGroup);
      }

      _updateGroups();
      _immediateNotify(); // 立即通知恢复完成

      ServiceLocator.log.d('DEBUG: 已恢复频道到分组: $originalGroup');
      return true;
    } catch (e) {
      _error = 'Failed to restore channel: $e';
      _immediateNotify(); // 立即通知错误
      return false;
    }
  }

  // 删除所有失效频道
  Future<int> deleteAllUnavailableChannels() async {
    try {
      final count = await ServiceLocator.database.delete(
        'channels',
        where: 'group_name LIKE ?',
        whereArgs: ['$ChannelProvider.unavailableGroupPrefix%'],
      );

      _allChannels.removeWhere((c) => ChannelProvider.isUnavailableChannel(c.groupName));
      _updateGroups();
      _immediateNotify(); // 立即通知删除完成

      ServiceLocator.log.d('DEBUG: 已删除 $count 个失效频道');
      return count;
    } catch (e) {
      _error = 'Failed to delete unavailable channels: $e';
      _immediateNotify(); // 立即通知错误
      return 0;
    }
  }

  // 获取失效频道数量
  int get unavailableChannelCount {
    return _allChannels.where((c) => ChannelProvider.isUnavailableChannel(c.groupName)).length;
  }

}
