import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
