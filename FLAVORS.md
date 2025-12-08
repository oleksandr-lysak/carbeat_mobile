# Flavor Configuration Guide

This app supports two flavors: **Carbeat** and **FloxCity**. Each flavor has its own:
- App name
- Package/Bundle identifier
- Server endpoints
- App title

## Building with Flavors

### Android

#### Build APK
```bash
# Carbeat
flutter build apk --flavor carbeat --dart-define=FLAVOR=carbeat

# FloxCity
flutter build apk --flavor floxcity --dart-define=FLAVOR=floxcity
```

#### Build App Bundle
```bash
# Carbeat
flutter build appbundle --flavor carbeat --dart-define=FLAVOR=carbeat

# FloxCity
flutter build appbundle --flavor floxcity --dart-define=FLAVOR=floxcity
```

#### Run/Debug
```bash
# Carbeat
flutter run --flavor carbeat --dart-define=FLAVOR=carbeat

# FloxCity
flutter run --flavor floxcity --dart-define=FLAVOR=floxcity
```

### iOS

#### Build
```bash
# Carbeat
flutter build ios --flavor carbeat --dart-define=FLAVOR=carbeat

# FloxCity
flutter build ios --flavor floxcity --dart-define=FLAVOR=floxcity
```

#### Run/Debug
```bash
# Carbeat
flutter run --flavor carbeat --dart-define=FLAVOR=carbeat

# FloxCity
flutter run --flavor floxcity --dart-define=FLAVOR=floxcity
```

## Flavor Configuration

### Carbeat
- **App Name**: Carbeat
- **Android Package**: `online.carbeat.app`
- **iOS Bundle ID**: `online.carbeat.app`
- **Production Server**: `https://carbeat.online/`
- **Socket Server**: `https://socket.carbeat.online/`

### FloxCity
- **App Name**: FloxCity
- **Android Package**: `online.floxcity.app`
- **iOS Bundle ID**: `online.floxcity.app`
- **Production Server**: `https://floxcity.online/`
- **Socket Server**: `https://socket.floxcity.online/`

## iOS Setup (Additional Configuration Required)

For iOS, you need to manually configure schemes in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Create build configurations for each flavor:
   - Go to Project Settings → Info
   - Duplicate Debug and Release configurations
   - Name them: `Debug-Carbeat`, `Release-Carbeat`, `Debug-FloxCity`, `Release-FloxCity`
3. Create schemes:
   - Product → Scheme → Manage Schemes
   - Create schemes: `Carbeat` and `FloxCity`
   - For each scheme, set the build configuration:
     - Debug: Use `Debug-Carbeat` or `Debug-FloxCity`
     - Release: Use `Release-Carbeat` or `Release-FloxCity`
4. Set bundle identifiers:
   - In Build Settings, set `PRODUCT_BUNDLE_IDENTIFIER`:
     - Carbeat: `online.carbeat.app`
     - FloxCity: `online.floxcity.app`
5. Set app display names:
   - In Info.plist or Build Settings, set `CFBundleDisplayName`:
     - Carbeat: `Carbeat`
     - FloxCity: `FloxCity`

## Configuration Files

- **Flavor Config**: `lib/config/flavor_config.dart`
- **App Constants**: `lib/constants/app_constants.dart` (uses flavor config)
- **Android**: `android/app/build.gradle.kts` (product flavors)
- **iOS**: `ios/Flutter/*.xcconfig` (build configurations)

## Notes

- The flavor is determined at build time via `--dart-define=FLAVOR=<flavor_name>`
- If no flavor is specified, it defaults to `carbeat`
- Server URLs automatically switch between local (debug) and production (release) based on build mode
- Each flavor can have different Firebase configurations (google-services.json for Android, GoogleService-Info.plist for iOS)

