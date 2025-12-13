---
description: How to build and run FlutterIPTV application
---

# FlutterIPTV Build and Run Workflow

## Prerequisites

1. Install Flutter SDK (3.0.0 or higher)
2. For Windows: Install Visual Studio 2022 with C++ desktop development
3. For Android: Install Android Studio with Kotlin support

## Setup

// turbo
1. Navigate to project directory:
```bash
cd c:\project\FlutterIPTV
```

2. Get dependencies:
```bash
flutter pub get
```

## Running the App

### Windows (PC)
// turbo
```bash
flutter run -d windows
```

### Android Mobile
1. Connect your Android device or start an emulator
// turbo
2. Run the app:
```bash
flutter run -d <device_id>
```

### Android TV
1. Connect your Android TV device via ADB
// turbo
2. Run the app:
```bash
flutter run -d <tv_device_id>
```

## Building for Release

### Windows
```bash
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\`

### Android APK (Universal)
```bash
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### Android APK (Split by ABI)
```bash
flutter build apk --split-per-abi --release
```
Outputs:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (x86_64 for emulators)

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build\app\outputs\bundle\release\app-release.aab`

## Testing

// turbo
```bash
flutter test
```

## Common Issues

### Windows: Visual Studio not found
Make sure Visual Studio 2022 is installed with "Desktop development with C++" workload.

### Android: SDK not found
Run `flutter doctor` and follow the instructions to configure Android SDK.

### Android TV: Remote navigation not working
Ensure all focusable widgets are wrapped with `TVFocusable` widget.

## Adding a Test M3U Playlist

For testing, you can use any public M3U URL. Some examples:
- Open the app
- Go to Playlist Manager
- Add a name and M3U URL
- Click "Add from URL"

The app will parse the playlist and show all available channels.
