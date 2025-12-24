import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field on mobile
    if (!PlatformDetector.useDPadNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = Column(
      children: [
        _buildSearchHeader(),
        Expanded(child: _buildSearchResults()),
      ],
    );

    if (isTV) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: TVSidebar(
          selectedIndex: 3, // 搜索页
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: content,
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          TVFocusable(
            onSelect: () => Navigator.pop(context),
            focusScale: 1.1,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.getTextPrimary(context),
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Search Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.of(context)?.searchHint ?? 'Search channels...',
                  hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.getTextMuted(context),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppTheme.getTextMuted(context),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        if (_searchQuery.isEmpty) {
          return _buildEmptySearch();
        }

        final results = provider.searchChannels(_searchQuery);

        if (results.isEmpty) {
          return _buildNoResults();
        }

        return _buildResultsGrid(results);
      },
    );
  }

  Widget _buildEmptySearch() {
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
              Icons.search_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.searchChannels ?? 'Search Channels',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.typeToSearch ?? 'Type to search by channel name or category',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),

          // Recent Searches (placeholder)
          const SizedBox(height: 40),
          if (PlatformDetector.useDPadNavigation) ...[
            Text(
              AppStrings.of(context)?.popularCategories ?? 'Popular Categories',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppStrings.of(context)?.sports ?? 'Sports',
                AppStrings.of(context)?.movies ?? 'Movies',
                AppStrings.of(context)?.news ?? 'News',
                AppStrings.of(context)?.music ?? 'Music',
                AppStrings.of(context)?.kids ?? 'Kids'
              ].map((category) {
                return TVFocusable(
                  onSelect: () {
                    _searchController.text = category;
                    setState(() => _searchQuery = category);
                  },
                  child: Chip(
                    label: Text(
                      category,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    ),
                    backgroundColor: AppTheme.getSurfaceColor(context),
                    side: BorderSide(color: AppTheme.getCardColor(context)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppTheme.getTextMuted(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(context)?.noResultsFound ?? 'No Results Found',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (AppStrings.of(context)?.noChannelsMatch ?? 'No channels match "{query}"').replaceAll('{query}', _searchQuery),
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<dynamic> results) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = PlatformDetector.getGridCrossAxisCount(size.width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            (AppStrings.of(context)?.resultsFor ?? '{count} result(s) for "{query}"').replaceAll('{count}', '${results.length}').replaceAll('{query}', _searchQuery),
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ),

        // Results Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final channel = results[index];
              final isFavorite = context.read<FavoritesProvider>().isFavorite(channel.id ?? 0);

              return ChannelCard(
                name: channel.name,
                logoUrl: channel.logoUrl,
                groupName: channel.groupName,
                isFavorite: isFavorite,
                autofocus: index == 0 && PlatformDetector.useDPadNavigation,
                onFavoriteToggle: () {
                  context.read<FavoritesProvider>().toggleFavorite(channel);
                },
                onTap: () {
                  // 保存上次播放的频道ID
                  final settingsProvider = context.read<SettingsProvider>();
                  if (settingsProvider.rememberLastChannel && channel.id != null) {
                    settingsProvider.setLastChannelId(channel.id);
                  }

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
              );
            },
          ),
        ),
      ],
    );
  }
}
