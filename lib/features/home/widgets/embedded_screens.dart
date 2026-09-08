import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../channels/providers/channel_provider.dart';
import '../../channels/screens/channels_screen.dart';
import '../../playlist/screens/playlist_list_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../search/screens/search_screen.dart';

/// 嵌入式频道页面（手机端底部导航用）
class EmbeddedChannelsScreen extends StatefulWidget {
  const EmbeddedChannelsScreen({super.key});

  @override
  State<EmbeddedChannelsScreen> createState() =>
      EmbeddedChannelsScreenState();
}

class EmbeddedChannelsScreenState extends State<EmbeddedChannelsScreen> {
  @override
  void initState() {
    super.initState();
    // 每次显示时清除分类筛选
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().clearGroupFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ChannelsScreen(embedded: true);
  }
}

/// 嵌入式收藏页面
class EmbeddedFavoritesScreen extends StatelessWidget {
  const EmbeddedFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FavoritesScreen(embedded: true);
  }
}

/// 嵌入式播放列表页面
class EmbeddedPlaylistListScreen extends StatelessWidget {
  const EmbeddedPlaylistListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaylistListScreen();
  }
}

/// 嵌入式搜索页面
class EmbeddedSearchScreen extends StatelessWidget {
  const EmbeddedSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchScreen(embedded: true);
  }
}

/// 嵌入式设置页面
class EmbeddedSettingsScreen extends StatelessWidget {
  const EmbeddedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(embedded: true);
  }
}