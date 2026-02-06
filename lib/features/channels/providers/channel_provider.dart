import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/channel_group.dart';
import '../../../core/services/service_locator.dart';

class ChannelProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  List<ChannelGroup> _groups = [];
  String? _selectedGroup;
  bool _isLoading = false;
  String? _error;

  // ✅ 分页加载相关
  static const int _pageSize = 100; // 每页100个频道
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;

  // ✅ 台标加载控制
  bool _isLogoLoadingPaused = false;
  int _loadingGeneration = 0; // 用于取消旧的加载任务

  // Getters
  List<Channel> get channels => _channels;
  List<ChannelGroup> get groups => _groups;
  String? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  List<Channel> get filteredChannels {
    if (_selectedGroup == null) return _channels;
    // 如果选中失效频道分组，返回所有失效频道
    if (_selectedGroup == unavailableGroupName) {
      return _channels.where((c) => isUnavailableChannel(c.groupName)).toList();
    }
    return _channels.where((c) => c.groupName == _selectedGroup).toList();
  }

  int get totalChannelCount => _totalCount;
  int get loadedChannelCount => _channels.length;

  // ✅ 重置分页状态
  void _resetPagination() {
    _currentPage = 0;
    _hasMore = true;
    _totalCount = 0;
    _channels.clear();
  }

  // Load channels for a specific playlist (with pagination)
  Future<void> loadChannels(int playlistId, {bool loadMore = false}) async {
    if (!loadMore) {
      ServiceLocator.log.i('加载播放列表频道: $playlistId', tag: 'ChannelProvider');
      _resetPagination();
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    final startTime = DateTime.now();

    try {
      // 首次加载时获取总数
      if (!loadMore) {
        final countResult = await ServiceLocator.database.rawQuery(
          'SELECT COUNT(*) as count FROM channels WHERE playlist_id = ? AND is_active = 1',
          [playlistId],
        );
        _totalCount = countResult.first['count'] as int? ?? 0;
        ServiceLocator.log.d('频道总数: $_totalCount', tag: 'ChannelProvider');
      }

      // 分页查询
      final offset = _currentPage * _pageSize;
      final results = await ServiceLocator.database.query(
        'channels',
        where: 'playlist_id = ? AND is_active = 1',
        whereArgs: [playlistId],
        orderBy: 'id ASC',
        limit: _pageSize,
        offset: offset,
      );

      final newChannels = results.map((r) => Channel.fromMap(r)).toList();

      // ✅ 立即更新UI，然后后台处理备用台标
      if (loadMore) {
        _channels.addAll(newChannels);
        ServiceLocator.log.d(
            '加载更多: ${newChannels.length} 个频道，当前总数: ${_channels.length}/$_totalCount',
            tag: 'ChannelProvider');
      } else {
        _channels = newChannels;
        ServiceLocator.log
            .d('首次加载: ${_channels.length} 个频道', tag: 'ChannelProvider');
      }

      // 后台填充备用台标，不阻塞UI
      _populateFallbackLogos(newChannels, _loadingGeneration);

      _currentPage++;
      _hasMore = _channels.length < _totalCount;

      _updateGroups();

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i(
          '频道加载完成，耗时: ${loadTime}ms，已加载: ${_channels.length}/$_totalCount',
          tag: 'ChannelProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('加载频道失败', tag: 'ChannelProvider', error: e);
      _error = 'Failed to load channels: $e';
      if (!loadMore) {
        _channels = [];
        _groups = [];
      }
    }

    if (loadMore) {
      _isLoadingMore = false;
      // ✅ 加载更多时不调用 notifyListeners()，避免整个列表重建
      // 列表会自动检测到 channels.length 变化并更新
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all channels from all active playlists (with pagination)
  Future<void> loadAllChannels({bool loadMore = false}) async {
    if (!loadMore) {
      _resetPagination();
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      // 首次加载时获取总数
      if (!loadMore) {
        final countResult = await ServiceLocator.database.rawQuery('''
          SELECT COUNT(*) as count FROM channels c
          INNER JOIN playlists p ON c.playlist_id = p.id
          WHERE c.is_active = 1 AND p.is_active = 1
        ''');
        _totalCount = countResult.first['count'] as int? ?? 0;
        ServiceLocator.log.d('所有频道总数: $_totalCount', tag: 'ChannelProvider');
      }

      // 分页查询
      final offset = _currentPage * _pageSize;
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN playlists p ON c.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY c.id ASC
        LIMIT $_pageSize OFFSET $offset
      ''');

      final newChannels = results.map((r) => Channel.fromMap(r)).toList();

      // ✅ 立即更新UI，然后后台处理备用台标
      if (loadMore) {
        _channels.addAll(newChannels);
        ServiceLocator.log.d(
            '加载更多: ${newChannels.length} 个频道，当前总数: ${_channels.length}/$_totalCount',
            tag: 'ChannelProvider');
      } else {
        _channels = newChannels;
        ServiceLocator.log
            .d('首次加载: ${_channels.length} 个频道', tag: 'ChannelProvider');
      }

      // 后台填充备用台标，不阻塞UI
      _populateFallbackLogos(newChannels, _loadingGeneration);

      _currentPage++;
      _hasMore = _channels.length < _totalCount;

      _updateGroups();
      _error = null;
    } catch (e) {
      _error = 'Failed to load channels: $e';
      if (!loadMore) {
        _channels = [];
        _groups = [];
      }
    }

    if (loadMore) {
      _isLoadingMore = false;
      // ✅ 加载更多时不调用 notifyListeners()，避免整个列表重建
      // 列表会自动检测到 channels.length 变化并更新
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateGroups() {
    final Map<String, int> groupCounts = {};
    final List<String> groupOrder = []; // 保持原始顺序
    int unavailableCount = 0;

    for (final channel in _channels) {
      final group = channel.groupName ?? 'Uncategorized';
      // 将所有失效频道合并到一个分组
      if (isUnavailableChannel(group)) {
        unavailableCount++;
      } else {
        if (!groupCounts.containsKey(group)) {
          groupOrder.add(group); // 记录首次出现的顺序
        }
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }
    }

    // 按原始顺序创建分组列表
    _groups = groupOrder
        .map((name) =>
            ChannelGroup(name: name, channelCount: groupCounts[name] ?? 0))
        .toList();

    // 如果有失效频道，添加到列表末尾
    if (unavailableCount > 0) {
      _groups.add(ChannelGroup(
          name: unavailableGroupName, channelCount: unavailableCount));
    }
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

    notifyListeners();
  }

  // Clear group filter
  void clearGroupFilter() {
    _selectedGroup = null;
    notifyListeners();
  }

  // Search channels by name
  List<Channel> searchChannels(String query) {
    if (query.isEmpty) return filteredChannels;

    final lowerQuery = query.toLowerCase();
    return _channels.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.groupName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get channels by group
  List<Channel> getChannelsByGroup(String groupName) {
    return _channels.where((c) => c.groupName == groupName).toList();
  }

  // Get a channel by ID
  Channel? getChannelById(int id) {
    try {
      return _channels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update favorite status for a channel
  void updateFavoriteStatus(int channelId, bool isFavorite) {
    final index = _channels.indexWhere((c) => c.id == channelId);
    if (index != -1) {
      _channels[index] = _channels[index].copyWith(isFavorite: isFavorite);
      notifyListeners();
    }
  }

  // Set currently playing channel
  void setCurrentlyPlaying(int? channelId) {
    for (int i = 0; i < _channels.length; i++) {
      final isPlaying = _channels[i].id == channelId;
      if (_channels[i].isCurrentlyPlaying != isPlaying) {
        _channels[i] = _channels[i].copyWith(isCurrentlyPlaying: isPlaying);
      }
    }
    notifyListeners();
  }

  // Add channels from parsing
  Future<void> addChannels(List<Channel> channels) async {
    try {
      for (final channel in channels) {
        await ServiceLocator.database.insert('channels', channel.toMap());
      }

      // Reload channels
      if (channels.isNotEmpty) {
        await loadChannels(channels.first.playlistId);
      }
    } catch (e) {
      _error = 'Failed to add channels: $e';
      notifyListeners();
    }
  }

  // Delete channels for a playlist
  Future<void> deleteChannelsForPlaylist(int playlistId) async {
    try {
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      _channels.removeWhere((c) => c.playlistId == playlistId);
      _updateGroups();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete channels: $e';
      notifyListeners();
    }
  }

  // 失效频道分类名称前缀
  static const String unavailableGroupPrefix = '⚠️ 失效频道';
  static const String unavailableGroupName = '⚠️ 失效频道';

  // 从失效分组名中提取原始分组名
  static String? extractOriginalGroup(String? groupName) {
    if (groupName == null || !groupName.startsWith(unavailableGroupPrefix)) {
      return null;
    }
    // 格式: "⚠️ 失效频道|原始分组名"
    final parts = groupName.split('|');
    if (parts.length > 1) {
      return parts[1];
    }
    return 'Uncategorized';
  }

  // 检查是否是失效频道
  static bool isUnavailableChannel(String? groupName) {
    return groupName != null && groupName.startsWith(unavailableGroupPrefix);
  }

  // 将频道标记为失效（移动到失效分类，保留原始分组信息）
  Future<void> markChannelsAsUnavailable(List<int> channelIds) async {
    if (channelIds.isEmpty) return;

    try {
      // 批量更新频道分组，保存原始分组名
      for (final id in channelIds) {
        final channel = _channels.firstWhere((c) => c.id == id,
            orElse: () => _channels.first);
        final originalGroup = channel.groupName ?? 'Uncategorized';
        // 如果已经是失效频道，不重复标记
        if (isUnavailableChannel(originalGroup)) continue;

        final newGroupName = '$unavailableGroupPrefix|$originalGroup';

        await ServiceLocator.database.update(
          'channels',
          {'group_name': newGroupName},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 更新内存中的频道数据
      for (int i = 0; i < _channels.length; i++) {
        if (channelIds.contains(_channels[i].id)) {
          final originalGroup = _channels[i].groupName ?? 'Uncategorized';
          if (!isUnavailableChannel(originalGroup)) {
            _channels[i] = _channels[i].copyWith(
              groupName: '$unavailableGroupPrefix|$originalGroup',
            );
          }
        }
      }

      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: 已将 ${channelIds.length} 个频道标记为失效');
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 标记失效频道时出错: $e');
      _error = 'Failed to mark channels as unavailable: $e';
      notifyListeners();
    }
  }

  // 恢复失效频道到原分组
  Future<bool> restoreChannel(int channelId) async {
    try {
      final channel = _channels.firstWhere((c) => c.id == channelId);
      final originalGroup = extractOriginalGroup(channel.groupName);

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

      final index = _channels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _channels[index] = _channels[index].copyWith(groupName: originalGroup);
      }

      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: 已恢复频道到分组: $originalGroup');
      return true;
    } catch (e) {
      _error = 'Failed to restore channel: $e';
      notifyListeners();
      return false;
    }
  }

  // 删除所有失效频道
  Future<int> deleteAllUnavailableChannels() async {
    try {
      final count = await ServiceLocator.database.delete(
        'channels',
        where: 'group_name LIKE ?',
        whereArgs: ['$unavailableGroupPrefix%'],
      );

      _channels.removeWhere((c) => isUnavailableChannel(c.groupName));
      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: 已删除 $count 个失效频道');
      return count;
    } catch (e) {
      _error = 'Failed to delete unavailable channels: $e';
      notifyListeners();
      return 0;
    }
  }

  // 获取失效频道数量
  int get unavailableChannelCount {
    return _channels.where((c) => isUnavailableChannel(c.groupName)).length;
  }

  // ✅ 暂停台标加载（例如在快速滚动时）
  void pauseLogoLoading() {
    _isLogoLoadingPaused = true;
  }

  // ✅ 恢复台标加载
  void resumeLogoLoading() {
    _isLogoLoadingPaused = false;
  }

  // ✅ 清理台标加载队列（取消当前所有后台加载任务）
  void clearLogoLoadingQueue() {
    _loadingGeneration++;
  }

  // ✅ 后台填充备用台标 (批量处理优化版)
  Future<void> _populateFallbackLogos(
      List<Channel> channelsToProcess, int generationId) async {
    // return; // 暂时禁用，测试性能
    final stopwatch = Stopwatch()..start();
    int processedCount = 0;
    // 使用大批量处理，因为现在是单次调用
    const batchSize = 20;

    // 创建一个副本进行迭代，避免在迭代时修改列表
    final List<Channel> processingList = List.from(channelsToProcess);

    for (int i = 0; i < processingList.length; i += batchSize) {
      // 检查任务是否已取消
      if (generationId != _loadingGeneration) return;

      // 如果暂停加载，等待直到恢复
      while (_isLogoLoadingPaused) {
        if (generationId != _loadingGeneration) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final end = (i + batchSize < processingList.length)
          ? i + batchSize
          : processingList.length;
      final batch = processingList.sublist(i, end);

      // 筛选需要查询台标的频道
      final channelsToQuery =
          batch.where((c) => c.logoUrl == null || c.logoUrl!.isEmpty).toList();

      if (channelsToQuery.isNotEmpty) {
        try {
          final names = channelsToQuery.map((c) => c.name).toList();
          // 批量查询，显著减少 Platform Channel 消息数量
          final logos =
              await ServiceLocator.channelLogo.findLogoUrlsBulk(names);

          // 更新结果
          for (final channel in channelsToQuery) {
            if (logos.containsKey(channel.name)) {
              channel.fallbackLogoUrl = logos[channel.name];
              processedCount++;
            }
          }
        } catch (e) {
          ServiceLocator.log.w('批量获取台标失败: $e');
        }
      }

      // 每处理完一个批次，Yield 给 UI 线程
      // 此时 UI 应该非常流畅，因为我们每 20 个项目才唤醒一次主线程处理 IO
      if (i + batchSize < processingList.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    stopwatch.stop();
    if (processedCount > 0 && generationId == _loadingGeneration) {
      ServiceLocator.log.i(
          '备用台标处理完成，为 $processedCount 个频道找到台标，耗时: ${stopwatch.elapsedMilliseconds}ms',
          tag: 'ChannelProvider');
      // notifyListeners();
    }
  }

  // Clear all data
  void clear() {
    _channels = [];
    _groups = [];
    _selectedGroup = null;
    _error = null;
    notifyListeners();
  }
}
