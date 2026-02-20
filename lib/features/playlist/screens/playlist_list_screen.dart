import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// Playlist sources page (read-only list of saved playlists).
class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  final Map<String, FocusNode> _tvFocusNodes = <String, FocusNode>{};
  bool _pendingTvMenuFocusAfterDelete = false;

  FocusNode _getTvFocusNode(String key) {
    return _tvFocusNodes.putIfAbsent(key, () => FocusNode(debugLabel: key));
  }

  bool _requestNodeFocus(FocusNode? node) {
    if (!mounted || node == null) return false;
    if (!node.canRequestFocus || node.context == null) return false;
    FocusScope.of(context).requestFocus(node);
    return true;
  }

  void _clearPrimaryFocus() {
    FocusManager.instance.primaryFocus
        ?.unfocus(disposition: UnfocusDisposition.scope);
  }

  void _cleanupTvFocusNodes(List<dynamic> playlists) {
    final validIds = playlists
        .map((p) => (p.id).toString())
        .toSet();
    final keysToRemove = <String>[];
    for (final key in _tvFocusNodes.keys) {
      final underscoreIndex = key.lastIndexOf('_');
      if (underscoreIndex <= 0 || underscoreIndex >= key.length - 1) continue;
      final idPart = key.substring(underscoreIndex + 1);
      if (!validIds.contains(idPart)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _tvFocusNodes.remove(key)?.dispose();
    }
  }

  void _requestTvFocusWithRetry(
    String key, {
    int retries = 8,
    VoidCallback? onFailure,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _getTvFocusNode(key);
      if (_requestNodeFocus(node)) {
        return;
      }
      if (retries > 0) {
        Future.delayed(
          const Duration(milliseconds: 40),
          () => _requestTvFocusWithRetry(
            key,
            retries: retries - 1,
            onFailure: onFailure,
          ),
        );
      } else {
        onFailure?.call();
      }
    });
  }

  bool _requestTvMenuFocus({int preferredIndex = 2}) {
    final menuNodes = TVSidebar.menuFocusNodes;
    if (menuNodes == null || menuNodes.isEmpty) return false;

    final candidates = {
      preferredIndex,
      0,
      for (int i = 0; i < menuNodes.length; i++) i,
    };

    for (final index in candidates) {
      if (index < 0 || index >= menuNodes.length) continue;
      if (_requestNodeFocus(menuNodes[index])) return true;
    }
    return false;
  }

  void _requestTvMenuFocusWithRetry({
    int preferredIndex = 2,
    int retries = 8,
    VoidCallback? onFailure,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_requestTvMenuFocus(preferredIndex: preferredIndex)) {
        return;
      }
      if (retries > 0) {
        Future.delayed(
          const Duration(milliseconds: 40),
          () => _requestTvMenuFocusWithRetry(
            preferredIndex: preferredIndex,
            retries: retries - 1,
            onFailure: onFailure,
          ),
        );
      } else {
        onFailure?.call();
      }
    });
  }

  void _requestTvFallbackFocus(PlaylistProvider provider) {
    final sortedPlaylists = List.from(provider.playlists)
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    for (final playlist in sortedPlaylists) {
      if (playlist.id == null) continue;
      final key = 'card_${playlist.id}';
      final node = _tvFocusNodes[key];
      if (_requestNodeFocus(node)) {
        return;
      }
    }

    if (sortedPlaylists.isNotEmpty && sortedPlaylists.first.id != null) {
      _requestTvFocusWithRetry(
        'card_${sortedPlaylists.first.id}',
        onFailure: () => _requestTvMenuFocusWithRetry(preferredIndex: 2),
      );
      return;
    }

    _requestTvMenuFocusWithRetry(preferredIndex: 2);
  }

  void _ensureTvFocusAlive(PlaylistProvider provider) {
    if (!PlatformDetector.isTV) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_pendingTvMenuFocusAfterDelete) {
        if (_requestTvMenuFocus(preferredIndex: 2)) {
          _pendingTvMenuFocusAfterDelete = false;
          return;
        }
        _requestTvMenuFocusWithRetry(
          preferredIndex: 2,
          onFailure: () {
            if (!mounted) return;
            _pendingTvMenuFocusAfterDelete = false;
            _requestTvFallbackFocus(provider);
          },
        );
        return;
      }

      final current = FocusManager.instance.primaryFocus;
      if (current != null && current.context != null && current.hasFocus) {
        return;
      }
      _requestTvFallbackFocus(provider);
    });
  }

  @override
  void dispose() {
    for (final node in _tvFocusNodes.values) {
      node.dispose();
    }
    _tvFocusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = _buildContent(context);

    if (isTV) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getPrimaryColor(context).withOpacity(0.15),
                      AppTheme.getBackgroundColor(context),
                    ]
                  : [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getBackgroundColor(context).withOpacity(0.9),
                      AppTheme.getPrimaryColor(context).withOpacity(0.08),
                    ],
            ),
          ),
          child: TVSidebar(
            selectedIndex: 2, // Playlist sources page
            onRight: () {
              final provider = context.read<PlaylistProvider>();
              final sortedPlaylists = List.from(provider.playlists)
                ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
              if (sortedPlaylists.isNotEmpty && sortedPlaylists.first.id != null) {
                _requestTvFocusWithRetry(
                  'card_${sortedPlaylists.first.id}',
                  onFailure: () => _requestTvFallbackFocus(provider),
                );
              }
            },
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // Add top safe-area spacing on mobile.
            if (PlatformDetector.isMobile)
              SizedBox(height: MediaQuery.of(context).padding.top),
            AppBar(
              backgroundColor: Colors.transparent,
              primary: false, // Disable automatic SafeArea padding.
              toolbarHeight: PlatformDetector.isMobile &&
                      MediaQuery.of(context).size.width > 600
                  ? 24.0
                  : 56.0, // Keep compact height in landscape mode.
              automaticallyImplyLeading: false, // Hide the default back button.
              title: Text(
                AppStrings.of(context)?.playlistList ?? 'Playlist List',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: PlatformDetector.isMobile &&
                          MediaQuery.of(context).size.width > 600
                      ? 14
                      : 20, // Use smaller title font in landscape mode.
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  '${(provider.importProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.of(context)?.processing ??
                      'Processing, please wait...',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.playlists.isEmpty) {
          _pendingTvMenuFocusAfterDelete = false;
          if (PlatformDetector.isTV) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _requestTvMenuFocusWithRetry(preferredIndex: 2);
            });
          }
          return _buildEmptyState();
        }

        return _buildPlaylistsList(provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noPlaylists ?? 'No Playlists',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.goToHomeToAdd ??
                'Go to Home to add playlists',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistProvider provider) {
    // Sort by ID descending (newest first).
    final sortedPlaylists = List.from(provider.playlists)
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    _cleanupTvFocusNodes(sortedPlaylists);
    _ensureTvFocusAlive(provider);

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = sortedPlaylists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlaylistCard(provider, playlist, index),
        );
      },
    );
  }

  Widget _buildPlaylistCard(
      PlaylistProvider provider, dynamic playlist, int index) {
    final isActive = provider.activePlaylist?.id == playlist.id;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    final isTv = PlatformDetector.isTV;
    final playlistKey = (playlist.id ?? index).toString();
    final cardFocusNode = isTv ? _getTvFocusNode('card_$playlistKey') : null;
    final copyFocusNode = isTv ? _getTvFocusNode('copy_$playlistKey') : null;
    final refreshFocusNode =
        isTv ? _getTvFocusNode('refresh_$playlistKey') : null;
    final deleteFocusNode =
        isTv ? _getTvFocusNode('delete_$playlistKey') : null;

    return TVFocusable(
      focusNode: cardFocusNode,
      autofocus: index == 0,
      onSelect: () {
        provider.setActivePlaylist(
          playlist,
          onPlaylistChanged: (playlistId) {
            context.read<ChannelProvider>().loadChannels(playlistId);
          },
          favoritesProvider: context.read<FavoritesProvider>(),
        );
      },
      // TV only: move focus from card to first action on RIGHT key.
      onRight: isTv
          ? () {
              if (playlist.isRemote && playlist.url != null) {
                copyFocusNode?.requestFocus();
              } else {
                refreshFocusNode?.requestFocus();
              }
            }
          : null,
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      AppTheme.getPrimaryColor(context).withOpacity(0.1),
                    ],
                  )
                : null,
            color: isActive ? null : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : isActive
                      ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(isLandscape ? 6 : 10),
        child: Row(
          children: [
            // Icon
            Container(
              width: isLandscape ? 36 : 48,
              height: isLandscape ? 36 : 48,
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
              ),
              child: Icon(
                playlist.isRemote
                    ? Icons.cloud_outlined
                    : Icons.folder_outlined,
                color: AppTheme.getPrimaryColor(context),
                size: isLandscape ? 18 : 24,
              ),
            ),

            SizedBox(width: isLandscape ? 10 : 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: isLandscape ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 4 : 6,
                            vertical: isLandscape ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getPrimaryColor(context),
                            borderRadius:
                                BorderRadius.circular(isLandscape ? 4 : 6),
                          ),
                          child: Text(
                            AppStrings.of(context)?.active ?? 'ACTIVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.format} | ${playlist.isRemote ? 'URL' : (AppStrings.of(context)?.localFile ?? 'Local File')} | ${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'}',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                  if (playlist.lastUpdated != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${AppStrings.of(context)?.updated ?? 'Updated'}: ${_formatDate(playlist.lastUpdated!)}',
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions (always visible; TV can focus via RIGHT key)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playlist.isRemote && playlist.url != null) ...[
                  TVFocusable(
                    focusNode: copyFocusNode,
                    onLeft: isTv ? () => cardFocusNode?.requestFocus() : null,
                    onRight: isTv ? () => refreshFocusNode?.requestFocus() : null,
                    onSelect: () => _copyUrl(playlist.url!),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        color: AppTheme.getTextSecondary(context),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                TVFocusable(
                  focusNode: refreshFocusNode,
                  onLeft: isTv
                      ? () {
                          if (playlist.isRemote && playlist.url != null) {
                            copyFocusNode?.requestFocus();
                          } else {
                            cardFocusNode?.requestFocus();
                          }
                        }
                      : null,
                  onRight: isTv ? () => deleteFocusNode?.requestFocus() : null,
                  onSelect: () => _refreshPlaylist(provider, playlist),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.getPrimaryColor(context),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TVFocusable(
                  focusNode: deleteFocusNode,
                  onLeft: isTv ? () => refreshFocusNode?.requestFocus() : null,
                  onRight: isTv ? () {} : null,
                  onSelect: () => _confirmDelete(provider, playlist),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${AppStrings.of(context)?.minutesAgo ?? 'm ago'}';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}${AppStrings.of(context)?.hoursAgo ?? 'h ago'}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}${AppStrings.of(context)?.daysAgo ?? 'd ago'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _refreshPlaylist(
      PlaylistProvider provider, dynamic playlist) async {
    if (!mounted) return;

    // Use unified refresh method with callback
    await provider.refreshPlaylistWithCallback(
      playlist: playlist,
      context: context,
      silent: false,
      onComplete: (success, error) async {
        if (!mounted) return;

        if (success) {
          // Reload channels if this is the active playlist
          final channelProvider = context.read<ChannelProvider>();
          if (provider.activePlaylist?.id == playlist.id) {
            await channelProvider.loadChannels(playlist.id);
          }

          // Reload EPG if enabled
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();

          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;

            // Background loading - don't block UI, don't await
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl, silent: true);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(fallbackEpgUrl, silent: true);
            }
          }
        }
      },
    );
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.urlCopied ?? 'URL copied to clipboard'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _confirmDelete(PlaylistProvider provider, dynamic playlist) {
    final pageContext = context;
    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(dialogContext)?.deletePlaylist ?? 'Delete Playlist',
            style: TextStyle(color: AppTheme.getTextPrimary(dialogContext)),
          ),
          content: Text(
            (AppStrings.of(dialogContext)?.deleteConfirmation ??
                    'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.')
                .replaceAll('{name}', playlist.name),
            style: TextStyle(color: AppTheme.getTextSecondary(dialogContext)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.of(dialogContext)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              autofocus: true,
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await provider.deletePlaylist(playlist.id);

                if (mounted && success) {
                  final channelProvider = pageContext.read<ChannelProvider>();

                  if (provider.activePlaylist != null &&
                      provider.activePlaylist!.id != null) {
                    await channelProvider
                        .loadChannels(provider.activePlaylist!.id!);
                  } else {
                    await channelProvider.loadAllChannels();
                  }

                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(pageContext)?.playlistDeleted ??
                          'Playlist deleted'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );

                  // TV: hard refresh current page to fully rebuild focus tree.
                  if (PlatformDetector.isTV) {
                    _pendingTvMenuFocusAfterDelete = false;
                    _clearPrimaryFocus();
                    if (!mounted) return;
                    Navigator.of(pageContext)
                        .pushReplacementNamed(AppRouter.playlistList);
                    return;
                  } else {
                    _pendingTvMenuFocusAfterDelete = false;
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}

