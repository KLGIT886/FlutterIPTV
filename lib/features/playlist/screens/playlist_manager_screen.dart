import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../providers/playlist_provider.dart';

class PlaylistManagerScreen extends StatefulWidget {
  const PlaylistManagerScreen({super.key});

  @override
  State<PlaylistManagerScreen> createState() => _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends State<PlaylistManagerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Playlist Manager',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Add Playlist Section
              _buildAddPlaylistSection(provider),
              
              const Divider(color: AppTheme.cardColor, height: 1),
              
              // Playlists List
              Expanded(
                child: provider.playlists.isEmpty
                    ? _buildEmptyState()
                    : _buildPlaylistsList(provider),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildAddPlaylistSection(PlaylistProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add New Playlist',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name Input
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.label_outline, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // URL Input
          TextField(
            controller: _urlController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'M3U/M3U8 URL',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.link, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TVFocusable(
                  onSelect: () => _addPlaylist(provider),
                  child: ElevatedButton.icon(
                    onPressed: provider.isLoading ? null : () => _addPlaylist(provider),
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 20),
                    label: Text(provider.isLoading ? 'Importing...' : 'Add from URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TVFocusable(
                onSelect: () {
                  // TODO: Implement file picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File picker not implemented yet'),
                    ),
                  );
                },
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement file picker
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: const Text('From File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Progress Indicator
          if (provider.isLoading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.importProgress,
                backgroundColor: AppTheme.cardColor,
                color: AppTheme.primaryColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(provider.importProgress * 100).toInt()}% Complete',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          // Error Message
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 13,
                      ),
                    ),
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
      ),
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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              size: 50,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Playlists',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first M3U playlist above',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaylistsList(PlaylistProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.playlists.length,
      itemBuilder: (context, index) {
        final playlist = provider.playlists[index];
        return _buildPlaylistCard(provider, playlist);
      },
    );
  }
  
  Widget _buildPlaylistCard(PlaylistProvider provider, dynamic playlist) {
    return TVFocusable(
      onSelect: () => provider.setActivePlaylist(playlist),
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        final isActive = provider.activePlaylist?.id == playlist.id;
        
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.primaryColor.withOpacity(0.1),
                    ],
                  )
                : null,
            color: isActive ? null : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? AppTheme.focusBorderColor
                  : isActive
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.focusColor.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
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
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.activePlaylist?.id == playlist.id)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${playlist.channelCount} channels • ${playlist.groupCount} groups',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (playlist.lastUpdated != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Updated: ${_formatDate(playlist.lastUpdated!)}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.textSecondary,
                onPressed: () => _refreshPlaylist(provider, playlist),
                tooltip: 'Refresh',
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.errorColor,
                onPressed: () => _confirmDelete(provider, playlist),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  Future<void> _addPlaylist(PlaylistProvider provider) async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a playlist name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a playlist URL'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    final playlist = await provider.addPlaylistFromUrl(name, url);
    
    if (playlist != null && mounted) {
      _nameController.clear();
      _urlController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${playlist.name}" with ${playlist.channelCount} channels'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
  
  Future<void> _refreshPlaylist(PlaylistProvider provider, dynamic playlist) async {
    final success = await provider.refreshPlaylist(playlist);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Playlist refreshed successfully'
                : 'Failed to refresh playlist',
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }
  
  void _confirmDelete(PlaylistProvider provider, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Playlist',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete "${playlist.name}"? This will also remove all channels from this playlist.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.deletePlaylist(playlist.id);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Playlist deleted'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
