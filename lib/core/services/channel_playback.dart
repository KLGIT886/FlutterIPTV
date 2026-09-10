import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../navigation/app_router.dart';
import '../platform/platform_detector.dart';
import '../platform/native_player_channel.dart';
import 'service_locator.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/channels/providers/channel_provider.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/multi_screen/providers/multi_screen_provider.dart';
import '../../features/player/providers/player_provider.dart';

/// 从频道列表（首页 / 频道页 / 搜索 / 收藏）中点击一个频道后的统一播放编排。
///
/// 此前该逻辑在 4 个调用点被逐行复制（home / channels_grid_item / search / favorites），
/// 且各自存在细微差异。此处收敛为一处，通过命名参数显式保留各调用点的既有行为，
/// 避免"看似相同"的重构悄悄改变语义。
///
/// 分支：
/// - 多屏开启 + TV(Android)：拉起原生分屏播放器（复用全量频道列表）
/// - 多屏开启 + 桌面：在默认位置起播并进入播放页（不传频道参数）
/// - 多屏开启 + 其他平台：按 [playMobileMultiScreen] 决定是否先起播，再进入播放页
/// - 未开启多屏：直接进入播放页并传频道参数
Future<void> playChannelFromList(
  BuildContext context,
  Channel channel, {
  String? logTag,
  /// true 使用 saveLastSingleChannel（首页），false 使用 setLastChannelId（其余）。
  bool rememberAsSingle = false,
  /// 是否在拉起原生分屏前注册 providers（供原生侧收藏功能使用）。
  bool registerNativeProviders = false,
  /// 原生分屏（TV）时是否补记观看历史。
  bool recordWatchHistory = false,
  /// 多屏 + 手机平台时是否先调用 PlayerProvider.playChannel（首页行为）。
  bool playMobileMultiScreen = false,
  /// 原生分屏关闭后的回调（如刷新观看历史）。
  VoidCallback? onMultiScreenClosed,
}) async {
  final settingsProvider = context.read<SettingsProvider>();

  if (logTag != null) {
    ServiceLocator.log
        .i('播放频道: ${channel.name} (ID: ${channel.id})', tag: logTag);
  }

  // 保存上次播放的频道ID
  if (settingsProvider.rememberLastChannel && channel.id != null) {
    if (rememberAsSingle) {
      settingsProvider.saveLastSingleChannel(channel.id);
    } else {
      settingsProvider.setLastChannelId(channel.id);
    }
  }

  if (registerNativeProviders) {
    NativePlayerChannel.setProviders(
      context.read<FavoritesProvider>(),
      context.read<ChannelProvider>(),
      settingsProvider,
    );
  }

  if (settingsProvider.enableMultiScreen) {
    // TV 端使用原生分屏播放器
    if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
      final channelProvider = context.read<ChannelProvider>();
      // ✅ 使用全部频道而不是分页显示的频道
      final channels = channelProvider.allChannels;

      // 找到当前点击频道的索引
      final clickedIndex = channels.indexWhere((c) => c.url == channel.url);

      // TV端原生分屏播放器也需要记录观看历史
      if (recordWatchHistory && channel.id != null) {
        await ServiceLocator.watchHistory
            .addWatchHistory(channel.id!, channel.playlistId);
      }

      // 准备频道数据
      final urls = channels.map((c) => c.url).toList();
      final names = channels.map((c) => c.name).toList();
      final groups = channels.map((c) => c.groupName ?? '').toList();
      final sources = channels.map((c) => c.sources).toList();
      final logos = channels.map((c) => c.logoUrl ?? '').toList();

      // 启动原生分屏播放器
      await NativePlayerChannel.launchMultiScreen(
        urls: urls,
        names: names,
        groups: groups,
        sources: sources,
        logos: logos,
        initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
        volumeBoostDb: settingsProvider.volumeBoost,
        defaultScreenPosition: settingsProvider.defaultScreenPosition,
        showChannelName: settingsProvider.showMultiScreenChannelName,
        userAgent: settingsProvider.userAgent,
        onClosed: onMultiScreenClosed,
      );
    } else if (PlatformDetector.isDesktop) {
      // 桌面端分屏模式：在指定位置播放频道
      final multiScreenProvider = context.read<MultiScreenProvider>();
      multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
      multiScreenProvider.playChannelAtDefaultPosition(
          channel, settingsProvider.defaultScreenPosition);

      // 分屏模式下导航到播放器页面，但不传递频道参数（由 MultiScreenProvider 处理播放）
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': '', // 空URL表示分屏模式
        'channelName': '',
        'channelLogo': null,
      });
    } else {
      // 其他平台普通播放
      if (playMobileMultiScreen) {
        context.read<PlayerProvider>().playChannel(channel);
      }
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
  } else {
    // 普通模式：直接导航到播放器页面（避免重复记录观看历史，PlayerScreen 会记录）
    Navigator.pushNamed(context, AppRouter.player, arguments: {
      'channelUrl': channel.url,
      'channelName': channel.name,
      'channelLogo': channel.logoUrl,
    });
  }
}
