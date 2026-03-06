import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/splash/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/player/screens/player_screen.dart';
import '../../features/channels/screens/channels_screen.dart';
import '../../features/playlist/screens/playlist_manager_screen.dart';
import '../../features/playlist/screens/playlist_list_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/epg/screens/epg_screen.dart';
import '../../features/settings/providers/settings_provider.dart';

class AppRouter {
  // Route observer for tracking navigation
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String player = '/player';
  static const String channels = '/channels';
  static const String playlistManager = '/playlist-manager';
  static const String playlistList = '/playlist-list';
  static const String favorites = '/favorites';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String epg = '/epg';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);

      case home:
        return _buildRoute(const HomeScreen(), settings);

      case player:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          PlayerScreen(
            channelUrl: args?['channelUrl'] ?? '',
            channelName: args?['channelName'] ?? 'Unknown',
            channelLogo: args?['channelLogo'],
            isMultiScreen: args?['isMultiScreen'] ?? false,
          ),
          settings,
        );

      case channels:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ChannelsScreen(
            groupName: args?['groupName'],
          ),
          settings,
        );

      case playlistManager:
        return _buildRoute(const PlaylistManagerScreen(), settings);

      case playlistList:
        return _buildRoute(const PlaylistListScreen(), settings);

      case favorites:
        return _buildRoute(const FavoritesScreen(), settings);

      case search:
        return _buildRoute(const SearchScreen(), settings);

      case AppRouter.settings:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(SettingsScreen(autoCheckUpdate: args?['autoCheckUpdate'] ?? false), settings);

      case epg:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          EpgScreen(
            channelId: args?['channelId'],
          ),
          settings,
        );

      default:
        return _buildRoute(
          Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 获取当前的动画类型设置
        final animationType = context.read<SettingsProvider>().pageTransitionAnimation;
        
        switch (animationType) {
          case 'fade':
            // 淡入淡出
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          
          case 'slide':
            // 从右到左滑入 + 淡入
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          
          case 'scale':
            // 缩放 + 淡入
            const curve = Curves.easeInOutCubic;
            var scaleTween = Tween(begin: 0.8, end: 1.0).chain(
              CurveTween(curve: curve),
            );

            return ScaleTransition(
              scale: animation.drive(scaleTween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          
          case 'material':
            // Material（Android）风格：从下到上滑入 + 淡入
            const begin = Offset(0.0, 0.04);
            const end = Offset.zero;
            const curve = Curves.fastOutSlowIn;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              ),
            );
          
          case 'cupertino':
            // Cupertino（iOS）风格：从右到左滑入，带视差效果
            const curve = Curves.linearToEaseOut;
            
            // 新页面从右侧滑入
            var primaryTween = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve));
            
            // 旧页面向左侧移动（视差效果）
            var secondaryTween = Tween(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(primaryTween),
              child: SlideTransition(
                position: secondaryAnimation.drive(secondaryTween),
                child: child,
              ),
            );
          
          case 'none':
            // 无动画
            return child;
          
          default:
            // 默认淡入淡出
            return FadeTransition(
              opacity: animation,
              child: child,
            );
        }
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
