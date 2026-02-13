import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/m3u_parser.dart';
import '../../../core/utils/txt_parser.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Playlist? _activePlaylist;
  bool _isLoading = false;
  String? _error;
  double _importProgress = 0.0;

  /// Last extracted EPG URL from M3U file (for UI display only)
  String? _lastExtractedEpgUrl;
  String? get lastExtractedEpgUrl => _lastExtractedEpgUrl;

  // Getters

  // Getters
  List<Playlist> get playlists => _playlists;
  Playlist? get activePlaylist => _activePlaylist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get importProgress => _importProgress;

  bool get hasPlaylists => _playlists.isNotEmpty;

  String _sortBy = 'name ASC';
  String get sortBy => _sortBy;

  void toggleSortOrder() {
    if (_sortBy == 'name ASC') {
      _sortBy = 'created_at DESC';
    } else {
      _sortBy = 'name ASC';
    }
    loadPlaylists();
  }

  // Load all playlists from database
  Future<void> loadPlaylists() async {
    ServiceLocator.log.i('开始加载播放列表', tag: 'PlaylistProvider');
    final startTime = DateTime.now();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.query(
        'playlists',
        orderBy: _sortBy,
      );

      _playlists = results.map((r) => Playlist.fromMap(r)).toList();
      ServiceLocator.log.d('从数据库加载了 ${_playlists.length} 个播放列表', tag: 'PlaylistProvider');
      
      // 调试：打印每个播放列表的 EPG URL
      for (final playlist in _playlists) {
        ServiceLocator.log.d('播放列表 "${playlist.name}" (ID: ${playlist.id}) - epgUrl: ${playlist.epgUrl ?? "(未配置)"}', tag: 'PlaylistProvider');
      }

      // Load channel counts for each playlist
      for (int i = 0; i < _playlists.length; i++) {
        final countResult = await ServiceLocator.database.rawQuery(
          'SELECT COUNT(*) as count, COUNT(DISTINCT group_name) as groups FROM channels WHERE playlist_id = ?',
          [_playlists[i].id],
        );

        if (countResult.isNotEmpty) {
          _playlists[i] = _playlists[i].copyWith(
            channelCount: countResult.first['count'] as int? ?? 0,
            groupCount: countResult.first['groups'] as int? ?? 0,
          );
        }
      }

      // Set active playlist if none selected
      if (_activePlaylist == null && _playlists.isNotEmpty) {
        _activePlaylist = _playlists.firstWhere(
          (p) => p.isActive,
          orElse: () => _playlists.first,
        );
        ServiceLocator.log.d('设置活动播放列表: ${_activePlaylist?.name}', tag: 'PlaylistProvider');
      }

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('播放列表加载完成，耗时: ${loadTime}ms', tag: 'PlaylistProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('加载播放列表失败', tag: 'PlaylistProvider', error: e);
      _error = 'Failed to load playlists: $e';
      _playlists = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Detect playlist format from URL or content
  /// Returns 'txt' for TXT format, 'm3u' for M3U format
  String _detectPlaylistFormat(String source, {String? content}) {
    // Check by extension first
    final lowerSource = source.toLowerCase();
    if (lowerSource.endsWith('.txt')) {
      return 'txt';
    }
    if (lowerSource.endsWith('.m3u') || lowerSource.endsWith('.m3u8')) {
      return 'm3u';
    }

    // Check by content if available
    if (content != null) {
      final trimmed = content.trim();
      // TXT format typically starts with category or has ,#genre# pattern
      if (trimmed.contains(',#genre#')) {
        return 'txt';
      }
      // M3U format starts with #EXTM3U
      if (trimmed.startsWith('#EXTM3U') || trimmed.startsWith('#EXTINF')) {
        return 'm3u';
      }
    }

    // Default to M3U
    return 'm3u';
  }

  /// Common import logic extracted to reduce code duplication
  /// Supports URL, content, and file path sources
  Future<Playlist?> _importPlaylist({
    required String name,
    String? url,
    String? content,
    String? filePath,
    String? mergeRule, // Add merge rule parameter
  }) async {
    ServiceLocator.log.i('导入播放列表: $name', tag: 'PlaylistProvider');
    if (url != null) ServiceLocator.log.d('URL: $url', tag: 'PlaylistProvider');
    if (filePath != null) ServiceLocator.log.d('文件路径: $filePath', tag: 'PlaylistProvider');
    
    final startTime = DateTime.now();
    
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    int? playlistId;
    String? tempFilePath;
    
    try {
      // Step 1: Create playlist record (10%)
      final playlistData = Playlist(
        name: name,
        url: url,
        filePath: filePath,
        createdAt: DateTime.now(),
      ).toMap();

      playlistId = await ServiceLocator.database.insert('playlists', playlistData);
      ServiceLocator.log.d('创建播放列表记录，ID: $playlistId', tag: 'PlaylistProvider');

      _importProgress = 0.1;
      notifyListeners();

      // Step 2: Parse channels (15% - 50%)
      final List<Channel> channels;
      String? epgUrl;
      
      // Use provided merge rule or default to 'name_group'
      final effectiveMergeRule = mergeRule ?? 'name_group';
      ServiceLocator.log.d('使用频道合并规则: $effectiveMergeRule', tag: 'PlaylistProvider');
      
      if (url != null) {
        // From URL
        final format = _detectPlaylistFormat(url);
        ServiceLocator.log.i('检测到播放列表格式: $format', tag: 'PlaylistProvider');
        
        _importProgress = 0.15;
        notifyListeners();
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromUrl(url, playlistId!, mergeRule: effectiveMergeRule);
        } else {
          channels = await M3UParser.parseFromUrl(url, playlistId!, mergeRule: effectiveMergeRule);
          epgUrl = M3UParser.lastParseResult?.epgUrl;
        }
      } else if (content != null) {
        // From content string
        final format = _detectPlaylistFormat('', content: content);
        ServiceLocator.log.i('检测到播放列表格式: $format', tag: 'PlaylistProvider');
        
        _importProgress = 0.15;
        notifyListeners();
        
        if (format == 'txt') {
          channels = TXTParser.parse(content, playlistId!, mergeRule: effectiveMergeRule);
        } else {
          channels = M3UParser.parse(content, playlistId!, mergeRule: effectiveMergeRule);
          epgUrl = M3UParser.lastParseResult?.epgUrl;
        }
        
        // Save content as temporary file for future refreshes
        final tempDir = await getTemporaryDirectory();
        
        // Clean up old temp files for this playlist before creating new one
        await _cleanupOldTempFiles(tempDir, playlistId!);
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/playlist_${playlistId}_$timestamp.m3u');
        await tempFile.writeAsString(content);
        tempFilePath = tempFile.path;
        
        ServiceLocator.log.d('保存临时播放列表文件: $tempFilePath', tag: 'PlaylistProvider');
      } else if (filePath != null) {
        // From local file
        final format = _detectPlaylistFormat(filePath);
        ServiceLocator.log.i('检测到播放列表格式: $format', tag: 'PlaylistProvider');
        
        _importProgress = 0.15;
        notifyListeners();
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromFile(filePath, playlistId!, mergeRule: effectiveMergeRule);
        } else {
          channels = await M3UParser.parseFromFile(filePath, playlistId!, mergeRule: effectiveMergeRule);
          epgUrl = M3UParser.lastParseResult?.epgUrl;
        }
      } else {
        throw Exception('No valid source provided (url, content, or filePath required)');
      }

      _importProgress = 0.5;
      notifyListeners();

      if (channels.isEmpty) {
        ServiceLocator.log.w('播放列表中没有找到频道', tag: 'PlaylistProvider');
        throw Exception('No channels found in playlist');
      }
      
      ServiceLocator.log.i('解析到 ${channels.length} 个频道', tag: 'PlaylistProvider');

      // ✅ Step 3: 批量查询备用台标 (50% - 60%)
      ServiceLocator.log.i('开始批量查询备用台标', tag: 'PlaylistProvider');
      final channelNames = channels.map((c) => c.name).toList();
      final fallbackLogos = await ServiceLocator.channelLogo.findLogoUrlsBulk(channelNames);
      
      // 将查询到的备用台标赋值给频道
      for (final channel in channels) {
        if (fallbackLogos.containsKey(channel.name)) {
          channel.fallbackLogoUrl = fallbackLogos[channel.name];
        }
      }
      
      ServiceLocator.log.i('备用台标查询完成，找到 ${fallbackLogos.length} 个台标', tag: 'PlaylistProvider');
      
      _importProgress = 0.6;
      notifyListeners();

      // Step 4: Insert channels in transaction (60% - 90%)
      await ServiceLocator.database.db.transaction((txn) async {
        // Batch insert channels in chunks
        const chunkSize = 500;
        for (int i = 0; i < channels.length; i += chunkSize) {
          final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
          final chunk = channels.sublist(i, end);
          
          final batch = txn.batch();
          for (final channel in chunk) {
            batch.insert('channels', channel.toMap());
          }
          await batch.commit(noResult: true);
          
          ServiceLocator.log.d('已插入 $end/${channels.length} 个频道', tag: 'PlaylistProvider');
        }

        // Update playlist with metadata
        final updateData = <String, dynamic>{
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
        };
        
        if (epgUrl != null) {
          updateData['epg_url'] = epgUrl;
          _lastExtractedEpgUrl = epgUrl;
          ServiceLocator.log.d('保存EPG URL: $epgUrl', tag: 'PlaylistProvider');
        }
        
        if (tempFilePath != null) {
          updateData['file_path'] = tempFilePath;
        }
        
        await txn.update(
          'playlists',
          updateData,
          where: 'id = ?',
          whereArgs: [playlistId],
        );
      });

      // Update progress after transaction (90%)
      _importProgress = 0.9;
      notifyListeners();

      _importProgress = 0.95;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();
      
      // Run ANALYZE to update database statistics after large import
      if (playlistId != null) {
        try {
          await ServiceLocator.database.db.execute('ANALYZE');
          ServiceLocator.log.d('数据库统计信息已更新', tag: 'PlaylistProvider');
        } catch (e) {
          ServiceLocator.log.w('更新数据库统计信息失败: $e', tag: 'PlaylistProvider');
        }
      }

      _importProgress = 1.0;
      notifyListeners();

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('播放列表导入成功，总耗时: ${totalTime}ms', tag: 'PlaylistProvider');
      
      await ServiceLocator.log.flush();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      ServiceLocator.log.e('导入播放列表失败', tag: 'PlaylistProvider', error: e);
      
      // Cleanup on failure
      if (playlistId != null) {
        try {
          await ServiceLocator.database.delete(
            'playlists',
            where: 'id = ?',
            whereArgs: [playlistId],
          );
          await ServiceLocator.database.delete(
            'channels',
            where: 'playlist_id = ?',
            whereArgs: [playlistId],
          );
        } catch (cleanupError) {
          ServiceLocator.log.w('清理失败的导入数据时出错', tag: 'PlaylistProvider', error: cleanupError);
        }
      }
      
      if (tempFilePath != null) {
        try {
          final file = File(tempFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (cleanupError) {
          ServiceLocator.log.w('清理临时文件失败', tag: 'PlaylistProvider', error: cleanupError);
        }
      }
      
      _error = 'Failed to import playlist: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Clean up old temporary files for a playlist
  Future<void> _cleanupOldTempFiles(Directory tempDir, int playlistId) async {
    try {
      final files = tempDir.listSync();
      final pattern = RegExp('playlist_${playlistId}_\\d+\\.m3u');
      
      for (final file in files) {
        if (file is File && pattern.hasMatch(file.path)) {
          try {
            await file.delete();
            ServiceLocator.log.d('删除旧临时文件: ${file.path}', tag: 'PlaylistProvider');
          } catch (e) {
            ServiceLocator.log.w('删除旧临时文件失败: ${file.path}', tag: 'PlaylistProvider', error: e);
          }
        }
      }
    } catch (e) {
      ServiceLocator.log.w('清理旧临时文件时出错', tag: 'PlaylistProvider', error: e);
    }
  }

  // Add a new playlist from URL
  Future<Playlist?> addPlaylistFromUrl(String name, String url, {String? mergeRule}) async {
    return _importPlaylist(name: name, url: url, mergeRule: mergeRule);
  }

  // Add a new playlist from M3U content directly (for QR import)
  Future<Playlist?> addPlaylistFromContent(String name, String content, {String? mergeRule}) async {
    return _importPlaylist(name: name, content: content, mergeRule: mergeRule);
  }

  // Add a new playlist from local file
  Future<Playlist?> addPlaylistFromFile(String name, String filePath, {String? mergeRule}) async {
    return _importPlaylist(name: name, filePath: filePath, mergeRule: mergeRule);
  }

  // Refresh a playlist from its source
  // If silent=true, runs in background without blocking UI
  Future<bool> refreshPlaylist(Playlist playlist, {bool silent = false, String? mergeRule}) async {
    if (playlist.id == null) return false;

    ServiceLocator.log.d('开始刷新播放列表: ${playlist.name} (ID: ${playlist.id}), 静默模式: $silent', tag: 'PlaylistProvider');
    ServiceLocator.log.d('playlist.url = ${playlist.url}', tag: 'PlaylistProvider');
    ServiceLocator.log.d('playlist.filePath = ${playlist.filePath}', tag: 'PlaylistProvider');
    ServiceLocator.log.d('playlist.isRemote = ${playlist.isRemote}', tag: 'PlaylistProvider');
    ServiceLocator.log.d('playlist.isLocal = ${playlist.isLocal}', tag: 'PlaylistProvider');

    if (!silent) {
      _isLoading = true;
      _importProgress = 0.0;
      _error = null;
      notifyListeners();
    }

    try {
      // 重新从数据库加载 playlist 以确保数据是最新的
      final dbResults = await ServiceLocator.database.query(
        'playlists',
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      if (dbResults.isEmpty) {
        throw Exception('Playlist not found in database');
      }

      final freshPlaylist = Playlist.fromMap(dbResults.first);
      ServiceLocator.log.d('从数据库重新加载 - URL: ${freshPlaylist.url}, FilePath: ${freshPlaylist.filePath}', tag: 'PlaylistProvider');

      List<Channel> channels;

      // Use provided merge rule or default to 'name_group'
      final effectiveMergeRule = mergeRule ?? 'name_group';
      ServiceLocator.log.d('使用频道合并规则: $effectiveMergeRule', tag: 'PlaylistProvider');

      ServiceLocator.log.d('播放列表源类型: ${freshPlaylist.isRemote ? "远程URL" : freshPlaylist.isLocal ? "本地文件" : "未知"}', tag: 'PlaylistProvider');
      ServiceLocator.log.d('播放列表源路径: ${freshPlaylist.sourcePath}', tag: 'PlaylistProvider');

      if (freshPlaylist.isRemote) {
        ServiceLocator.log.d('开始从URL解析播放列表: ${freshPlaylist.url}', tag: 'PlaylistProvider');
        
        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.url!);
        ServiceLocator.log.d('检测到播放列表格式: $format', tag: 'PlaylistProvider');
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromUrl(freshPlaylist.url!, playlist.id!, mergeRule: effectiveMergeRule);
        } else {
          channels = await M3UParser.parseFromUrl(freshPlaylist.url!, playlist.id!, mergeRule: effectiveMergeRule);
        }
        
        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('从M3U提取到EPG URL: $_lastExtractedEpgUrl', tag: 'PlaylistProvider');
          }
        }
      } else if (freshPlaylist.isLocal) {
        ServiceLocator.log.d('开始从本地文件解析播放列表: ${freshPlaylist.filePath}', tag: 'PlaylistProvider');

        // Check if file exists before trying to parse
        final file = File(freshPlaylist.filePath!);
        if (!await file.exists()) {
          ServiceLocator.log.d('本地文件不存在: ${freshPlaylist.filePath}', tag: 'PlaylistProvider');
          throw Exception('Local playlist file not found: ${freshPlaylist.filePath}');
        }

        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.filePath!);
        ServiceLocator.log.d('检测到播放列表格式: $format', tag: 'PlaylistProvider');
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromFile(freshPlaylist.filePath!, playlist.id!, mergeRule: effectiveMergeRule);
        } else {
          channels = await M3UParser.parseFromFile(freshPlaylist.filePath!, playlist.id!, mergeRule: effectiveMergeRule);
        }
        
        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('从M3U提取到EPG URL: $_lastExtractedEpgUrl', tag: 'PlaylistProvider');
          }
        }
      } else {
        // Check if this is a content-imported playlist without a proper file path
        ServiceLocator.log.d('播放列表源无效，URL: ${freshPlaylist.url}, 文件路径: ${freshPlaylist.filePath}', tag: 'PlaylistProvider');
        throw Exception('Invalid playlist source - URL: ${freshPlaylist.url}, File: ${freshPlaylist.filePath}');
      }

      ServiceLocator.log.d('解析完成，共找到 ${channels.length} 个频道', tag: 'PlaylistProvider');

      if (!silent) {
        _importProgress = 0.5;
        notifyListeners();
      }

      // ✅ 批量查询备用台标（与导入流程一致）
      ServiceLocator.log.i('开始批量查询备用台标', tag: 'PlaylistProvider');
      final channelNames = channels.map((c) => c.name).toList();
      final fallbackLogos = await ServiceLocator.channelLogo.findLogoUrlsBulk(channelNames);
      
      // 将查询到的备用台标赋值给频道
      for (final channel in channels) {
        if (fallbackLogos.containsKey(channel.name)) {
          channel.fallbackLogoUrl = fallbackLogos[channel.name];
        }
      }
      
      ServiceLocator.log.i('备用台标查询完成，找到 ${fallbackLogos.length} 个台标', tag: 'PlaylistProvider');

      if (!silent) {
        _importProgress = 0.6;
        notifyListeners();
      }

      // 在删除旧频道之前，先保存观看记录的频道信息（名称和URL）
      ServiceLocator.log.d('保存观看记录的频道信息...', tag: 'PlaylistProvider');
      final savedChannelInfo = await ServiceLocator.watchHistory.saveWatchHistoryChannelInfo(playlist.id!);
      ServiceLocator.log.d('已保存 ${savedChannelInfo.length} 条观看记录的频道信息', tag: 'PlaylistProvider');

      // ✅ 在删除旧频道之前，保存收藏的频道名称和位置
      ServiceLocator.log.d('保存收藏频道信息...', tag: 'PlaylistProvider');
      final favoriteChannelNames = await _saveFavoriteChannelNames(playlist.id!);
      ServiceLocator.log.d('已保存 ${favoriteChannelNames.length} 个收藏频道', tag: 'PlaylistProvider');

      // 使用事务确保数据一致性：先删除旧数据，再插入新数据
      // 如果插入失败，事务会回滚，旧数据不会丢失
      await ServiceLocator.database.db.transaction((txn) async {
        // Delete existing channels
        ServiceLocator.log.d('开始删除现有频道数据...', tag: 'PlaylistProvider');
        final deleteResult = await txn.delete(
          'channels',
          where: 'playlist_id = ?',
          whereArgs: [playlist.id],
        );
        ServiceLocator.log.d('已删除 $deleteResult 个旧频道记录', tag: 'PlaylistProvider');

        // Insert new channels - 使用批量插入以提高性能，分块处理避免内存问题
        const chunkSize = 500;
        for (int i = 0; i < channels.length; i += chunkSize) {
          final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
          final chunk = channels.sublist(i, end);
          
          final batch = txn.batch();
          for (final channel in chunk) {
            final channelMap = channel.toMap();
            batch.insert('channels', channelMap);
          }
          await batch.commit(noResult: true);
          ServiceLocator.log.d('已插入 $end/${channels.length} 个新频道记录', tag: 'PlaylistProvider');
        }
      });

      // ✅ 恢复收藏关联
      if (favoriteChannelNames.isNotEmpty) {
        ServiceLocator.log.d('开始恢复收藏关联...', tag: 'PlaylistProvider');
        final restoredCount = await _restoreFavoritesByName(playlist.id!, favoriteChannelNames);
        ServiceLocator.log.d('已恢复 $restoredCount 个收藏频道', tag: 'PlaylistProvider');
      }

      // Update playlist timestamp and EPG URL
      ServiceLocator.log.d('更新播放列表时间戳和EPG URL...', tag: 'PlaylistProvider');
      final updateData = <String, dynamic>{
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'channel_count': channels.length,
      };
      
      // 如果提取到了 EPG URL，也更新到数据库
      if (_lastExtractedEpgUrl != null) {
        updateData['epg_url'] = _lastExtractedEpgUrl;
        ServiceLocator.log.d('保存EPG URL到数据库: $_lastExtractedEpgUrl', tag: 'PlaylistProvider');
      }
      
      await ServiceLocator.database.update(
        'playlists',
        updateData,
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      if (!silent) {
        _importProgress = 1.0;
        ServiceLocator.log.d('刷新完成，进度: 100%', tag: 'PlaylistProvider');
        notifyListeners();
      }

      // 更新观看记录的频道ID（通过名称和URL匹配新的频道ID）
      ServiceLocator.log.d('开始更新观看记录的频道ID...', tag: 'PlaylistProvider');
      await ServiceLocator.watchHistory.updateChannelIdsAfterRefresh(playlist.id!, savedChannelInfo);
      ServiceLocator.log.d('观看记录频道ID更新完成', tag: 'PlaylistProvider');

      // 清除重定向缓存（因为播放列表已更新，URL可能已变化）
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('已清除重定向缓存（刷新播放列表）', tag: 'PlaylistProvider');

      // Reload playlists
      ServiceLocator.log.d('重新加载播放列表数据...', tag: 'PlaylistProvider');
      await loadPlaylists();

      ServiceLocator.log.d('播放列表刷新成功完成', tag: 'PlaylistProvider');
      
      if (!silent) {
        _isLoading = false;
      }
      
      // ✅ 通知其他 Provider 刷新数据（收藏夹已恢复，需要重新加载）
      notifyListeners();
      
      return true;
    } catch (e) {
      ServiceLocator.log.e('刷新播放列表时发生错误', tag: 'PlaylistProvider', error: e);
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}', tag: 'PlaylistProvider');
      _error = 'Failed to refresh playlist: $e';
      
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
      
      return false;
    }
  }

  // Delete a playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      // Find the playlist before deletion to check for temp files
      final playlist = _playlists.firstWhere(
        (p) => p.id == playlistId, 
        orElse: () => Playlist(name: '')
      );
      final wasActive = _activePlaylist?.id == playlistId;

      // Use transaction for data consistency
      await ServiceLocator.database.db.transaction((txn) async {
        // Delete channels first (cascade should handle this, but being explicit)
        await txn.delete(
          'channels',
          where: 'playlist_id = ?',
          whereArgs: [playlistId],
        );

        // Delete playlist
        await txn.delete(
          'playlists',
          where: 'id = ?',
          whereArgs: [playlistId],
        );
      });

      // Delete temporary file if this is a temporary playlist
      if (playlist.isTemporary && playlist.filePath != null) {
        try {
          final file = File(playlist.filePath!);
          if (await file.exists()) {
            await file.delete();
            ServiceLocator.log.d('已删除临时播放列表文件: ${playlist.filePath}', tag: 'PlaylistProvider');
          }
        } catch (e) {
          ServiceLocator.log.w('删除临时文件时出错: $e', tag: 'PlaylistProvider');
        }
      }

      // 清除重定向缓存（因为播放列表的URL可能已失效）
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('已清除重定向缓存（删除播放列表）', tag: 'PlaylistProvider');

      // Update local state
      _playlists.removeWhere((p) => p.id == playlistId);

      // If the deleted playlist was active, switch to the first available playlist
      if (wasActive) {
        if (_playlists.isNotEmpty) {
          _activePlaylist = _playlists.first;
          // Save the new active playlist to database
          await ServiceLocator.prefs.setInt('active_playlist_id', _activePlaylist!.id!);
          ServiceLocator.log.d('删除后切换到播放列表: ${_activePlaylist!.name} (ID: ${_activePlaylist!.id})', tag: 'PlaylistProvider');
        } else {
          _activePlaylist = null;
          await ServiceLocator.prefs.remove('active_playlist_id');
          ServiceLocator.log.d('没有剩余播放列表', tag: 'PlaylistProvider');
        }
      }

      notifyListeners();

      // Run VACUUM in background to reclaim space (don't await to avoid blocking UI)
      optimizeDatabase().then((_) {
        ServiceLocator.log.d('删除播放列表后数据库优化完成', tag: 'PlaylistProvider');
      }).catchError((e) {
        ServiceLocator.log.w('删除播放列表后数据库优化失败: $e', tag: 'PlaylistProvider');
      });

      return true;
    } catch (e) {
      ServiceLocator.log.e('删除播放列表失败', tag: 'PlaylistProvider', error: e);
      _error = 'Failed to delete playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Set active playlist
  void setActivePlaylist(Playlist playlist, {Function(int)? onPlaylistChanged, FavoritesProvider? favoritesProvider}) async {
    ServiceLocator.log.d('DEBUG: 设置激活播放列表: ${playlist.name} (ID: ${playlist.id})');
    _activePlaylist = playlist;

    // Update database to mark this playlist as active
    if (playlist.id != null) {
      try {
        // Mark all playlists as inactive
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 0},
        );

        // Mark this playlist as active
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [playlist.id],
        );
      } catch (e) {
        ServiceLocator.log.d('DEBUG: 更新数据库激活状态时出错: $e');
      }
    }

    // Notify listeners immediately for UI update
    notifyListeners();

    // Trigger channel loading via callback
    if (playlist.id != null && onPlaylistChanged != null) {
      try {
        ServiceLocator.log.d('DEBUG: 触发播放列表频道加载回调...');
        onPlaylistChanged(playlist.id!);
      } catch (e) {
        ServiceLocator.log.d('DEBUG: 执行播放列表频道加载回调时出错: $e');
      }
    }

    // Update favorites provider with the new active playlist
    if (playlist.id != null && favoritesProvider != null) {
      try {
        ServiceLocator.log.d('DEBUG: 更新收藏夹提供者的激活播放列表ID...');
        favoritesProvider.setActivePlaylistId(playlist.id!);
        await favoritesProvider.loadFavorites();
      } catch (e) {
        ServiceLocator.log.d('DEBUG: 更新收藏夹时出错: $e');
      }
    }
  }

  // Update playlist
  Future<bool> updatePlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    try {
      await ServiceLocator.database.update(
        'playlists',
        playlist.toMap(),
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      final index = _playlists.indexWhere((p) => p.id == playlist.id);
      if (index != -1) {
        _playlists[index] = playlist;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clean up all old temporary playlist files
  Future<void> cleanupAllTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      final pattern = RegExp(r'playlist_\d+_\d+\.m3u');
      
      int deletedCount = 0;
      for (final file in files) {
        if (file is File && pattern.hasMatch(file.path)) {
          try {
            await file.delete();
            deletedCount++;
          } catch (e) {
            ServiceLocator.log.w('删除临时文件失败: ${file.path}', tag: 'PlaylistProvider');
          }
        }
      }
      
      if (deletedCount > 0) {
        ServiceLocator.log.i('清理了 $deletedCount 个临时播放列表文件', tag: 'PlaylistProvider');
      }
    } catch (e) {
      ServiceLocator.log.e('清理临时文件失败', tag: 'PlaylistProvider', error: e);
    }
  }

  /// Refresh playlist with callback for UI updates
  /// This is a unified method for both home screen and playlist screen
  Future<void> refreshPlaylistWithCallback({
    required Playlist playlist,
    required BuildContext context,
    bool silent = false,
    Function(bool success, String? error)? onComplete,
  }) async {
    if (playlist.id == null) {
      onComplete?.call(false, 'Invalid playlist ID');
      return;
    }

    final startTime = DateTime.now();

    // Show initial message (must be on main thread)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(silent 
              ? '正在后台刷新 ${playlist.name}...' 
              : '刷新中 ${playlist.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Get merge rule from settings
    final settings = context.read<SettingsProvider>();
    final mergeRule = settings.channelMergeRule;

    // Execute refresh
    final success = await refreshPlaylist(playlist, silent: silent, mergeRule: mergeRule);
    
    final refreshTime = DateTime.now().difference(startTime).inMilliseconds;

    // Use scheduleMicrotask to ensure we're on the main thread for UI updates
    if (context.mounted) {
      scheduleMicrotask(() {
        if (!context.mounted) return;
        
        if (success) {
          ServiceLocator.log.i('播放列表刷新成功，耗时: ${refreshTime}ms', tag: 'PlaylistProvider');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${playlist.name} 刷新成功'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ServiceLocator.log.e('播放列表刷新失败', tag: 'PlaylistProvider');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${playlist.name} 刷新失败: ${_error?.replaceAll("Exception:", "").trim() ?? "未知错误"}'),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }

    // Call completion callback
    onComplete?.call(success, success ? null : _error);
  }

  /// Optimize database by running VACUUM
  /// Should be called after large deletions or periodically
  Future<bool> optimizeDatabase() async {
    try {
      ServiceLocator.log.i('开始优化数据库', tag: 'PlaylistProvider');
      
      final sizeBefore = await ServiceLocator.database.getDatabaseSize();
      await ServiceLocator.database.vacuum();
      final sizeAfter = await ServiceLocator.database.getDatabaseSize();
      
      final savedBytes = sizeBefore - sizeAfter;
      final savedMB = (savedBytes / (1024 * 1024)).toStringAsFixed(2);
      
      ServiceLocator.log.i('数据库优化完成，回收空间: ${savedMB}MB', tag: 'PlaylistProvider');
      return true;
    } catch (e) {
      ServiceLocator.log.e('数据库优化失败', tag: 'PlaylistProvider', error: e);
      return false;
    }
  }

  /// ✅ 保存收藏频道的名称和位置（刷新前）
  Future<Map<String, int>> _saveFavoriteChannelNames(int playlistId) async {
    try {
      ServiceLocator.log.i('开始查询播放列表 $playlistId 的收藏频道', tag: 'PlaylistProvider');
      
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.name, f.position
        FROM favorites f
        INNER JOIN channels c ON f.channel_id = c.id
        WHERE c.playlist_id = ?
        ORDER BY f.position
      ''', [playlistId]);
      
      ServiceLocator.log.i('查询到 ${results.length} 条收藏记录', tag: 'PlaylistProvider');
      
      final Map<String, int> favoriteMap = {};
      for (final row in results) {
        final name = row['name'] as String;
        final position = row['position'] as int;
        favoriteMap[name] = position;
        ServiceLocator.log.d('收藏频道: $name (位置: $position)', tag: 'PlaylistProvider');
      }
      
      return favoriteMap;
    } catch (e) {
      ServiceLocator.log.e('保存收藏频道信息失败', tag: 'PlaylistProvider', error: e);
      return {};
    }
  }

  /// ✅ 根据频道名称恢复收藏关联（刷新后）
  Future<int> _restoreFavoritesByName(int playlistId, Map<String, int> favoriteMap) async {
    try {
      ServiceLocator.log.i('开始恢复 ${favoriteMap.length} 个收藏频道', tag: 'PlaylistProvider');
      int restoredCount = 0;
      
      for (final entry in favoriteMap.entries) {
        final channelName = entry.key;
        final position = entry.value;
        
        ServiceLocator.log.d('查找频道: $channelName', tag: 'PlaylistProvider');
        
        // 查找新插入的频道ID
        final results = await ServiceLocator.database.rawQuery('''
          SELECT id FROM channels 
          WHERE playlist_id = ? AND name = ? 
          LIMIT 1
        ''', [playlistId, channelName]);
        
        if (results.isNotEmpty) {
          final channelId = results.first['id'] as int;
          
          ServiceLocator.log.d('找到频道ID: $channelId，恢复收藏', tag: 'PlaylistProvider');
          
          // 重新创建收藏记录
          await ServiceLocator.database.insert('favorites', {
            'channel_id': channelId,
            'position': position,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
          
          restoredCount++;
        } else {
          ServiceLocator.log.w('未找到收藏频道: $channelName', tag: 'PlaylistProvider');
        }
      }
      
      ServiceLocator.log.i('成功恢复 $restoredCount 个收藏频道', tag: 'PlaylistProvider');
      return restoredCount;
    } catch (e) {
      ServiceLocator.log.e('恢复收藏关联失败', tag: 'PlaylistProvider', error: e);
      return 0;
    }
  }
}
