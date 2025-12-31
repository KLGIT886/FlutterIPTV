# Lotus IPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Lotus IPTV Logo">
</p>

<p align="center">
  <strong>A Modern IPTV Player for Windows, Android, and Android TV</strong>
</p>

<p align="center">
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/badge/version-1.1.82-blue.svg" alt="Version">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml">
    <img src="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/downloads/shnulaa/FlutterIPTV/total" alt="Downloads">
  </a>
</p>

<p align="center">
  <strong>English</strong> | <a href="README_ZH.md">中文</a>
</p>

Lotus IPTV is a modern, high-performance IPTV player built with Flutter. Features a beautiful Lotus-themed UI with pink/purple gradient accents, optimized for seamless viewing across desktop, mobile, and TV platforms.

## ✨ Features

### 🎨 Lotus Theme UI
- Pure black background with lotus pink/purple gradient accents
- Glassmorphism style cards for desktop/mobile
- TV-optimized interface with smooth performance
- Auto-collapsing sidebar navigation

### 📺 Multi-Platform Support
- **Windows**: Desktop-optimized UI with keyboard shortcuts and mini mode
- **Android Mobile**: Touch-friendly interface with gesture controls
- **Android TV**: Full D-Pad navigation with remote control support

### ⚡ High-Performance Playback
- **Desktop/Mobile**: Powered by `media_kit` with hardware acceleration
- **Android TV**: Native ExoPlayer (Media3) for 4K video playback
- Real-time FPS display (configurable in settings)
- Video stats display (resolution, codec info)
- Supports HLS (m3u8), MP4, MKV, RTMP/RTSP and more

### 📂 Smart Playlist Management
- Import M3U/M3U8 playlists from local files or URLs
- QR code import for easy mobile-to-TV transfer
- Auto-grouping by `group-title`
- Preserves original M3U category order
- Channel availability testing with batch operations

### ❤️ User Features
- Favorites management with long-press support
- Channel search by name or group
- In-player category panel (press LEFT key)
- Double-press BACK to exit player (prevents accidental exit)
- Watch history tracking
- Default channel logo for missing thumbnails

## 📸 Screenshots

<p align="center">
  <img src="assets/screenshots/home_screen.png" width="30%" alt="Home Screen">
  <img src="assets/screenshots/channels_screen.png" width="30%" alt="Channels Screen">
  <img src="assets/screenshots/player_screen.png" width="30%" alt="Player Screen">
</p>

## 🚀 Download

Download the latest version (v1.1.82) from [Releases Page](https://github.com/shnulaa/FlutterIPTV/releases/tag/v1.1.82).

### Windows
- [Windows x64 Installer](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-Windows-x64-Setup.exe)

### Android Mobile
| Architecture | Download |
|--------------|----------|
| arm64-v8a | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-Android-Mobile-arm64-v8a.apk) |
| armeabi-v7a | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-Android-Mobile-armeabi-v7a.apk) |
| x86_64 | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-Android-Mobile-x86_64.apk) |

### Android TV
| Architecture | Download |
|--------------|----------|
| arm64-v8a | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-AndroidTV-arm64-v8a.apk) |
| armeabi-v7a | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-AndroidTV-armeabi-v7a.apk) |
| x86_64 | [Download APK](https://github.com/shnulaa/FlutterIPTV/releases/download/v1.1.82/flutteriptv-AndroidTV-x86_64.apk) |

## 🎮 Controls

| Action | Keyboard | TV Remote |
|--------|----------|-----------|
| Play/Pause | Space/Enter | OK |
| Channel Up | ↑ | D-Pad Up |
| Channel Down | ↓ | D-Pad Down |
| Open Category Panel | ← | D-Pad Left |
| Favorite | F | Long Press OK |
| Mute | M | - |
| Exit Player | Double Esc | Double Back |

## 🆕 What's New in v1.1.82

- Add FPS display setting (enabled by default)
- Show real-time frame rate in player top-right corner
- Windows mini mode shows FPS in bottom-right corner

## 🛠️ Development

### Prerequisites
- Flutter SDK (>=3.5.0)
- Android Studio (for Android/TV builds)
- Visual Studio (for Windows builds)

### Build
```bash
git clone https://github.com/shnulaa/FlutterIPTV.git
cd FlutterIPTV
flutter pub get

# Run
flutter run -d windows
flutter run -d <android_device>

# Build Release
flutter build windows
flutter build apk --release
```

## 🤝 Contributing

Pull requests are welcome!

## ⚠️ Disclaimer

This application is a player only and does not provide any content. Users must provide their own M3U playlists. Developers are not responsible for the content played through this application.

## 📄 License

This project is licensed under the MIT License.
