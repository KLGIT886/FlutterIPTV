import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../channels/providers/channel_provider.dart';
import '../providers/playlist_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

/// Dialog for scanning QR code to import playlist on TV
class QrImportDialog extends StatefulWidget {
  const QrImportDialog({super.key});

  @override
  State<QrImportDialog> createState() => _QrImportDialogState();
}

class _QrImportDialogState extends State<QrImportDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;
  String? _receivedMessage;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _serverService.stop();
    super.dispose();
  }

  Future<void> _startServer() async {
    debugPrint('DEBUG: 开始启动本地服务器...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Set up callbacks
    _serverService.onUrlReceived = _handleUrlReceived;
    _serverService.onContentReceived = _handleContentReceived;

    final success = await _serverService.start();
    debugPrint('DEBUG: 服务器启动结果: ${success ? "成功" : "失败"}');
    if (success) {
      debugPrint('DEBUG: 服务器URL: ${_serverService.serverUrl}');
    }

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        _error = '无法启动本地服务器，请检查网络连接';
      }
    });
  }

  void _handleUrlReceived(String url, String name) async {
    if (_isImporting) return;

    debugPrint('DEBUG: 收到URL导入请求 - 名称: $name, URL: $url');

    setState(() {
      _isImporting = true;
      _receivedMessage = '正在导入: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      debugPrint('DEBUG: 开始通过URL添加播放列表...');
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        debugPrint('DEBUG: 播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist,
            favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          debugPrint('DEBUG: 加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        setState(() {
          _receivedMessage = '✓ 导入成功: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        debugPrint('DEBUG: 播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ 导入失败';
          _isImporting = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: URL导入过程中发生错误: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ 导入失败: $e';
        _isImporting = false;
      });
    }
  }

  void _handleContentReceived(String content, String name) async {
    if (_isImporting) return;

    debugPrint('DEBUG: 收到内容导入请求 - 名称: $name, 内容长度: ${content.length}');

    setState(() {
      _isImporting = true;
      _receivedMessage = '正在导入: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      debugPrint('DEBUG: 开始通过内容添加播放列表...');
      final playlist = await provider.addPlaylistFromContent(name, content);

      if (playlist != null && mounted) {
        debugPrint('DEBUG: 播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist,
            favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          debugPrint('DEBUG: 加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        setState(() {
          _receivedMessage = '✓ 导入成功: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        debugPrint('DEBUG: 播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ 导入失败';
          _isImporting = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: 内容导入过程中发生错误: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ 导入失败: $e';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '扫码导入播放列表',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '使用手机扫描二维码',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            if (_isLoading)
              _buildLoadingState()
            else if (_error != null)
              _buildErrorState()
            else if (_isServerRunning)
              _buildQrCodeState(),

            const SizedBox(height: 24),

            // Close button
            TVFocusable(
              autofocus: true,
              onSelect: () => Navigator.of(context).pop(false),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.cardColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('关闭'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '正在启动服务...',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.errorColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TVFocusable(
          onSelect: _startServer,
          child: ElevatedButton(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState() {
    return Column(
      children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: _serverService.serverUrl,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),

        const SizedBox(height: 16),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStep('1', '使用手机扫描上方二维码'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStep('2', '在网页中输入链接或上传文件'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStep('3', '点击导入，电视将自动接收'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Server URL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_rounded,
                color: AppTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _serverService.serverUrl,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // Status message
        if (_receivedMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _receivedMessage!.contains('✓')
                  ? Colors.green.withOpacity(0.2)
                  : _receivedMessage!.contains('✗')
                      ? Colors.red.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isImporting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                if (_isImporting) const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _receivedMessage!,
                    style: TextStyle(
                      color: _receivedMessage!.contains('✓')
                          ? Colors.green
                          : _receivedMessage!.contains('✗')
                              ? Colors.red
                              : AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
