import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/player_provider.dart';


class PlayerGestureOverlay extends StatefulWidget {
  final Widget child;
  final bool showCategoryPanel;
  final VoidCallback onShowControls;
  final VoidCallback onHideControls;
  final Function(bool) onToggleCategoryPanel;
  final Function(String?) onCategorySelected;
  final VoidCallback onTogglePlayPause;
  final VoidCallback? onPlayNext;
  final VoidCallback? onPlayPrevious;

  const PlayerGestureOverlay({
    super.key,
    required this.child,
    required this.showCategoryPanel,
    required this.onShowControls,
    required this.onHideControls,
    required this.onToggleCategoryPanel,
    required this.onCategorySelected,
    required this.onTogglePlayPause,
    this.onPlayNext,
    this.onPlayPrevious,
  });


  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay> {
  Offset? _panStartPosition;
  String? _currentGestureType;
  double _gestureStartY = 0;
  double _initialVolume = 0;
  double _initialBrightness = 0;
  bool _showGestureIndicator = false;
  double _gestureValue = 0;
  Timer? _hideControlsTimer;

  void _showControlsTemporarily() {
    widget.onShowControls();
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) widget.onHideControls();
    });
  }

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = details.globalPosition;
    _currentGestureType = null;

    final playerProvider = context.read<PlayerProvider>();
    _initialVolume = playerProvider.volume;
    _gestureStartY = details.globalPosition.dy;

    _loadCurrentBrightness();
  }

  Future<void> _loadCurrentBrightness() async {
    try {
      _initialBrightness = await ScreenBrightness.instance.current;
    } catch (_) {
      _initialBrightness = 0.5;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panStartPosition == null) return;

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;

    if (_currentGestureType == null) {
      const threshold = 10.0;
      if (dx.abs() > threshold || dy.abs() > threshold) {
        final screenWidth = MediaQuery.of(context).size.width;
        final x = _panStartPosition!.dx;

        if (dy.abs() > dx.abs()) {
          if (x < screenWidth * 0.35) {
            _currentGestureType = 'volume';
            _gestureValue = _initialVolume;
          } else if (x > screenWidth * 0.65) {
            _currentGestureType = 'brightness';
            _gestureValue = _initialBrightness;
          } else {
            _currentGestureType = 'channel';
          }
        } else {
          _currentGestureType = 'horizontal';
        }
      }
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;

    if (_currentGestureType == 'volume') {
      final volumeChange = (deltaY / (screenHeight * 0.5)) * 1.0;
      final newVolume = (_initialVolume + volumeChange).clamp(0.0, 1.0);
      context.read<PlayerProvider>().setVolume(newVolume);
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newVolume;
      });
    } else if (_currentGestureType == 'brightness') {
      final brightnessChange = (deltaY / (screenHeight * 0.5)) * 1.0;
      final newBrightness = (_initialBrightness + brightnessChange).clamp(0.0, 1.0);
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
      } catch (_) {}
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newBrightness;
      });
    } else if (_currentGestureType == 'channel') {
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = dy.clamp(-100.0, 100.0) / 100.0;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_panStartPosition == null) {
      _resetGestureState();
      return;
    }

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_currentGestureType == 'channel') {
      final threshold = screenHeight * 0.08;
      if (dy.abs() > threshold) {
        if (dy > 0) {
          widget.onPlayPrevious?.call();
        } else {
          widget.onPlayNext?.call();
        }
      }
    }


    if (_currentGestureType == 'horizontal') {
      final threshold = screenWidth * 0.15;
      if (dx < -threshold && !widget.showCategoryPanel) {
        widget.onToggleCategoryPanel(true);
        widget.onCategorySelected(null);
        widget.onHideControls();
      } else if (dx > threshold && widget.showCategoryPanel) {
        widget.onToggleCategoryPanel(false);
        widget.onCategorySelected(null);
      }
    }

    _resetGestureState();
  }

  void _resetGestureState() {
    setState(() {
      _showGestureIndicator = false;
    });
    _panStartPosition = null;
    _currentGestureType = null;
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _showControlsTemporarily(),
      onExit: (_) {
        if (mounted) {
          _hideControlsTimer?.cancel();
          _hideControlsTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) widget.onHideControls();
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (widget.showCategoryPanel) {
            widget.onToggleCategoryPanel(false);
            widget.onCategorySelected(null);
          } else {
            _showControlsTemporarily();
          }
        },
        onDoubleTap: widget.onTogglePlayPause,
        onPanStart: PlatformDetector.isMobile ? _onPanStart : null,
        onPanUpdate: PlatformDetector.isMobile ? _onPanUpdate : null,
        onPanEnd: PlatformDetector.isMobile ? _onPanEnd : null,
        child: Stack(
          children: [
            widget.child,
            if (_showGestureIndicator)
              _buildGestureIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureIndicator() {
    IconData icon;
    String text = '';

    if (_currentGestureType == 'volume') {
      icon = _gestureValue == 0 ? Icons.volume_off : Icons.volume_up;
      text = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'brightness') {
      icon = Icons.brightness_6;
      text = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'channel') {
      icon = _gestureValue > 0 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up;
      text = '';
    } else {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
