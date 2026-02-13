import '../database/database_helper.dart';
import '../models/channel.dart';
import '../services/service_locator.dart';

class WatchHistoryService {
  final DatabaseHelper _db = ServiceLocator.database;

  /// 添加观看记录
  Future<void> addWatchHistory(int channelId, int playlistId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查是否已存在该频道的记录
      final existing = await _db.rawQuery('''
        SELECT id FROM watch_history 
        WHERE channel_id = ? AND playlist_id = ?
      ''', [channelId, playlistId]);
      
      if (existing.isNotEmpty) {
        // 更新现有记录的时间
        await _db.update(
          'watch_history',
          {'watched_at': now},
          where: 'channel_id = ? AND playlist_id = ?',
          whereArgs: [channelId, playlistId],
        );
      } else {
        // 插入新记录
        await _db.insert('watch_history', {
          'channel_id': channelId,
          'playlist_id': playlistId,
          'watched_at': now,
          'duration_seconds': 0,
        });
      }
    } catch (e) {
      ServiceLocator.log.e('添加观看记录失败: $e', tag: 'WatchHistoryService');
    }
  }

  /// 获取观看记录（按播放列表分组）
  /// limit 参数控制返回的最大记录数，默认20条
  Future<List<Channel>> getWatchHistory(int playlistId, {int limit = 20}) async {
    try {
      // 使用 INNER JOIN 查询观看记录和对应的频道信息
      // 只返回存在且激活的频道，按观看时间倒序排列，限制返回数量
      final result = await _db.rawQuery('''
        SELECT c.*, wh.watched_at
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        WHERE wh.playlist_id = ? AND c.is_active = 1 AND c.playlist_id = ?
        ORDER BY wh.watched_at DESC
        LIMIT ?
      ''', [playlistId, playlistId, limit]);

      return result.map((row) {
        return Channel(
          id: row['id'] as int,
          name: row['name'] as String,
          url: row['url'] as String,
          logoUrl: row['logo_url'] as String?,
          groupName: row['group_name'] as String?,
          epgId: row['epg_id'] as String?,
          sources: _parseSources(row['sources'] as String?),
          playlistId: row['playlist_id'] as int,
          isActive: (row['is_active'] as int) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        );
      }).toList();
    } catch (e, stackTrace) {
      ServiceLocator.log.e('获取观看记录失败: $e\n$stackTrace', tag: 'WatchHistoryService');
      return [];
    }
  }

  /// 获取所有播放列表的观看记录（用于首页显示）
  Future<List<Channel>> getAllWatchHistory({int limit = 20}) async {
    try {
      final result = await _db.rawQuery('''
        SELECT c.*, wh.watched_at, p.name as playlist_name
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        INNER JOIN playlists p ON wh.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY wh.watched_at DESC
        LIMIT ?
      ''', [limit]);

      return result.map((row) {
        return Channel(
          id: row['id'] as int,
          name: row['name'] as String,
          url: row['url'] as String,
          logoUrl: row['logo_url'] as String?,
          groupName: row['group_name'] as String?,
          epgId: row['epg_id'] as String?,
          sources: _parseSources(row['sources'] as String?),
          playlistId: row['playlist_id'] as int,
          isActive: (row['is_active'] as int) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        );
      }).toList();
    } catch (e) {
      ServiceLocator.log.e('获取所有观看记录失败: $e');
      return [];
    }
  }

  /// 清除指定播放列表的观看记录
  Future<void> clearWatchHistory(int playlistId) async {
    try {
      await _db.delete(
        'watch_history',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      ServiceLocator.log.d('已清除播放列表$playlistId 的观看记录');
    } catch (e) {
      ServiceLocator.log.e('清除观看记录失败: $e');
    }
  }

  /// 清除所有观看记录
  Future<void> clearAllWatchHistory() async {
    try {
      await _db.delete('watch_history');
      ServiceLocator.log.d('已清除所有观看记录');
    } catch (e) {
      ServiceLocator.log.e('清除所有观看记录失败: $e');
    }
  }

  /// 刷新播放列表前保存观看记录的频道信息
  /// 返回一个Map，key是观看记录ID，value是频道的名称和URL
  Future<Map<int, Map<String, String>>> saveWatchHistoryChannelInfo(int playlistId) async {
    try {
      ServiceLocator.log.i('保存播放列表$playlistId 的观看记录频道信息', tag: 'WatchHistoryService');
      
      // 获取观看记录及其对应的频道信息
      final historyRecords = await _db.rawQuery('''
        SELECT wh.id, c.name, c.url
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        WHERE wh.playlist_id = ?
      ''', [playlistId]);
      
      final Map<int, Map<String, String>> channelInfo = {};
      for (final record in historyRecords) {
        final historyId = record['id'] as int;
        final name = record['name'] as String;
        final url = record['url'] as String;
        channelInfo[historyId] = {'name': name, 'url': url};
      }
      
      ServiceLocator.log.i('保存了 ${channelInfo.length} 条观看记录的频道信息', tag: 'WatchHistoryService');
      return channelInfo;
    } catch (e) {
      ServiceLocator.log.e('保存观看记录频道信息失败: $e', tag: 'WatchHistoryService');
      return {};
    }
  }

  /// 刷新播放列表后更新观看记录的频道ID
  /// 使用之前保存的频道信息来匹配新的频道ID
  Future<void> updateChannelIdsAfterRefresh(
    int playlistId,
    Map<int, Map<String, String>> savedChannelInfo,
  ) async {
    try {
      ServiceLocator.log.i('开始更新播放列表$playlistId 的观看记录频道ID', tag: 'WatchHistoryService');
      
      // 1. 先删除超过20条的旧记录
      final countResult = await _db.rawQuery('''
        SELECT COUNT(*) as count FROM watch_history WHERE playlist_id = ?
      ''', [playlistId]);
      final count = countResult.first['count'] as int;
      
      if (count > 20) {
        // 获取要保留的最新20条记录的ID
        final keepIds = await _db.rawQuery('''
          SELECT id FROM watch_history 
          WHERE playlist_id = ? 
          ORDER BY watched_at DESC 
          LIMIT 20
        ''', [playlistId]);
        
        final keepIdList = keepIds.map((row) => row['id'] as int).join(',');
        
        // 删除不在保留列表中的记录
        await _db.rawQuery('''
          DELETE FROM watch_history 
          WHERE playlist_id = ? AND id NOT IN ($keepIdList)
        ''', [playlistId]);
        
        ServiceLocator.log.i('删除了 ${count - 20} 条旧观看记录', tag: 'WatchHistoryService');
      }
      
      int updatedCount = 0;
      int deletedCount = 0;
      
      // 2. 遍历保存的频道信息，更新或删除观看记录
      for (final entry in savedChannelInfo.entries) {
        final historyId = entry.key;
        final channelName = entry.value['name']!;
        final channelUrl = entry.value['url']!;
        
        // 检查这条观看记录是否还存在（可能在步骤1中被删除了）
        final historyExists = await _db.rawQuery('''
          SELECT id FROM watch_history WHERE id = ?
        ''', [historyId]);
        
        if (historyExists.isEmpty) {
          // 观看记录已被删除（超过20条），跳过
          continue;
        }
        
        // 通过名称和URL查找新的频道ID
        final newChannels = await _db.rawQuery('''
          SELECT id FROM channels 
          WHERE name = ? AND url = ? AND playlist_id = ? AND is_active = 1
          LIMIT 1
        ''', [channelName, channelUrl, playlistId]);
        
        if (newChannels.isNotEmpty) {
          final newChannelId = newChannels.first['id'] as int;
          
          // 更新频道ID
          await _db.update(
            'watch_history',
            {'channel_id': newChannelId},
            where: 'id = ?',
            whereArgs: [historyId],
          );
          updatedCount++;
        } else {
          // 频道不存在了，删除这条观看记录
          await _db.delete(
            'watch_history',
            where: 'id = ?',
            whereArgs: [historyId],
          );
          deletedCount++;
          ServiceLocator.log.d('删除观看记录 $historyId (频道 "$channelName" 不存在)', tag: 'WatchHistoryService');
        }
      }
      
      ServiceLocator.log.i('观看记录更新完成: 更新了 $updatedCount 条，删除了 $deletedCount 条（频道不存在）', tag: 'WatchHistoryService');
    } catch (e) {
      ServiceLocator.log.e('更新观看记录频道ID失败: $e', tag: 'WatchHistoryService');
    }
  }

  /// 清理观看记录（删除超过20条的旧记录）
  /// 刷新播放列表后清理观看记录
  /// 只删除超过20条的旧记录，保留最新的20条
  Future<void> cleanupWatchHistoryAfterRefresh(int playlistId) async {
    try {
      ServiceLocator.log.i('开始清理播放列表$playlistId 的观看记录', tag: 'WatchHistoryService');
      
      // 删除超过20条的旧记录
      final countResult = await _db.rawQuery('''
        SELECT COUNT(*) as count FROM watch_history WHERE playlist_id = ?
      ''', [playlistId]);
      final count = countResult.first['count'] as int;
      
      if (count > 20) {
        // 获取要保留的最新20条记录的ID
        final keepIds = await _db.rawQuery('''
          SELECT id FROM watch_history 
          WHERE playlist_id = ? 
          ORDER BY watched_at DESC 
          LIMIT 20
        ''', [playlistId]);
        
        final keepIdList = keepIds.map((row) => row['id'] as int).join(',');
        
        // 删除不在保留列表中的记录
        await _db.rawQuery('''
          DELETE FROM watch_history 
          WHERE playlist_id = ? AND id NOT IN ($keepIdList)
        ''', [playlistId]);
        
        ServiceLocator.log.i('删除了 ${count - 20} 条旧观看记录，保留最新20条', tag: 'WatchHistoryService');
      } else {
        ServiceLocator.log.i('观看记录数量 $count <= 20，无需清理', tag: 'WatchHistoryService');
      }
    } catch (e) {
      ServiceLocator.log.e('清理观看记录失败: $e', tag: 'WatchHistoryService');
    }
  }

  /// 解析多源字符串
  List<String> _parseSources(String? sourcesStr) {
    if (sourcesStr == null || sourcesStr.isEmpty) return [];
    try {
      // 假设sources是用逗号分隔的字符串
      return sourcesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }
}