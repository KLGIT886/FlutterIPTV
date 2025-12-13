import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

class ChannelsScreen extends StatefulWidget {
  final String? groupName;
  
  const ChannelsScreen({
    super.key,
    this.groupName,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String? _selectedGroup;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groupName;
    
    if (_selectedGroup != null) {
      context.read<ChannelProvider>().selectGroup(_selectedGroup!);
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Groups Sidebar (for TV and Desktop)
          if (isTV) _buildGroupsSidebar(),
          
          // Channels Grid
          Expanded(
            child: _buildChannelsContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupsSidebar() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        return Container(
          width: 240,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.cardColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TVFocusable(
                      onSelect: () => Navigator.of(context).pop(),
                      focusScale: 1.1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Categories',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // All Channels Option
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _buildGroupItem(
                  name: 'All Channels',
                  count: provider.totalChannelCount,
                  isSelected: _selectedGroup == null,
                  onTap: () {
                    setState(() => _selectedGroup = null);
                    provider.clearGroupFilter();
                  },
                ),
              ),
              
              const Divider(color: AppTheme.cardColor, height: 1),
              
              // Groups List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: provider.groups.length,
                  itemBuilder: (context, index) {
                    final group = provider.groups[index];
                    return _buildGroupItem(
                      name: group.name,
                      count: group.channelCount,
                      isSelected: _selectedGroup == group.name,
                      onTap: () {
                        setState(() => _selectedGroup = group.name);
                        provider.selectGroup(group.name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildGroupItem({
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TVFocusable(
        onSelect: onTap,
        focusScale: 1.02,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : isFocused
                      ? AppTheme.cardColor
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused
                    ? AppTheme.focusBorderColor
                    : isSelected
                        ? AppTheme.primaryColor.withOpacity(0.5)
                        : Colors.transparent,
                width: isFocused ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: AppTheme.animationFast,
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
  
  Widget _buildChannelsContent() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        final channels = provider.filteredChannels;
        final size = MediaQuery.of(context).size;
        final crossAxisCount = PlatformDetector.getGridCrossAxisCount(size.width);
        
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.backgroundColor.withOpacity(0.95),
              title: Text(
                _selectedGroup ?? 'All Channels',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                // Channel count
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${channels.length} channels',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Channels Grid
            if (channels.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.live_tv_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No channels found',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final channel = channels[index];
                      final isFavorite = context.read<FavoritesProvider>()
                          .isFavorite(channel.id ?? 0);
                      
                      return ChannelCard(
                        name: channel.name,
                        logoUrl: channel.logoUrl,
                        groupName: channel.groupName,
                        isFavorite: isFavorite,
                        autofocus: index == 0,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.player,
                            arguments: {
                              'channelUrl': channel.url,
                              'channelName': channel.name,
                              'channelLogo': channel.logoUrl,
                            },
                          );
                        },
                        onLongPress: () => _showChannelOptions(context, channel),
                      );
                    },
                    childCount: channels.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  void _showChannelOptions(BuildContext context, dynamic channel) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final isFavorite = favoritesProvider.isFavorite(channel.id ?? 0);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel name
              Text(
                channel.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Options
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? AppTheme.accentColor : AppTheme.textSecondary,
                ),
                title: Text(
                  isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  await favoritesProvider.toggleFavorite(channel);
                  Navigator.pop(context);
                },
              ),
              
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: const Text(
                  'Channel Info',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show channel info dialog
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
