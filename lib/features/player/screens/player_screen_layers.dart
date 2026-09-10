part of 'player_screen.dart';

/// 视频层 / 分屏层 / EPG 面板 从 _PlayerScreenState 抽出的扩展。
extension _PlayerScreenLayers on _PlayerScreenState {
  Widget _buildEpgPanel() {
    if (!_showEpgPanel ||
        WindowsPipChannel.isInPipMode ||
        _isMultiScreenMode()) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: InteractiveEpgWidget(
        channel: _originalChannel ??
            (_playerProvider?.currentChannel ??
                Channel(playlistId: 0, name: 'Unknown', url: '')),
        isPlayingCatchup: _originalChannel != null,
        currentCatchupProgram: _currentCatchupProgram,
        onProgramSelected: (program) {
          _playCatchup(program);
          refreshPlayerUi(() => _showEpgPanel = false);
        },
        onBackToLive: () {
          _backToLive();
          refreshPlayerUi(() => _showEpgPanel = false);
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // 使用本地状态判断是否显示分屏模式
    if (_isMultiScreenMode()) {
      return _buildMultiScreenPlayer();
    }

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // 已熶竴使用敤 media_kit
        if (provider.videoController == null) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return ExcludeSemantics(
          // Exclude semantics from video texture widget to prevent AXTree update
          // errors when the platform video surface rebuilds.
          child: Video(
            controller: provider.videoController!,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }

  // 多屏播放器
  Widget _buildMultiScreenPlayer() {
    return MultiScreenPlayer(
      onExitMultiScreen: () {
        // 退出分屏模式，使用活动屏幕的频道全屏播放（不修改设置）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final activeChannel = multiScreenProvider.activeChannel;

        // 切回单屏前：释放多屏播放器，但保留每屏频道状态，方便再次进入
        multiScreenProvider.pauseAllScreens();

        // 切换到常规模式
        refreshPlayerUi(() {
          _localMultiScreenMode = false;
        });

        if (activeChannel != null) {
          // 使用主播放器播放活动频道
          unawaited(_resumeSingleFromMultiScreen(activeChannel));
        }
      },
      onBack: () async {
        // 先保存分屏状态，再清空
        _saveMultiScreenState();
        // 返回时清空所有分屏（等待完成）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        await multiScreenProvider.clearAllScreens();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  // 切换到分屏模式

}
