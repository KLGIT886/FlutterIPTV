# Lotus IPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Lotus IPTV Logo">
</p>

<p align="center">
  <strong>A Professional IPTV Player for Windows, Android, and Android TV</strong>
</p>

<p align="center">
  <a href="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml">
    <img src="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/v/release/shnulaa/FlutterIPTV?include_prereleases" alt="Latest Release">
  </a>
</p>

<p align="center">
  **English** | <a href="README_ZH.md">中文</a>
</p>

Lotus IPTV is a modern, high-performance IPTV player application developed with Flutter. It offers a seamless viewing experience across multiple platforms, with a special focus on usability and aesthetics.

## 📸 Screenshots

<p align="center">
  <img src="assets/screenshots/home_screen.png" width="30%" alt="Home Screen">
  <img src="assets/screenshots/channels_screen.png" width="30%" alt="Channels Screen">
  <img src="assets/screenshots/player_screen.jpg" width="30%" alt="Player Screen">
</p>

## ✨ Features

- **📺 Cross-Platform Excellence**:
  - **Windows**: Desktop-optimized UI with keyboard support.
  - **Android Mobile**: Touch-friendly interface for phones and tablets.
  - **Android TV**: Fully optimized D-Pad navigation for remote controls.

- **⚡ High-Performance Player**:
  - Powered by `media_kit` for hardware-accelerated playback.
  - **Real-time Stats**: Displays video resolution (e.g., 1920x1080) and technical info.
  - **Fullscreen Mode**: Toggle immersive viewing with a single click.
  - **Format Support**: Handles HLS (m3u8), MP4, MKV, and more.

- **📂 Smart Playlist Management**:
  - **M3U Support**: Import playlists from local files or URLs.
  - **Auto-Grouping**: Automatically categorizes channels based on `group-title`.
  - **Robust Parsing**: Intellegently handles messy URLs and complex M3U tags.
  - **Local Logos**: Supports displaying channel icons from local storage.

- **❤️ User-Friendly Tools**:
  - **Favorites**: Quickly mark channels as favorites for easy access (toggle directly in player).
  - **Discovery**: "All Channels" section randomly features 10 channels to help you discover new content.
  - **Search**: Fast channel searching.

## 🚀 Installation

Download the latest version from the [Releases Page](https://github.com/shnulaa/FlutterIPTV/releases).

### Android / Android TV
1. Download the `flutter_iptv-android-arm64-vX.X.X.apk` (or universal apk).
2. Install via ADB or your device's file manager.

### Windows
1. Download `flutter_iptv-windows-vX.X.X.zip`.
2. Extract the archive.
3. Run `flutter_iptv.exe`.

## 🎮 Controls & Shortcuts

| Action | Keyboard | TV Remote / D-Pad |
|--------|----------|-------------------|
| **Play / Pause** | Space / Enter | Center Button (OK) |
| **Volume Up** | Arrow Up | D-Pad Up |
| **Volume Down** | Arrow Down | D-Pad Down |
| **Seek Forward** | Arrow Right | D-Pad Right |
| **Seek Backward** | Arrow Left | D-Pad Left |
| **Mute** | M | - |
| **Back** | Esc | Back Button |
| **Fullscreen**| Button in UI | - |

## 🛠️ Development

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Visual Studio (for Windows build)
- Android Studio / SDK (for Android build)

### Build Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/shnulaa/FlutterIPTV.git
   cd FlutterIPTV
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run locally**
   ```bash
   flutter run -d windows
   # or
   flutter run -d android
   ```

4. **Build Release**
   ```bash
   flutter build windows
   flutter build apk --split-per-abi
   ```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## ⚠️ Disclaimer

This application is **only a player** and does not provide any default playlists or content. Users must provide their own content. The developers are not responsible for how the application is used or the content played through it.
