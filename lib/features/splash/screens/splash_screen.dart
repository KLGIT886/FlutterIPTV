import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/auto_refresh_service.dart';
import '../../../core/platform/tv_detection_channel.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../../player/providers/player_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  bool _initFailed = false; // 初始化失败标记（失败时显示重试，不再静默跳首页）
  bool _isRetrying = false; // 重试中标记（禁用按钮，防重复点击）

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _textController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    await _initializeApp();
  }

  Future<void> _initializeApp() async {
    ServiceLocator.log.i('开始初始化应用服务', tag: 'SplashScreen');
    final startTime = DateTime.now();
    
    try {
      // Initialize core services
      ServiceLocator.log.d('初始化核心服务...', tag: 'SplashScreen');
      await ServiceLocator.init();
      ServiceLocator.log.d('初始化 TV 检测...', tag: 'SplashScreen');
      await TVDetectionChannel.initialize();

      // Load data
      if (mounted) {
        ServiceLocator.log.d('加载播放列表数据...', tag: 'SplashScreen');
        final playlistProvider = context.read<PlaylistProvider>();
        await playlistProvider.loadPlaylists();
        
        ServiceLocator.log.d('播放列表加载完成: ${playlistProvider.playlists.length} 个', tag: 'SplashScreen');
        
        // 播放列表加载完成后，通知自动刷新服务进行检查
        AutoRefreshService().checkOnStartup();
        
        // 预热播放器 - Windows 桌面端提前初始化播放器,避免首次进入播放页面卡顿
        if (PlatformDetector.isDesktop) {
          ServiceLocator.log.d('预热播放器...', tag: 'SplashScreen');
          final playerProvider = context.read<PlayerProvider>();
          // 异步预热,不阻塞启动流程
          playerProvider.warmup().catchError((e) {
            ServiceLocator.log.d('播放器预热失败 (不影响使用): $e', tag: 'SplashScreen');
          });
        }
      }
      
      final initTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('应用初始化完成，耗时: ${initTime}ms', tag: 'SplashScreen');
    } catch (e) {
      ServiceLocator.log.e('应用初始化失败', tag: 'SplashScreen', error: e);
      // 标记失败，停留在 splash 显示重试 UI；不再静默 push 首页把错误延后到别处崩溃
      if (mounted) setState(() => _initFailed = true);
    }

    // Ensure minimum splash display time
    await Future.delayed(const Duration(milliseconds: 1500));

    // 仅初始化成功才进入首页；失败则留在当前页，由 build 展示重试/继续按钮
    if (mounted && !_initFailed) {
      _goHome();
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacementNamed(AppRouter.home);
  }

  /// 重试初始化
  Future<void> _retryInit() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _initFailed = false;
    });
    await _initializeApp();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.getPrimaryColor(context);
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: AppTheme.getGradient(context),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Animated App Name
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.getGradient(context).createShader(bounds),
                        child: Text(
                          AppStrings.of(context)?.lotusIptv ?? 'Lotus IPTV',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.of(context)?.professionalIptvPlayer ?? 'Professional IPTV Player',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.getTextSecondary(context).withOpacity(0.8),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: AppTheme.getSurfaceColor(context),
                          color: primaryColor,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)?.loading ?? 'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 初始化失败面板：提供重试与"仍然继续"两个兜底入口
              if (_initFailed) ...[
                const SizedBox(height: 24),
                Text(
                  AppStrings.of(context)?.initFailed ?? '初始化失败',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isRetrying ? null : _retryInit,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_isRetrying
                      ? (AppStrings.of(context)?.retrying ?? '重试中...')
                      : (AppStrings.of(context)?.retry ?? '重试')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _goHome,
                  child: Text(AppStrings.of(context)?.continueAnyway ?? '仍然继续'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
