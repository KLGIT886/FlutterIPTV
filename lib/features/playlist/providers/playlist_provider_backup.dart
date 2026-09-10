part of 'playlist_provider.dart';

/// 备份文件生命周期与临时文件清理（从 PlaylistProvider 抽出的扩展）。
/// 通过 part 共享同一 library，可直接访问私有状态与私有方法。
extension PlaylistBackupActions on PlaylistProvider {
  Future<void> _createMissingBackups() async {
    for (final playlistId in _playlistsNeedingBackup.toList()) {
      try {
        await _createBackupForPlaylist(playlistId);
        _playlistsNeedingBackup.remove(playlistId);
      } catch (e) {
        ServiceLocator.log.w('为播放列表 $playlistId 创建备份失败: $e', tag: 'PlaylistProvider');
      }
    }
  }
  
  /// 为指定播放列表创建备份
  Future<void> _createBackupForPlaylist(int playlistId) async {
    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => Playlist(name: ''),
    );
    
    if (playlist.id == null) {
      ServiceLocator.log.w('播放列表ID为空，跳过备份创建', tag: 'PlaylistProvider');
      return;
    }
    
    String? sourceContent;
    
    // 尝试从各种来源获取内容
    try {
      if (playlist.url != null && playlist.url!.isNotEmpty) {
        // 从URL重新下载
        ServiceLocator.log.d('从URL获取播放列表内容: ${playlist.url}', tag: 'PlaylistProvider');
        sourceContent = await _downloadContentFromUrl(playlist.url!);
      } else if (playlist.filePath != null && playlist.filePath!.isNotEmpty) {
        // 从原始文件读取
        final file = File(playlist.filePath!);
        if (await file.exists()) {
          ServiceLocator.log.d('从文件读取播放列表内容: ${playlist.filePath}', tag: 'PlaylistProvider');
          sourceContent = await file.readAsString();
        } else {
          ServiceLocator.log.w('原始文件不存在: ${playlist.filePath}', tag: 'PlaylistProvider');
        }
      }
      
      // 如果上述方法都失败，尝试从旧的临时文件查找
      sourceContent ??= await _tryFindOldTempFile(playlistId);
    } catch (e) {
      ServiceLocator.log.w('获取播放列表内容失败: $e', tag: 'PlaylistProvider');
    }
    
    if (sourceContent != null && sourceContent.isNotEmpty) {
      // 创建备份文件
      final backupPath = await _saveBackupFile(playlistId, sourceContent, playlist.format);
      
      // 更新数据库
      await ServiceLocator.database.update(
        'playlists',
        {
          'backup_path': backupPath,
          'file_path': backupPath, // 同时更新file_path以保持向后兼容
          'last_backup_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      
      ServiceLocator.log.i('成功为播放列表 "${playlist.name}" (ID: $playlistId) 创建备份: $backupPath', tag: 'PlaylistProvider');
    } else {
      ServiceLocator.log.w('无法获取播放列表 "${playlist.name}" (ID: $playlistId) 的内容，跳过备份创建', tag: 'PlaylistProvider');
    }
  }
  
  /// 从URL下载内容
  Future<String> _downloadContentFromUrl(String url,
      {CancelToken? cancelToken}) async {
    final dio = Dio();
    // 显式超时，避免大列表在无网络/慢速情况下无限挂起（P1-12）
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    final response = await dio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status! < 500,
      ),
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200) {
      return response.data.toString();
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// 取消正在进行的导入下载（若有），避免长时间卡在整份列表下载上。
  void cancelImport() {
    _importCancelToken?.cancel('用户取消导入');
    _importCancelToken = null;
  }
  
  /// 保存备份文件
  Future<String> _saveBackupFile(int playlistId, String content, String format) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/playlists/backups');
    
    // 确保备份目录存在
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
      ServiceLocator.log.d('创建备份目录: ${backupDir.path}', tag: 'PlaylistProvider');
    }
    
    // 使用固定文件名（不带时间戳），便于更新
    final extension = format.toLowerCase() == 'txt' ? 'txt' : 'm3u';
    final backupFile = File('${backupDir.path}/playlist_${playlistId}_backup.$extension');
    
    await backupFile.writeAsString(content);
    ServiceLocator.log.d('保存备份文件: ${backupFile.path}', tag: 'PlaylistProvider');
    
    return backupFile.path;
  }
  
  /// 尝试从旧的临时目录查找文件（兼容旧版本）
  Future<String?> _tryFindOldTempFile(int playlistId) async {
    try {
      // 查找临时目录中的旧文件
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return null;
      
      final files = tempDir.listSync();
      final pattern = RegExp('playlist_${playlistId}_\\d+\\.m3u');
      
      for (final file in files) {
        if (file is File && pattern.hasMatch(file.path)) {
          ServiceLocator.log.i('找到旧版本临时文件: ${file.path}', tag: 'PlaylistProvider');
          final content = await file.readAsString();
          
          // 迁移：删除旧临时文件（已经创建备份）
          try {
            await file.delete();
            ServiceLocator.log.d('删除旧临时文件: ${file.path}', tag: 'PlaylistProvider');
          } catch (e) {
            ServiceLocator.log.w('删除旧临时文件失败: $e', tag: 'PlaylistProvider');
          }
          
          return content;
        }
      }
      
      // 也检查永久存储目录中的旧文件
      final appDir = await getApplicationDocumentsDirectory();
      final playlistDir = Directory('${appDir.path}/playlists');
      if (await playlistDir.exists()) {
        final playlistFiles = playlistDir.listSync();
        for (final file in playlistFiles) {
          if (file is File && pattern.hasMatch(file.path)) {
            ServiceLocator.log.i('找到旧版本播放列表文件: ${file.path}', tag: 'PlaylistProvider');
            return await file.readAsString();
          }
        }
      }
    } catch (e) {
      ServiceLocator.log.w('查找旧文件失败: $e', tag: 'PlaylistProvider');
    }
    
    return null;
  }
  
  /// 更新备份文件
  Future<void> _updateBackupFile(int playlistId, String content, String format) async {
    try {
      final backupPath = await _saveBackupFile(playlistId, content, format);
      
      // 更新数据库
      await ServiceLocator.database.update(
        'playlists',
        {
          'backup_path': backupPath,
          'file_path': backupPath, // 同时更新file_path以保持向后兼容
          'last_backup_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      
      ServiceLocator.log.d('更新播放列表 $playlistId 的备份文件', tag: 'PlaylistProvider');
    } catch (e) {
      ServiceLocator.log.w('更新备份文件失败: $e', tag: 'PlaylistProvider');
    }
  }
}

