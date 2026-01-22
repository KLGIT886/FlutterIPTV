import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A simple local HTTP server for receiving playlist data and search queries from mobile devices
class LocalServerService {
  // 单例模式
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();
  
  HttpServer? _server;
  String? _localIp;
  final int _port = 38888;

  // Callbacks
  Function(String url, String name)? onUrlReceived;
  Function(String content, String name)? onContentReceived;
  Function(String query)? onSearchReceived;

  bool get isRunning => _server != null;
  String get serverUrl => 'http://$_localIp:$_port';
  String get importUrl => 'http://$_localIp:$_port/import';
  String get searchUrl => 'http://$_localIp:$_port/search';
  String? get localIp => _localIp;
  int get port => _port;

  String? _lastError;
  String? get lastError => _lastError;
  
  String? _cachedImportHtml;
  String? _cachedSearchHtml;

  /// Start the local HTTP server
  Future<bool> start() async {
    // 如果服务器已经在运行，直接返回成功
    if (_server != null) {
      debugPrint('LocalServer: 服务器已在运行');
      return true;
    }
    
    try {
      _lastError = null;
      
      // Load HTML templates if not cached
      if (_cachedImportHtml == null) {
        try {
          _cachedImportHtml = await rootBundle.loadString('assets/html/import_playlist.html');
          debugPrint('LocalServer: 导入HTML模板加载成功');
        } catch (e) {
          debugPrint('LocalServer: 导入HTML模板加载失败: $e');
          _lastError = '无法加载页面模板';
          return false;
        }
      }
      
      if (_cachedSearchHtml == null) {
        try {
          _cachedSearchHtml = await rootBundle.loadString('assets/html/search_channels.html');
          debugPrint('LocalServer: 搜索HTML模板加载成功');
        } catch (e) {
          debugPrint('LocalServer: 搜索HTML模板加载失败: $e');
        }
      }
      
      // Get local IP address
      _localIp = await _getLocalIpAddress();
      if (_localIp == null) {
        _lastError = '无法获取本地IP地址。请检查网络连接是否正常。';
        debugPrint('LocalServer: $_lastError');
        return false;
      }

      debugPrint('LocalServer: 本地IP地址: $_localIp');
      debugPrint('LocalServer: 尝试在端口 $_port 启动服务器...');

      // Start HTTP server - bind to all interfaces
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);

      debugPrint('LocalServer: 服务器已启动，监听地址: ${_server!.address.address}:${_server!.port}');
      debugPrint('LocalServer: 访问地址: http://$_localIp:$_port');

      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LocalServer: 请求处理错误: $e');
      });

      return true;
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048 || e.message.contains('address already in use')) {
        _lastError = '端口 $_port 已被占用。请关闭占用该端口的程序后重试。';
      } else if (e.osError?.errorCode == 10013) {
        _lastError = '权限不足。请以管理员身份运行应用。';
      } else {
        _lastError = '网络错误: ${e.message}';
      }
      debugPrint('LocalServer: 启动失败 (SocketException): $e');
      debugPrint('LocalServer: 错误代码: ${e.osError?.errorCode}');
      return false;
    } catch (e) {
      _lastError = '启动失败: $e';
      debugPrint('LocalServer: 启动失败: $e');
      return false;
    }
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Handle incoming HTTP requests
  void _handleRequest(HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      debugPrint('DEBUG: 收到请求 - 路径: ${request.uri.path}, 方法: ${request.method}');
      
      if (request.uri.path == '/' && request.method == 'GET') {
        // Serve the import page by default
        debugPrint('DEBUG: 提供导入页面 (/)');
        await _serveImportPage(request);
      } else if (request.uri.path == '/import' && request.method == 'GET') {
        // Serve the import page
        debugPrint('DEBUG: 提供导入页面 (/import)');
        await _serveImportPage(request);
      } else if (request.uri.path == '/search' && request.method == 'GET') {
        // Serve the search page
        debugPrint('DEBUG: 提供搜索页面 (/search)');
        await _serveSearchPage(request);
      } else if (request.uri.path == '/submit' && request.method == 'POST') {
        // Handle playlist submission
        debugPrint('DEBUG: 处理播放列表提交');
        await _handleSubmission(request);
      } else if (request.uri.path == '/api/search' && request.method == 'POST') {
        // Handle search submission
        debugPrint('DEBUG: 处理搜索提交');
        await _handleSearchSubmission(request);
      } else {
        debugPrint('DEBUG: 404 - 未找到路径: ${request.uri.path}');
        request.response.statusCode = 404;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('DEBUG: 请求处理错误: $e');
      request.response.statusCode = 500;
      request.response.write('Error: $e');
      await request.response.close();
    }
  }

  /// Serve the import web page
  Future<void> _serveImportPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_cachedImportHtml ?? _getImportPageHtml());
    await request.response.close();
  }

  /// Serve the search web page
  Future<void> _serveSearchPage(HttpRequest request) async {
    debugPrint('DEBUG: _serveSearchPage 被调用');
    debugPrint('DEBUG: _cachedSearchHtml 是否为空: ${_cachedSearchHtml == null}');
    request.response.headers.contentType = ContentType.html;
    final html = _cachedSearchHtml ?? _getSearchPageHtml();
    debugPrint('DEBUG: 发送搜索页面，长度: ${html.length}');
    request.response.write(html);
    await request.response.close();
  }

  /// Handle playlist submission from mobile
  Future<void> _handleSubmission(HttpRequest request) async {
    try {
      debugPrint('DEBUG: 收到来自 ${request.requestedUri} 的提交请求');

      final content = await utf8.decoder.bind(request).join();
      debugPrint('DEBUG: 请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;

      final type = data['type'] as String?;
      final name = data['name'] as String? ?? 'Imported Playlist';

      debugPrint('DEBUG: 请求类型: $type, 名称: $name');

      if (type == 'url') {
        final url = data['url'] as String?;
        debugPrint('DEBUG: URL内容: ${url?.substring(0, math.min(100, url.length))}...');

        if (url != null && url.isNotEmpty) {
          debugPrint('DEBUG: 调用URL接收回调...');
          onUrlReceived?.call(url, name);

          request.response.headers.contentType = ContentType.json;
          request.response.write(json.encode({'success': true, 'message': 'URL received'}));
        } else {
          debugPrint('DEBUG: URL为空或无效');
          request.response.statusCode = 400;
          request.response.write(json.encode({'success': false, 'message': 'URL is required'}));
        }
      } else if (type == 'content') {
        final fileContent = data['content'] as String?;
        debugPrint('DEBUG: 文件内容长度: ${fileContent?.length}');

        if (fileContent != null && fileContent.isNotEmpty) {
          debugPrint('DEBUG: 调用内容接收回调...');
          onContentReceived?.call(fileContent, name);

          request.response.headers.contentType = ContentType.json;
          request.response.write(json.encode({'success': true, 'message': 'Content received'}));
        } else {
          debugPrint('DEBUG: 文件内容为空');
          request.response.statusCode = 400;
          request.response.write(json.encode({'success': false, 'message': 'Content is required'}));
        }
      } else {
        debugPrint('DEBUG: 无效的请求类型: $type');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'Invalid type'}));
      }
    } catch (e) {
      debugPrint('DEBUG: 处理提交请求时出错: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    debugPrint('DEBUG: 请求处理完成');
  }

  /// Handle search submission from mobile
  Future<void> _handleSearchSubmission(HttpRequest request) async {
    try {
      debugPrint('DEBUG: 收到来自 ${request.requestedUri} 的搜索请求');

      final content = await utf8.decoder.bind(request).join();
      debugPrint('DEBUG: 请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;
      final query = data['query'] as String?;

      debugPrint('DEBUG: 搜索内容: $query');

      if (query != null && query.isNotEmpty) {
        debugPrint('DEBUG: 调用搜索接收回调...');
        onSearchReceived?.call(query);

        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'success': true, 'message': 'Search query received'}));
      } else {
        debugPrint('DEBUG: 搜索内容为空');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'Query is required'}));
      }
    } catch (e) {
      debugPrint('DEBUG: 处理搜索请求时出错: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    debugPrint('DEBUG: 搜索请求处理完成');
  }

  /// Get the local IP address
  /// Tries to find the most likely usable LAN IP using a scoring mechanism
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      NetworkInterface? bestInterface;
      int bestScore = -1000;

      for (var interface in interfaces) {
        int score = 0;
        final name = interface.name.toLowerCase();

        // Penalize virtual interfaces
        if (name.contains('vethernet') ||
            name.contains('virtual') ||
            name.contains('wsl') ||
            name.contains('docker') ||
            name.contains('bridge') ||
            name.contains('vmware') ||
            name.contains('box') ||
            name.contains('pseudo') ||
            name.contains('host-only') ||
            name.contains('tap') ||
            name.contains('tun')) {
          score -= 100;
        }

        // Bonus for known physical interface names
        if (name.contains('wi-fi') || name.contains('wlan')) {
          score += 50;
        }
        if (name.contains('ethernet') || name.contains('以太网') || name.contains('本地连接')) {
          score += 40;
        }

        // Find the first IPv4 address
        String? ip;
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }

        if (ip == null) {
          continue;
        }

        // Bonus for standard LAN ranges
        if (ip.startsWith('192.168.')) {
          score += 20;
        } else if (ip.startsWith('10.')) {
          score += 10;
        } else if (ip.startsWith('172.')) {
          // Check Class B private range 172.16.0.0 - 172.31.255.255
          try {
            final secondPart = int.parse(ip.split('.')[1]);
            if (secondPart >= 16 && secondPart <= 31) score += 15;
          } catch (_) {}
        }

        debugPrint('Interface: ${interface.name}, IP: $ip, Score: $score');

        if (score > bestScore) {
          bestScore = score;
          bestInterface = interface;
        }
      }

      if (bestInterface != null) {
        for (var addr in bestInterface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return null;
    }
  }

  /// Generate the HTML page for mobile input (fallback)
  String _getImportPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - Import Playlist</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🎬 Lotus IPTV</h1>
    <p>Import Playlist</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }

  /// Generate the search HTML page (fallback)
  String _getSearchPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - Search Channels</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🔍 Lotus IPTV</h1>
    <p>Search Channels</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }
}
