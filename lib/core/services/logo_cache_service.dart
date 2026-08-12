import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'service_locator.dart';
import '../widgets/channel_logo_widget.dart';

/// 台标图片缓存服务
///
/// 功能：
/// - 管理台标图片的磁盘缓存配置（过期时间、最大数量）
/// - 提供缓存大小统计、清理缓存功能
/// - 当设置变化时，动态重建底层 CacheManager
class LogoCacheService {
  // 当前配置
  Duration _stalePeriod;
  int _maxNrOfCacheObjects;
  bool _enabled;

  // 配置访问器
  Duration get stalePeriod => _stalePeriod;
  int get maxNrOfCacheObjects => _maxNrOfCacheObjects;
  bool get enabled => _enabled;

  /// 应用默认配置（与 LogoCacheManager 保持一致）
  static const Duration defaultStalePeriod = Duration(days: 7);
  static const int defaultMaxNrOfCacheObjects = 500;
  static const bool defaultEnabled = true;

  LogoCacheService({
    Duration? stalePeriod,
    int? maxNrOfCacheObjects,
    bool? enabled,
  })  : _stalePeriod = stalePeriod ?? defaultStalePeriod,
        _maxNrOfCacheObjects =
            maxNrOfCacheObjects ?? defaultMaxNrOfCacheObjects,
        _enabled = enabled ?? defaultEnabled;

  /// 更新缓存配置
  /// 会触发底层 LogoCacheManager 的重建（下次使用时生效）
  Future<void> updateConfig({
    Duration? stalePeriod,
    int? maxNrOfCacheObjects,
    bool? enabled,
  }) async {
    final changed = (stalePeriod != null && stalePeriod != _stalePeriod) ||
        (maxNrOfCacheObjects != null &&
            maxNrOfCacheObjects != _maxNrOfCacheObjects) ||
        (enabled != null && enabled != _enabled);

    if (stalePeriod != null) _stalePeriod = stalePeriod;
    if (maxNrOfCacheObjects != null) {
      _maxNrOfCacheObjects = maxNrOfCacheObjects;
    }
    if (enabled != null) _enabled = enabled;

    if (changed) {
      ServiceLocator.log.i(
          '[LogoCacheService] 配置已更新: enabled=$_enabled, stalePeriod=${_stalePeriod.inDays}天, maxObjects=$_maxNrOfCacheObjects');
    }
  }

  /// 获取缓存目录大小（字节）
  /// 遍历 logoCache 目录，累加所有文件大小
  Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await _getCacheDir();
      if (cacheDir == null || !await cacheDir.exists()) {
        return 0;
      }

