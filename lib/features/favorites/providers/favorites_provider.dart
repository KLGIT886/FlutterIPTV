import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';

class FavoritesProvider extends ChangeNotifier {
  List<Channel> _favorites = [];
  bool _isLoading = false;
  String? _error;
  int? _activePlaylistId;

  // Getters
  List<Channel> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get count => _favorites.length;

  // Set active playlist ID
  void setActivePlaylistId(int playlistId) {
    if (_activePlaylistId != playlistId) {
      _activePlaylistId = playlistId;
      ServiceLocator.log.d('设置激活的播放列表ID: $playlistId');
    }
  }

  // Load favorites from database for current active playlist
  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 首先获取当前激活的播放列表ID（如果未设置）
      if (_activePlaylistId == null) {
        final playlistResult = await ServiceLocator.database.query(
          'playlists',
          where: 'is_active = ?',
          whereArgs: [1],
          limit: 1,
        );

        if (playlistResult.isNotEmpty) {
          _activePlaylistId = playlistResult.first['id'] as int;
          ServiceLocator.log.d('自动获取激活的播放列表ID: $_activePlaylistId');
        } else {
          ServiceLocator.log.d('没有找到激活的播放列表');
          _favorites = [];
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      ServiceLocator.log.d('加载播放列表 $_activePlaylistId 的收藏夹');

      // 只加载当前激活播放列表的收藏夹
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN favorites f ON c.id = f.channel_id
        WHERE c.is_active = 1 AND c.playlist_id = ?
        ORDER BY f.position ASC, f.created_at DESC
      ''', [_activePlaylistId]);

      _favorites = results.map((r) {
        final channel = Channel.fromMap(r);
        return channel.copyWith(isFavorite: true);
      }).toList();

      ServiceLocator.log.d('加载了 ${_favorites.length} 个收藏频道');
      _error = null;
    } catch (e) {
      _error = 'Failed to load favorites: $e';
      _favorites = [];
      ServiceLocator.log.d('加载收藏夹失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Check if a channel is favorited
  bool isFavorite(int channelId) {
    return _favorites.any((c) => c.id == channelId);
  }

  // Add a channel to favorites
  Future<bool> addFavorite(Channel channel) async {
    if (channel.id == null) return false;

    try {
      // Get the next position
      final positionResult = await ServiceLocator.database.rawQuery(
        'SELECT MAX(position) as max_pos FROM favorites',
      );
      final nextPosition = (positionResult.first['max_pos'] as int? ?? 0) + 1;

      // Insert favorite
      await ServiceLocator.database.insert('favorites', {
        'channel_id': channel.id,
        'position': nextPosition,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Update local list
      _favorites.add(channel.copyWith(isFavorite: true));
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to add favorite: $e';
      notifyListeners();
      return false;
    }
  }

  // Remove a channel from favorites
  Future<bool> removeFavorite(int channelId) async {
    try {
      await ServiceLocator.database.delete(
        'favorites',
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );

      _favorites.removeWhere((c) => c.id == channelId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to remove favorite: $e';
      notifyListeners();
      return false;
    }
  }

  // Toggle favorite status
  Future<bool> toggleFavorite(Channel channel) async {
    if (channel.id == null) {
      ServiceLocator.log.d('收藏切换失败: 频道ID为空 - ${channel.name}');
      return false;
    }

    ServiceLocator.log.d('收藏切换: 频道=${channel.name}, ID=${channel.id}, 当前状态=${isFavorite(channel.id!)}');

    if (isFavorite(channel.id!)) {
      final success = await removeFavorite(channel.id!);
      ServiceLocator.log.d('移除收藏${success ? "成功" : "失败"}');
      return success;
    } else {
      final success = await addFavorite(channel);
      ServiceLocator.log.d('添加收藏${success ? "成功" : "失败"}');
      return success;
    }
  }

  // Reorder favorites
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final channel = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, channel);

    // Update positions in database
    try {
      for (int i = 0; i < _favorites.length; i++) {
        await ServiceLocator.database.update(
          'favorites',
          {'position': i},
          where: 'channel_id = ?',
          whereArgs: [_favorites[i].id],
        );
      }
    } catch (e) {
      _error = 'Failed to reorder favorites: $e';
    }

    notifyListeners();
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    try {
      await ServiceLocator.database.delete('favorites');
      _favorites.clear();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear favorites: $e';
      notifyListeners();
    }
  }
}
