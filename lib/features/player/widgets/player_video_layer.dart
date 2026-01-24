import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';
import '../../multi_screen/widgets/multi_screen_player.dart';


class PlayerVideoLayer extends StatelessWidget {
  final bool isMultiScreenMode;
  final VoidCallback? onExitMultiScreen;
  final Future<void> Function()? onMultiScreenBack;

  const PlayerVideoLayer({
    super.key,
    required this.isMultiScreenMode,
    this.onExitMultiScreen,
    this.onMultiScreenBack,
  });

  @override
  Widget build(BuildContext context) {
    if (isMultiScreenMode) {
      return MultiScreenPlayer(
        onExitMultiScreen: onExitMultiScreen ?? () {},
        onBack: onMultiScreenBack ?? () async {},
      );
    }

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        if (provider.useExoPlayer) {
          final exoPlayer = provider.exoPlayer;
          if (exoPlayer == null) return const SizedBox.expand();

          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: exoPlayer,
            builder: (context, value, child) {
              if (!value.isInitialized) return const SizedBox.expand();

              return Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(exoPlayer),
                ),
              );
            },
          );
        }

        if (provider.videoController == null) return const SizedBox.expand();

        return Center(
          child: Video(
            controller: provider.videoController!,
            fill: Colors.black,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }
}
