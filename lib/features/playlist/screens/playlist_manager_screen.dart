import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_iptv/features/playlist/widgets/qr_import_dialog.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

class PlaylistManagerScreen extends StatefulWidget {
  const PlaylistManagerScreen({super.key});

  @override
  State<PlaylistManagerScreen> createState() => _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends State<PlaylistManagerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode(debugLabel: 'playlist_name_field');
    _urlFocusNode = FocusNode(debugLabel: 'playlist_url_field');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppTheme.getBackgroundColor(context),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: provider.isLoading ? null : () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _buildContent(provider),
                  ),
                ),
              ),
            ),
            if (provider.isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primaryColor),
                        const SizedBox(height: 20),
                        Text(
                          '${(provider.importProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.of(context)?.processing ?? 'Processing, please wait...',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContent(PlaylistProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.getGradient(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.playlist_add_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.of(context)?.addNewPlaylist ?? 'Add New Playlist',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          PlatformDetector.isTV
              ? (AppStrings.of(context)?.addFirstPlaylistTV ?? 'Import via USB or scan QR code')
              : 'Import M3U/M3U8 playlist from URL or file',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: PlatformDetector.isTV ? _buildTVContent(provider) : _buildDesktopContent(provider),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(provider.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.errorColor,
                  onPressed: provider.clearError,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTVContent(PlaylistProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImportCard(
          onPressed: () => _pickFile(provider),
          icon: Icons.folder_open_rounded,
          title: AppStrings.of(context)?.fromFile ?? 'From File',
          subtitle: 'Import from USB or local storage',
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildImportCard(
          onPressed: () => _showQrImportDialog(context),
          icon: Icons.qr_code_scanner_rounded,
          title: AppStrings.of(context)?.scanToImport ?? 'Scan to Import',
          subtitle: 'Use your phone to scan QR code',
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildDesktopContent(PlaylistProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          hintText: AppStrings.of(context)?.playlistName ?? 'Playlist Name',
          prefixIcon: Icons.label_outline_rounded,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _urlController,
          focusNode: _urlFocusNode,
          hintText: AppStrings.of(context)?.playlistUrl ?? 'M3U/M3U8 URL',
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          onPressed: provider.isLoading ? null : () => _addPlaylist(provider),
          icon: provider.isLoading ? null : Icons.add_rounded,
          label: provider.isLoading
              ? (AppStrings.of(context)?.importing ?? 'Importing...')
              : (AppStrings.of(context)?.addFromUrl ?? 'Add from URL'),
          isLoading: provider.isLoading,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.getTextMuted(context).withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppStrings.of(context)?.or ?? 'or',
                style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.getTextMuted(context).withOpacity(0.3))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                onPressed: () => _pickFile(provider),
                icon: Icons.folder_open_rounded,
                label: AppStrings.of(context)?.fromFile ?? 'From File',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                onPressed: () => _showQrImportDialog(context),
                icon: Icons.qr_code_scanner_rounded,
                label: AppStrings.of(context)?.scanToImport ?? 'Scan QR',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    bool autofocus = false,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
              width: 2,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
              prefixIcon: Icon(prefixIcon, color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getTextMuted(context)),
              filled: true,
              fillColor: AppTheme.getCardColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    IconData? icon,
    required String label,
    bool isLoading = false,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.getPrimaryColor(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (icon != null || isLoading) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.getPrimaryColor(context),
          side: BorderSide(color: AppTheme.getPrimaryColor(context).withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard({
    required VoidCallback? onPressed,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimary,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      showFocusBorder: true,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isPrimary && isFocused ? AppTheme.getGradient(context) : null,
            color: isPrimary && !isFocused
                ? AppTheme.getPrimaryColor(context)
                : !isPrimary && isFocused
                    ? AppTheme.getCardColor(context)
                    : AppTheme.getCardColor(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: !isPrimary
                ? Border.all(
                    color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getPrimaryColor(context).withOpacity(0.3),
                    width: 2,
                  )
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white.withOpacity(0.2) : AppTheme.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : AppTheme.getPrimaryColor(context),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : AppTheme.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isPrimary ? Colors.white.withOpacity(0.8) : AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: isPrimary ? Colors.white : AppTheme.getTextMuted(context),
            size: 16,
          ),
        ],
      ),
    );
  }

  Future<void> _addPlaylist(PlaylistProvider provider) async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistName ?? 'Please enter a playlist name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistUrl ?? 'Please enter a playlist URL'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
        await context.read<ChannelProvider>().loadChannels(playlist.id!);

        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl, silent: true);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              await epgProvider.loadEpg(fallbackEpgUrl, silent: true);
            }
          }
        }

        _nameController.clear();
        _urlController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text((AppStrings.of(context)?.playlistAdded ?? 'Added "{name}"').replaceAll('{name}', playlist.name)),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showQrImportDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const QrImportDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.playlistImported ?? 'Playlist imported successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickFile(PlaylistProvider provider) async {
    try {
      if (PlatformDetector.isTV) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)?.selectM3uFile ?? 'Please select an M3U/M3U8 file'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;

        final filePath = result.files.single.path!;
        final fileName = result.files.single.name.replaceAll(RegExp(r'\.(m3u8?|txt)$'), '');

        try {
          final playlist = await provider.addPlaylistFromFile(fileName, filePath);

          if (mounted) {
            if (playlist != null) {
              provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
              await context.read<ChannelProvider>().loadChannels(playlist.id!);

              if (mounted) {
                final settingsProvider = context.read<SettingsProvider>();
                final epgProvider = context.read<EpgProvider>();
                
                if (settingsProvider.enableEpg) {
                  final playlistEpgUrl = provider.lastExtractedEpgUrl;
                  final fallbackEpgUrl = settingsProvider.epgUrl;
                  
                  if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
                    await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl, silent: true);
                  } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
                    await epgProvider.loadEpg(fallbackEpgUrl, silent: true);
                  }
                }
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.of(context)?.playlistImported ?? 'Playlist imported successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            _nameController.clear();
            _urlController.clear();
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } else if (PlatformDetector.isTV) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context)?.noFileSelected ?? 'No file selected'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((AppStrings.of(context)?.errorPickingFile ?? 'Error picking file: {error}').replaceAll('{error}', '$e')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

