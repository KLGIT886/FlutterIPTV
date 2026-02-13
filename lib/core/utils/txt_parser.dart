import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/service_locator.dart';

/// Parser for TXT playlist files (genre format)
/// Format:
/// Category,#genre#
/// Channel Name,URL
/// Channel Name,URL
class TXTParser {
  /// Parse TXT content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId, {String? mergeRule}) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从URL获取TXT播放列表内容: $url');

      final dio = Dio();
      // Increased timeout for large playlists
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 30);

      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      ServiceLocator.log.d('DEBUG: 成功获取TXT播放列表内容，状态码: ${response.statusCode}');
      final contentLength = response.data.toString().length;
      ServiceLocator.log.d('DEBUG: 内容大小: $contentLength 字符');

      // Only use isolate for large files (>500KB) to avoid overhead
      final useIsolate = contentLength > 500 * 1024;
      ServiceLocator.log.d('DEBUG: ${useIsolate ? "使用" : "不使用"} isolate 解析 (大小: ${(contentLength / 1024).toStringAsFixed(1)}KB)');

      final List<Channel> channels;
      if (useIsolate) {
        channels = await compute(
            _parseInIsolate, _ParseParams(response.data.toString(), playlistId, mergeRule));
      } else {
        // Parse directly in main thread for small files
        channels = parse(response.data.toString(), playlistId, mergeRule: mergeRule);
      }

      ServiceLocator.log.d('DEBUG: TXT URL解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 从URL获取TXT播放列表时出错: $e');

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        throw Exception('errorTimeout');
      } else if (errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('handshake') ||
          errorStr.contains('lookup')) {
        throw Exception('errorNetwork');
      } else if (errorStr.contains('404')) {
        throw Exception('Playlist not found (404)');
      } else if (errorStr.contains('403')) {
        throw Exception('Access denied (403)');
      }

      rethrow;
    }
  }

  /// Parse TXT content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId, {String? mergeRule}) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从本地文件读取TXT播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        ServiceLocator.log.d('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      final contentLength = content.length;
      ServiceLocator.log.d('DEBUG: 成功读取TXT本地文件，内容大小: $contentLength 字符');

      // Only use isolate for large files (>500KB)
      final useIsolate = contentLength > 500 * 1024;
      ServiceLocator.log.d('DEBUG: ${useIsolate ? "使用" : "不使用"} isolate 解析 (大小: ${(contentLength / 1024).toStringAsFixed(1)}KB)');

      final List<Channel> channels;
      if (useIsolate) {
        channels = await compute(_parseInIsolate, _ParseParams(content, playlistId, mergeRule));
      } else {
        // Parse directly in main thread for small files
        channels = parse(content, playlistId, mergeRule: mergeRule);
      }

      ServiceLocator.log.d('DEBUG: TXT本地文件解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 读取TXT本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse TXT content string
  /// Format: Category,#genre#
  ///         Channel Name,URL
  /// Merges channels with same name into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId, {String? mergeRule}) {
    // 注意：此方法可能在 isolate 中运行，不能使用 ServiceLocator.log
    print('TXT Parser: 开始解析，播放列表ID: $playlistId, 合并规则: ${mergeRule ?? "name_group"}');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();

    print('TXT Parser: 内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      print('TXT Parser: 内容为空，返回空频道列表');
      return rawChannels;
    }

    String currentGroup = 'Uncategorized';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      // Check if this is a category line (ends with ,#genre#)
      if (line.endsWith(',#genre#')) {
        currentGroup = line.substring(0, line.length - 8).trim();
        if (currentGroup.isEmpty) {
          currentGroup = 'Uncategorized';
        }
        continue;
      }

      // Parse channel line: Channel Name,URL
      final parts = line.split(',');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final url =
            parts.sublist(1).join(',').trim(); // Handle URLs with commas

        if (name.isNotEmpty && _isValidUrl(url)) {
          final channel = Channel(
            playlistId: playlistId,
            name: name,
            url: url,
            groupName: currentGroup,
          );

          rawChannels.add(channel);
        }
      }
    }

    print('TXT Parser: 原始解析完成，有效频道: ${rawChannels.length}');

    // Merge channels with same name into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels, mergeRule: mergeRule);

    print('TXT Parser: 合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');

    return mergedChannels;
  }

  /// Merge channels with same name AND group into single channel with multiple sources
  /// Preserves the order of first occurrence, but prefers non-special groups
  /// Optimized using Map for better performance
  static List<Channel> _mergeChannelSources(List<Channel> channels, {String? mergeRule}) {
    // Use Map to maintain insertion order while providing O(1) lookup
    final Map<String, Channel> mergedMap = {};

    // Special groups that should not be the primary group
    final specialGroups = {'🕘️更新时间', '更新时间', 'update', 'info'};

    // Default to 'name_group' if not specified
    final rule = mergeRule ?? 'name_group';

    for (final channel in channels) {
      // Choose merge key based on rule
      final String mergeKey;
      if (rule == 'name') {
        // Merge by name only (across all groups)
        mergeKey = channel.name;
      } else {
        // Merge by name + group (default: 'name_group')
        mergeKey = '${channel.name}_${channel.groupName ?? ""}';
      }

      if (mergedMap.containsKey(mergeKey)) {
        // Add source to existing channel
        final existing = mergedMap[mergeKey]!;
        final newSources = [...existing.sources];

        // Add URL if not duplicate
        if (!newSources.contains(channel.url)) {
          newSources.add(channel.url);
        }

        // Check if we should replace the primary channel info
        // (prefer non-special group over special group)
        final existingIsSpecial = specialGroups.any((g) =>
            existing.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);
        final newIsSpecial = specialGroups.any((g) =>
            channel.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);

        if (existingIsSpecial && !newIsSpecial) {
          // Replace with the new channel's info but keep all sources
          mergedMap[mergeKey] = channel.copyWith(
            sources: newSources,
            // Keep the first URL as primary
            url: newSources.first,
          );
        } else {
          // Just add the new source
          mergedMap[mergeKey] = existing.copyWith(sources: newSources);
        }
      } else {
        // New channel
        mergedMap[mergeKey] = channel.copyWith(sources: [channel.url]);
      }
    }

    // Return in original order (Map maintains insertion order in Dart)
    return mergedMap.values.toList();
  }

  /// Check if a string is a valid URL
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtmp' ||
              uri.scheme == 'rtsp' ||
              uri.scheme == 'mms' ||
              uri.scheme == 'mmsh' ||
              uri.scheme == 'mmst');

      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Generate TXT content from a list of channels
  static String generate(List<Channel> channels) {
    final buffer = StringBuffer();

    // Group channels by category
    final Map<String, List<Channel>> groupedChannels = {};
    for (final channel in channels) {
      final group = channel.groupName ?? 'Uncategorized';
      groupedChannels.putIfAbsent(group, () => []).add(channel);
    }

    // Write each group
    for (final entry in groupedChannels.entries) {
      buffer.writeln('${entry.key},#genre#');
      for (final channel in entry.value) {
        buffer.writeln('${channel.name},${channel.url}');
      }
    }

    return buffer.toString();
  }
}

/// 用于传递参数到 isolate 的类
class _ParseParams {
  final String content;
  final int playlistId;
  final String? mergeRule;

  _ParseParams(this.content, this.playlistId, this.mergeRule);
}

/// Isolate 中执行的解析函数（必须是顶层函数或静态函数）
List<Channel> _parseInIsolate(_ParseParams params) {
  return TXTParser.parse(params.content, params.playlistId, mergeRule: params.mergeRule);
}
