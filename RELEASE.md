# Release Guide

This document explains how to create releases for FlutterIPTV.

## Automated Releases via GitHub Actions

The project uses GitHub Actions to automatically build and release the application.

### Triggering a Release

There are two ways to trigger a release:

#### Method 1: Create a Git Tag (Recommended)

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.0+1
   ```

2. Commit the change:
   ```bash
   git add pubspec.yaml
   git commit -m "chore: bump version to 1.0.0"
   ```

3. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. GitHub Actions will automatically:
   - Build Windows application
   - Build Android Mobile APKs
   - Build Android TV APKs
   - Create a GitHub Release with all artifacts

#### Method 2: Manual Workflow Dispatch

1. Go to **Actions** tab in your GitHub repository
2. Select **"Build and Release"** workflow
3. Click **"Run workflow"** dropdown
4. Enter the version number (e.g., `1.0.0`)
5. Click **"Run workflow"** button

### Release Artifacts

Each release includes:

| Platform | File | Description |
|----------|------|-------------|
| **Windows** | `FlutterIPTV-Windows-x64.zip` | Portable Windows 64-bit application |
| **Android Mobile** | `FlutterIPTV-Android-Mobile-arm64-v8a.apk` | 64-bit ARM (modern phones) |
| **Android Mobile** | `FlutterIPTV-Android-Mobile-armeabi-v7a.apk` | 32-bit ARM (older phones) |
| **Android Mobile** | `FlutterIPTV-Android-Mobile-x86_64.apk` | x86_64 (emulators) |
| **Android Mobile** | `FlutterIPTV-Android-Mobile-universal.apk` | Universal (all architectures) |
| **Android TV** | `FlutterIPTV-AndroidTV-arm64-v8a.apk` | 64-bit ARM TV devices |
| **Android TV** | `FlutterIPTV-AndroidTV-armeabi-v7a.apk` | 32-bit ARM TV devices |
| **Android TV** | `FlutterIPTV-AndroidTV-x86_64.apk` | x86_64 TV emulators |
| **Android TV** | `FlutterIPTV-AndroidTV-universal.apk` | Universal TV (all architectures) |

## Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., `1.2.3`)
  - MAJOR: Breaking changes
  - MINOR: New features (backward compatible)
  - PATCH: Bug fixes (backward compatible)

In `pubspec.yaml`:
```yaml
version: 1.2.3+4
#        │ │ │ └── Build number (incremental)
#        │ │ └──── Patch version
#        │ └────── Minor version
#        └──────── Major version
```

## Signing Android APKs

For production releases, you should sign your APKs with a release key.

### Setting up Signing

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
   ```

2. Create `android/key.properties` (do not commit this file):
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=release
   storeFile=../release-key.jks
   ```

3. Add to `android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
           }
       }
   }
   ```

4. For GitHub Actions, add these secrets:
   - `KEYSTORE_BASE64`: Base64-encoded keystore file
   - `KEYSTORE_PASSWORD`: Keystore password
   - `KEY_ALIAS`: Key alias
   - `KEY_PASSWORD`: Key password

## Pre-release Checklist

Before creating a release:

- [ ] Update version in `pubspec.yaml`
- [ ] Update CHANGELOG.md (if you have one)
- [ ] Test on Windows
- [ ] Test on Android Mobile
- [ ] Test on Android TV with D-Pad navigation
- [ ] Verify all features work correctly
- [ ] Review and merge any pending PRs

## Post-release Tasks

After a release:

- [ ] Verify all artifacts are available on the Release page
- [ ] Test downloads on each platform
- [ ] Announce the release (social media, etc.)
- [ ] Update documentation if needed