      int total = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (e) {
      ServiceLocator.log.w('[LogoCacheService] 获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取格式化的缓存大小字符串（如 "1.23 MB"）
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSizeBytes();
    return _formatBytes(bytes);
  }

  /// 诊断：记录缓存目录和元数据文件的实际路径
  /// 用于验证缓存是否工作正常
  Future<void> logCachePaths() async {
    final cacheDir = await _getCacheDir();
    final metaFile = await _getMetadataFile();
    final exists = cacheDir != null && await cacheDir.exists();
    final metaExists = metaFile != null && await metaFile.exists();
    ServiceLocator.log.i(
        '[LogoCacheService] 缓存目录: ${cacheDir?.path ?? "null"} (存在: $exists), '
        '元数据文件: ${metaFile?.path ?? "null"} (存在: $metaExists)');
  }

  /// 获取缓存条目数量
  /// 通过 flutter_cache_manager 的数据库查询
  Future<int> getCacheObjectCount() async {
    try {
      final cacheDir = await _getCacheDir();
      if (cacheDir == null || !await cacheDir.exists()) {
        return 0;
      }

      int count = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          // 排除 .json 元数据文件（只计实际的图片文件）
          if (!entity.path.endsWith('.json')) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      ServiceLocator.log.w('[LogoCacheService] 获取缓存条目数失败: $e');
      return 0;
    }
  }

  /// 清空所有台标缓存
  /// 删除缓存文件目录和元数据 JSON 文件，并重置 CacheManager 单例
  Future<void> clearAllCache() async {
    try {
      ServiceLocator.log.i('[LogoCacheService] 开始清空台标缓存');

      // 1. 删除缓存文件目录（图片文件）
      final cacheDir = await _getCacheDir();
      if (cacheDir != null && await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        ServiceLocator.log.i('[LogoCacheService] 已删除缓存目录: ${cacheDir.path}');
      }

      // 2. 重建空目录
      if (cacheDir != null) {
        await cacheDir.create(recursive: true);
      }

      // 3. 删除元数据 JSON 文件
      final metaFile = await _getMetadataFile();
      if (metaFile != null && await metaFile.exists()) {
        await metaFile.delete();
        ServiceLocator.log.i('[LogoCacheService] 已删除元数据文件: ${metaFile.path}');
      }

      // 4. 强制重置 LogoCacheManager 单例（下次访问会重新创建，使用最新配置）
      _resetLogoCacheManagerInstance();

      ServiceLocator.log.i('[LogoCacheService] 台标缓存已清空');
    } catch (e) {
      ServiceLocator.log.e('[LogoCacheService] 清空缓存失败: $e');
    }
  }

  /// 清理过期缓存（超过 stalePeriod 的文件）
  Future<void> clearExpiredCache() async {
    try {
      ServiceLocator.log.i('[LogoCacheService] 开始清理过期缓存');
      final cacheDir = await _getCacheDir();
      if (cacheDir == null || !await cacheDir.exists()) {
        return;
      }

      final now = DateTime.now();
      int removedCount = 0;
      int removedBytes = 0;

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);
            if (age > _stalePeriod) {
              final size = stat.size;
              await entity.delete();
              removedCount++;
              removedBytes += size;
            }
          } catch (_) {}
        }
      }

      ServiceLocator.log.i(
          '[LogoCacheService] 过期缓存清理完成: 删除 $removedCount 个文件，共 ${_formatBytes(removedBytes)}');
    } catch (e) {
      ServiceLocator.log.e('[LogoCacheService] 清理过期缓存失败: $e');
    }
  }

  // ========================================
  // 内部方法
  // ========================================

  /// 获取台标缓存文件目录
  ///
  /// flutter_cache_manager 3.4.2 的 IOFileSystem 将缓存文件存储在：
  ///   getTemporaryDirectory()/{cacheKey}
  /// 即：getTemporaryDirectory()/logoCache
  Future<Directory?> _getCacheDir() async {
    try {
      final baseDir = await getTemporaryDirectory();
      return Directory(p.join(baseDir.path, 'logoCache'));
    } catch (e) {
      ServiceLocator.log.w('[LogoCacheService] 获取缓存目录失败: $e');
      return null;
    }
  }

  /// 获取台标缓存元数据 JSON 文件
  ///
  /// JsonCacheInfoRepository 将元数据存储在：
  ///   getApplicationSupportDirectory()/{databaseName}.json
  /// 即：getApplicationSupportDirectory()/logoCache.json
  Future<File?> _getMetadataFile() async {
    try {
      final baseDir = await getApplicationSupportDirectory();
      return File(p.join(baseDir.path, 'logoCache.json'));
    } catch (e) {
      ServiceLocator.log.w('[LogoCacheService] 获取元数据文件失败: $e');
      return null;
    }
  }

  /// 重置 LogoCacheManager 单例（下次访问时重建）
  void _resetLogoCacheManagerInstance() {
    resetLogoCacheManager();
  }

  /// 格式化字节数为可读字符串
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${units[i]}';
  }
}

// 真正的重置实现：重置 LogoCacheManager 单例，使下次访问时按最新配置重建
void resetLogoCacheManager() {
  ServiceLocator.log.d('[LogoCacheService] 重置 LogoCacheManager 实例');
  LogoCacheManager.resetInstance();
}
