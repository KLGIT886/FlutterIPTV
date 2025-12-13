# Changelog

All notable changes to FlutterIPTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-13

### Added
- Initial release of FlutterIPTV
- **Multi-Platform Support**
  - Windows (PC) with keyboard/mouse navigation
  - Android Mobile with touch-optimized interface
  - Android TV with full D-Pad/Remote navigation
- **Video Player**
  - High-quality playback using media_kit (libmpv)
  - Support for HLS, DASH, RTMP/RTSP streams
  - Hardware-accelerated decoding
  - Playback speed control (0.5x - 2.0x)
  - Volume control with mute toggle
- **Playlist Management**
  - Import M3U/M3U8 playlists from URL
  - Import local playlist files
  - Automatic playlist refresh
  - Multiple playlist support
- **Channel Features**
  - Automatic grouping by categories
  - Channel search by name or group
  - Favorites with drag-and-drop reordering
  - Watch history tracking
- **Settings**
  - Playback buffer configuration
  - Auto-play preferences
  - Last channel memory
  - Parental control with PIN
- **UI/UX**
  - Beautiful dark theme optimized for TV
  - Smooth animations and transitions
  - Focus-based navigation for TV remotes
  - Responsive design for all screen sizes

### Technical
- Flutter 3.x compatible
- Provider state management
- SQLite local database
- MediaKit video player integration
- Platform channel for Android TV detection

---

## [Unreleased]

### Planned Features
- EPG (Electronic Program Guide) support
- Channel logos caching
- Multiple audio track selection
- Subtitle support
- Picture-in-Picture mode (Android)
- Chromecast support
- Recording functionality
