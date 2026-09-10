part of 'channel_provider.dart';

/// 频道查询/筛选/首页选择逻辑（从 ChannelProvider 抽出的扩展）。
/// 通过 part 共享同一 library，可直接访问 ChannelProvider 的私有状态。
extension ChannelProviderQuery on ChannelProvider {
  List<Channel> get filteredChannels {
    if (_selectedGroup == null) return _allChannels;
    if (_selectedGroup == ChannelProvider.unavailableGroupName) {
      return _allChannels.where((c) => ChannelProvider.isUnavailableChannel(c.groupName)).toList();
    }
    return _allChannels.where((c) => c.groupName == _selectedGroup).toList();
  }

  // ✅ UI显示的筛选频道（分页显示）
  List<Channel> get displayedFilteredChannels {
    if (_selectedGroup == null) return _displayedChannels;
    if (_selectedGroup == ChannelProvider.unavailableGroupName) {
      return _displayedChannels.where((c) => ChannelProvider.isUnavailableChannel(c.groupName)).toList();
    }
    return _displayedChannels.where((c) => c.groupName == _selectedGroup).toList();
  }

  // ✅ 首页数据：获取指定数量的分类
  List<ChannelGroup> getHomeGroups({int maxGroups = 8}) {
    return _allGroups.take(maxGroups).toList();
  }

  // ✅ 首页数据：每个分类指定数量的频道
  Map<String, List<Channel>> getHomeChannelsByGroup({int maxGroups = 8, int channelsPerGroup = 12}) {
    final result = <String, List<Channel>>{};
    final groups = _allGroups.take(maxGroups);
    
    ServiceLocator.log.d(
        'getHomeChannelsByGroup: _allGroups.length=${_allGroups.length}, _allChannels.length=${_allChannels.length}',
        tag: 'ChannelProvider');
    
    for (final group in groups) {
      final channels = _allChannels
          .where((c) => c.groupName == group.name)
          .take(channelsPerGroup)
          .toList();
      
      // ServiceLocator.log.d(
      //     'getHomeChannelsByGroup: group=${group.name}, channels.length=${channels.length}',
      //     tag: 'ChannelProvider');
      
      // ✅ 即使没有频道也要包含分类（确保首页显示完整）
      result[group.name] = channels;
    }
    
    // ServiceLocator.log.d(
    //     'getHomeChannelsByGroup: result.length=${result.length}',
    //     tag: 'ChannelProvider');
    
    return result;
  }

  // Select a group filter
  void selectGroup(String? groupName) {
    _selectedGroup = groupName;

    // 切换分类时，清理台标加载队列，避免堆积
    try {
      clearLogoLoadingQueue();
      ServiceLocator.log.d('切换分类到: $groupName，已清理台标加载队列');
    } catch (e) {
      ServiceLocator.log.w('清理台标队列失败: $e');
    }

    _immediateNotify(); // 立即通知分类切换
  }

  // Clear group filter
  void clearGroupFilter() {
    _selectedGroup = null;
    _immediateNotify(); // 立即通知清除筛选
  }

  // Search channels by name
  List<Channel> searchChannels(String query) {
    if (query.isEmpty) return filteredChannels;

    final lowerQuery = query.toLowerCase();
    return _allChannels.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.groupName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get channels by group
  List<Channel> getChannelsByGroup(String groupName) {
    return _allChannels.where((c) => c.groupName == groupName).toList();
  }

  // Get a channel by ID
  Channel? getChannelById(int id) {
    try {
      return _allChannels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update favorite status for a channel
  void updateFavoriteStatus(int channelId, bool isFavorite) {
    final index = _allChannels.indexWhere((c) => c.id == channelId);
    if (index != -1) {
      _allChannels[index] = _allChannels[index].copyWith(isFavorite: isFavorite);
      _throttledNotify(); // 使用节流通知（非关键更新）
    }
  }

  // Set currently playing channel
  void setCurrentlyPlaying(int? channelId) {
    for (int i = 0; i < _allChannels.length; i++) {
      final isPlaying = _allChannels[i].id == channelId;
      if (_allChannels[i].isCurrentlyPlaying != isPlaying) {
        _allChannels[i] = _allChannels[i].copyWith(isCurrentlyPlaying: isPlaying);
      }
    }
    _throttledNotify(); // 使用节流通知（非关键更新）
  }

}
