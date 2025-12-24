import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// A simple local HTTP server for receiving playlist data from mobile devices
class LocalServerService {
  HttpServer? _server;
  String? _localIp;
  final int _port = 8899;

  // Callbacks
  Function(String url, String name)? onUrlReceived;
  Function(String content, String name)? onContentReceived;

  bool get isRunning => _server != null;
  String get serverUrl => 'http://$_localIp:$_port';
  String? get localIp => _localIp;
  int get port => _port;

  /// Start the local HTTP server
  Future<bool> start() async {
    try {
      // Get local IP address
      _localIp = await _getLocalIpAddress();
      if (_localIp == null) {
        debugPrint('LocalServer: 无法获取本地IP地址');
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
    } catch (e) {
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
      if (request.uri.path == '/' && request.method == 'GET') {
        // Serve the web page
        await _serveWebPage(request);
      } else if (request.uri.path == '/submit' && request.method == 'POST') {
        // Handle playlist submission
        await _handleSubmission(request);
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error: $e');
      await request.response.close();
    }
  }

  /// Serve the web page for mobile input
  Future<void> _serveWebPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_getWebPageHtml());
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

  /// Generate the HTML page for mobile input
  String _getWebPageHtml() {
    return r'''
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>导入播放列表 - Lotus IPTV</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            margin-bottom: 10px;
            font-size: 24px;
            background: linear-gradient(90deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle {
            text-align: center;
            color: #888;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .card {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.1);
        }
        .card h2 {
            font-size: 16px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .card h2::before {
            content: '';
            display: inline-block;
            width: 4px;
            height: 20px;
            background: linear-gradient(180deg, #667eea, #764ba2);
            border-radius: 2px;
        }
        input, textarea {
            width: 100%;
            padding: 14px 16px;
            border: none;
            border-radius: 12px;
            background: rgba(255,255,255,0.08);
            color: #fff;
            font-size: 16px;
            margin-bottom: 12px;
            outline: none;
            transition: all 0.3s;
        }
        input:focus, textarea:focus {
            background: rgba(255,255,255,0.12);
            box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.5);
        }
        input::placeholder, textarea::placeholder {
            color: #666;
        }
        button {
            width: 100%;
            padding: 16px;
            border: none;
            border-radius: 12px;
            background: linear-gradient(90deg, #667eea, #764ba2);
            color: #fff;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
        }
        button:active {
            transform: translateY(0);
        }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }
        .file-input-wrapper {
            position: relative;
            margin-bottom: 12px;
        }
        .file-input-wrapper input[type="file"] {
            position: absolute;
            opacity: 0;
            width: 100%;
            height: 100%;
            cursor: pointer;
        }
        .file-label {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 40px 16px;
            border: 2px dashed rgba(255,255,255,0.2);
            border-radius: 12px;
            color: #888;
            transition: all 0.3s;
            text-align: center;
        }
        .file-label.has-file {
            border-color: #667eea;
            color: #667eea;
        }
        .message {
            padding: 12px 16px;
            border-radius: 8px;
            margin-top: 12px;
            text-align: center;
            font-size: 14px;
        }
        .message.success {
            background: rgba(34, 197, 94, 0.2);
            color: #22c55e;
        }
        .message.error {
            background: rgba(239, 68, 68, 0.2);
            color: #ef4444;
        }
        .divider {
            display: flex;
            align-items: center;
            margin: 20px 0;
            color: #666;
            font-size: 14px;
        }
        .divider::before, .divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: rgba(255,255,255,0.1);
        }
        .divider span {
            padding: 0 16px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 Lotus IPTV</h1>
        <p class="subtitle">导入播放列表到您的电视</p>
        
        <div class="card">
            <h2>从链接导入</h2>
            <input type="text" id="playlistName" placeholder="播放列表名称 (可选)">
            <input type="url" id="playlistUrl" placeholder="请输入 M3U/M3U8 链接">
            <button onclick="submitUrl()" id="urlBtn">导入链接</button>
            <div id="urlMessage"></div>
        </div>
        
        <div class="divider"><span>或者</span></div>
        
        <div class="card">
            <h2>从文件导入</h2>
            <input type="text" id="fileName" placeholder="播放列表名称 (可选)">
            <div class="file-input-wrapper">
                <input type="file" id="fileInput" accept=".m3u,.m3u8" onchange="handleFileSelect(event)">
                <div class="file-label" id="fileLabel">
                    📁 点击选择 M3U/M3U8 文件
                </div>
            </div>
            <button onclick="submitFile()" id="fileBtn" disabled>上传文件</button>
            <div id="fileMessage"></div>
        </div>
    </div>

    <script>
        let selectedFile = null;
        
        function handleFileSelect(event) {
            const file = event.target.files[0];
            if (file) {
                selectedFile = file;
                document.getElementById('fileLabel').textContent = '📄 ' + file.name;
                document.getElementById('fileLabel').classList.add('has-file');
                document.getElementById('fileBtn').disabled = false;
                if (!document.getElementById('fileName').value) {
                    document.getElementById('fileName').value = file.name.replace(/\\.m3u8?$/i, '');
                }
            }
        }
        
        async function submitUrl() {
            const url = document.getElementById('playlistUrl').value.trim();
            const name = document.getElementById('playlistName').value.trim() || 'Imported Playlist';
            const btn = document.getElementById('urlBtn');
            const msg = document.getElementById('urlMessage');
            
            if (!url) {
                showMessage(msg, '请输入链接', 'error');
                return;
            }
            
            btn.disabled = true;
            btn.textContent = '正在导入...';
            
            try {
                const response = await fetch('/submit', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({type: 'url', url: url, name: name})
                });
                
                const result = await response.json();
                
                if (result.success) {
                    showMessage(msg, '✓ 已发送到电视，请在电视上查看', 'success');
                    document.getElementById('playlistUrl').value = '';
                    document.getElementById('playlistName').value = '';
                } else {
                    showMessage(msg, '发送失败: ' + result.message, 'error');
                }
            } catch (e) {
                showMessage(msg, '网络错误，请确保设备在同一局域网', 'error');
            }
            
            btn.disabled = false;
            btn.textContent = '导入链接';
        }
        
        async function submitFile() {
            if (!selectedFile) return;
            
            const name = document.getElementById('fileName').value.trim() || selectedFile.name.replace(/\\.m3u8?$/i, '');
            const btn = document.getElementById('fileBtn');
            const msg = document.getElementById('fileMessage');
            
            btn.disabled = true;
            btn.textContent = '正在上传...';
            
            try {
                const content = await selectedFile.text();
                
                const response = await fetch('/submit', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({type: 'content', content: content, name: name})
                });
                
                const result = await response.json();
                
                if (result.success) {
                    showMessage(msg, '✓ 已发送到电视，请在电视上查看', 'success');
                    selectedFile = null;
                    document.getElementById('fileInput').value = '';
                    document.getElementById('fileLabel').textContent = '📁 点击选择 M3U/M3U8 文件';
                    document.getElementById('fileLabel').classList.remove('has-file');
                    document.getElementById('fileName').value = '';
                } else {
                    showMessage(msg, '发送失败: ' + result.message, 'error');
                }
            } catch (e) {
                showMessage(msg, '网络错误，请确保设备在同一局域网', 'error');
            }
            
            btn.disabled = false;
            btn.textContent = '上传文件';
        }
        
        function showMessage(el, text, type) {
            el.textContent = text;
            el.className = 'message ' + type;
            setTimeout(() => { el.textContent = ''; el.className = ''; }, 5000);
        }
    </script>
</body>
</html>
''';
  }
}
