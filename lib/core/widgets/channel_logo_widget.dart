import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/service_locator.dart';

/// Widget to display channel logo with fallback priority:
/// 1. M3U logo (if available and loads successfully)
/// 2. Database logo (fuzzy match by channel name)
/// 3. Default placeholder image
class ChannelLogoWidget extends StatefulWidget {
  final Channel channel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ChannelLogoWidget({
    Key? key,
    required this.channel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<ChannelLogoWidget> createState() => _ChannelLogoWidgetState();
}

class _ChannelLogoWidgetState extends State<ChannelLogoWidget> {
  String? _fallbackLogoUrl;
  bool _m3uLogoFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFallbackLogo();
  }

  @override
  void didUpdateWidget(ChannelLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.name != widget.channel.name) {
      _m3uLogoFailed = false;
      _fallbackLogoUrl = null;
      _loadFallbackLogo();
    }
  }

  Future<void> _loadFallbackLogo() async {
    try {
      final logoUrl = await ServiceLocator.channelLogo.findLogoUrl(widget.channel.name);
      if (mounted && logoUrl != null) {
        setState(() {
          _fallbackLogoUrl = logoUrl;
        });
      }
    } catch (e) {
      ServiceLocator.log.w('Failed to load fallback logo for ${widget.channel.name}: $e');
    }
  }

  Widget _buildLogo(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // If M3U logo fails, mark it and try fallback
        if (!_m3uLogoFailed && logoUrl == widget.channel.logoUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _m3uLogoFailed = true;
              });
            }
          });
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: widget.borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          'assets/images/default_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // 如果默认图片也加载失败，显示图标
            return Icon(
              Icons.tv,
              size: (widget.width ?? 48) * 0.5,
              color: Colors.grey[600],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget logoWidget;

    // Priority 1: Try M3U logo if available and not failed
    if (!_m3uLogoFailed && 
        widget.channel.logoUrl != null && 
        widget.channel.logoUrl!.isNotEmpty) {
      logoWidget = _buildLogo(widget.channel.logoUrl);
    }
    // Priority 2: Try database fallback logo
    else if (_fallbackLogoUrl != null) {
      logoWidget = _buildLogo(_fallbackLogoUrl);
    }
    // Priority 3: Default placeholder
    else {
      logoWidget = _buildPlaceholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}
