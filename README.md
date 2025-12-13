# FlutterIPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="FlutterIPTV Logo">
</p>

<p align="center">
  <strong>A Professional IPTV Player Application</strong>
</p>

<p align="center">
  Built with Flutter for Windows, Android Mobile, and Android TV
</p>

<p align="center">
  <a href="https://github.com/yourusername/FlutterIPTV/actions/workflows/ci.yml">
    <img src="https://github.com/yourusername/FlutterIPTV/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="https://github.com/yourusername/FlutterIPTV/actions/workflows/build-release.yml">
    <img src="https://github.com/yourusername/FlutterIPTV/actions/workflows/build-release.yml/badge.svg" alt="Build and Release">
  </a>
  <a href="https://github.com/yourusername/FlutterIPTV/releases/latest">
    <img src="https://img.shields.io/github/v/release/yourusername/FlutterIPTV?include_prereleases" alt="Release">
  </a>
  <a href="https://github.com/yourusername/FlutterIPTV/releases/latest">
    <img src="https://img.shields.io/github/downloads/yourusername/FlutterIPTV/total" alt="Downloads">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/yourusername/FlutterIPTV" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://github.com/yourusername/FlutterIPTV/releases/latest">
    <img src="https://img.shields.io/badge/Download-Windows-blue?style=for-the-badge&logo=windows" alt="Download Windows">
  </a>
  <a href="https://github.com/yourusername/FlutterIPTV/releases/latest">
    <img src="https://img.shields.io/badge/Download-Android-green?style=for-the-badge&logo=android" alt="Download Android">
  </a>
  <a href="https://github.com/yourusername/FlutterIPTV/releases/latest">
    <img src="https://img.shields.io/badge/Download-Android%20TV-orange?style=for-the-badge&logo=android" alt="Download Android TV">
  </a>
</p>

---

## ✨ Features

### 📺 Multi-Platform Support
- **Windows (PC)** - Full keyboard and mouse support
- **Android Mobile** - Touch-optimized interface
- **Android TV** - Complete D-Pad/Remote navigation support

### 🎬 Player Features
- High-quality video playback using media_kit (libmpv)
- Support for multiple streaming formats:
  - HLS (M3U8)
  - DASH
  - RTMP/RTSP
  - Direct HTTP streams
- Hardware-accelerated decoding
- Adjustable playback speed
- Volume control with mute toggle

### 📋 Playlist Management
- Import M3U/M3U8 playlists from URL
- Import local playlist files
- Automatic playlist refresh
- Support for multiple playlists

### 🗂️ Channel Organization
- Automatic grouping by categories
- Search channels by name or group
- Favorites with drag-and-drop reordering
- Watch history tracking

### ⚙️ Settings & Customization
- Playback buffer size configuration
- Auto-play preferences
- Parental control with PIN
- EPG (Electronic Program Guide) support (coming soon)

### 🎨 Modern UI/UX
- Beautiful dark theme optimized for TV viewing
- Smooth animations and transitions
- Focus-based navigation for TV remotes
- Responsive design for all screen sizes

---

## 📱 Platform-Specific Features

### Android TV
- **Full D-Pad Navigation** - Every element is focusable
- **Leanback Support** - Shows in Android TV launcher
- **10-foot UI** - Optimized for viewing from a distance
- **Remote Control Shortcuts**:
  - Arrow keys: Navigate
  - Enter/Select: Confirm action
  - Back: Go back/Exit
  - Play/Pause: Toggle playback

### Windows
- **Keyboard Shortcuts**:
  - Space: Play/Pause
  - Arrow Left/Right: Seek backward/forward
  - Arrow Up/Down: Volume control
  - M: Toggle mute
  - Escape: Exit fullscreen/Go back
- Resizable window
- Multi-monitor support

### Android Mobile
- Touch-optimized controls
- Gesture support for player
- Double-tap to play/pause
- Swipe for volume/brightness

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or higher
- For Windows: Visual Studio 2022 with C++ desktop development
- For Android: Android Studio with Kotlin support

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/FlutterIPTV.git
   cd FlutterIPTV
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on your device**
   ```bash
   # For Windows
   flutter run -d windows
   
   # For Android (Mobile or TV)
   flutter run -d <device_id>
   
   # List available devices
   flutter devices
   ```

### Building for Release

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── database/               # SQLite database helper
│   ├── models/                 # Data models
│   ├── navigation/             # App router
│   ├── platform/               # Platform detection
│   ├── services/               # Service locator
│   ├── theme/                  # App theme
│   ├── utils/                  # Utilities (M3U parser, etc.)
│   └── widgets/                # Reusable widgets
└── features/
    ├── channels/               # Channels listing
    ├── epg/                    # Electronic Program Guide
    ├── favorites/              # Favorites management
    ├── home/                   # Home screen
    ├── player/                 # Video player
    ├── playlist/               # Playlist management
    ├── search/                 # Search functionality
    ├── settings/               # App settings
    └── splash/                 # Splash screen
```

---

## 🔧 Configuration

### Adding a Playlist
1. Open the app
2. Go to Playlist Manager (+ icon on home screen)
3. Enter a name and M3U URL
4. Click "Add from URL"

### EPG Configuration
1. Go to Settings
2. Enable EPG
3. Enter your EPG XMLTV URL
4. The app will automatically match channels

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📞 Support

If you have any questions or run into issues, please open an issue on GitHub.

---

<p align="center">
  Made with ❤️ using Flutter
</p>
