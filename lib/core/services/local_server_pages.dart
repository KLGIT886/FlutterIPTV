/// 局域网配置服务器的内联 HTML 页面（纯字符串，从 local_server_service.dart 抽出）。
library;

import 'dart:convert';

  /// Generate the HTML page for mobile input (fallback)
  String getImportPageHtml() {
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
  String getSearchPageHtml() {
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

  /// Generate the logs viewing HTML page
  String getLogsPageHtml(String logContent) {
    final escapedContent = const HtmlEscape().convert(logContent);
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - 日志查看</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .header p {
            color: #888;
            font-size: 14px;
        }
        .actions {
            display: flex;
            gap: 10px;
            justify-content: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        .btn-secondary {
            background: rgba(255, 255, 255, 0.1);
            color: white;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.15);
        }
        .btn-danger {
            background: rgba(244, 67, 54, 0.25);
            color: white;
            border: 1px solid rgba(244, 67, 54, 0.5);
        }
        .btn-danger:hover {
            background: rgba(244, 67, 54, 0.4);
        }
        .log-container {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 12px;
            padding: 20px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }
        .log-content {
            background: #1a1a2e;
            border-radius: 8px;
            padding: 16px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 13px;
            line-height: 1.6;
            color: #e0e0e0;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 600px;
            overflow-y: auto;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        .log-content::-webkit-scrollbar {
            width: 8px;
        }
        .log-content::-webkit-scrollbar-track {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 4px;
        }
        .log-content::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.2);
            border-radius: 4px;
        }
        .log-content::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        .toast {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #4caf50;
            color: white;
            padding: 16px 24px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            display: none;
            animation: slideIn 0.3s ease;
        }
        @keyframes slideIn {
            from {
                transform: translateX(400px);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
        .toast.show {
            display: block;
        }
        @media (max-width: 768px) {
            .header h1 {
                font-size: 24px;
            }
            .actions {
                flex-direction: column;
            }
            .btn {
                width: 100%;
                justify-content: center;
            }
            .log-content {
                font-size: 12px;
                max-height: 400px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📋 Lotus IPTV 日志查看</h1>
            <p>查看和分享应用日志</p>
        </div>
        
        <div class="actions">
            <button class="btn btn-primary" onclick="copyLogs()">
                📋 复制日志
            </button>
            <button class="btn btn-secondary" onclick="downloadLogs()">
                💾 下载日志
            </button>
            <button class="btn btn-danger" onclick="clearLogs()">
                🗑 清空日志
            </button>
        </div>
        
        <div class="log-container">
            <div class="log-content" id="logContent">$escapedContent</div>
        </div>
    </div>
    
    <div class="toast" id="toast">已复制到剪贴板！</div>
    
    <script>
        function showToast(message) {
            const toast = document.getElementById('toast');
            toast.textContent = message;
            toast.classList.add('show');
            setTimeout(() => {
                toast.classList.remove('show');
            }, 3000);
        }
        
        function copyLogs() {
            const logContent = document.getElementById('logContent').textContent;
            
            // 尝试使用现代 Clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(logContent).then(() => {
                    showToast('✓ 已复制到剪贴板！');
                }).catch(err => {
                    console.error('Clipboard API 失败:', err);
                    // 如果失败，尝试备用方案
                    fallbackCopy(logContent);
                });
            } else {
                // 浏览器不支持 Clipboard API，使用备用方案
                fallbackCopy(logContent);
            }
        }
        
        function fallbackCopy(text) {
            // 创建临时 textarea 元素
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.top = '0';
            textarea.style.left = '0';
            textarea.style.width = '2em';
            textarea.style.height = '2em';
            textarea.style.padding = '0';
            textarea.style.border = 'none';
            textarea.style.outline = 'none';
            textarea.style.boxShadow = 'none';
            textarea.style.background = 'transparent';
            document.body.appendChild(textarea);
            
            // 选择文本
            textarea.focus();
            textarea.select();
            
            try {
                // 执行复制命令
                const successful = document.execCommand('copy');
                if (successful) {
                    showToast('✓ 已复制到剪贴板！');
                } else {
                    showToast('✗ 复制失败，请手动复制');
                }
            } catch (err) {
                console.error('execCommand 失败:', err);
                showToast('✗ 复制失败，请手动复制');
            }
            
            // 移除临时元素
            document.body.removeChild(textarea);
        }
        
        function downloadLogs() {
            const logContent = document.getElementById('logContent').textContent;
            const blob = new Blob([logContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'lotus_iptv_logs_' + new Date().toISOString().replace(/[:.]/g, '-') + '.txt';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            showToast('✓ 日志已下载！');
        }

        function clearLogs() {
            if (!confirm('确定要清空所有日志吗？此操作不可恢复。')) return;
            fetch('/api/logs/clear', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('logContent').textContent = '';
                        showToast('✓ 日志已清空！');
                    } else {
                        showToast('✗ 清空失败：' + (data.error || '未知错误'));
                    }
                })
                .catch(err => {
                    console.error('清空日志失败:', err);
                    showToast('✗ 清空失败，请重试');
                });
        }
    </script>
</body>
</html>
''';
  }

  /// Generate the WebDAV config HTML page (fallback)
  String getWebDAVConfigPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - WebDAV Configuration</title>
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
    <h1>🔧 Lotus IPTV</h1>
    <p>WebDAV Configuration</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }

  /// Generate the User-Agent input HTML page (fallback)
  String getUserAgentPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - User-Agent Input</title>
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
    <h1>🌐 Lotus IPTV</h1>
    <p>User-Agent Input</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }
