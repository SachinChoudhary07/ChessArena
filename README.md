# Chess4Cash

Chess4Cash is a cross-platform Flutter application that lets users play competitive chess matches
and win real money. The app integrates Firebase for authentication, data storage, and push
notifications, uses Razorpay for payments, and embeds the Stockfish chess engine for single-player
practice.

---

## Table of Contents

1. Features
2. Tech Stack & Versions
3. Folder Structure
4. Prerequisites
5. Getting Started
6. Running & Building
7. Environment / Secrets
8. Useful Commands
9. Contributing
10. License

---

## 1  Features

• Email with Firebase Auth  
• Real-time game rooms powered by Cloud Firestore & Realtime Database  
• Secure cash stakes and payouts via Razorpay  
• Push notifications (Firebase Messaging + Flutter Local Notifications)  
• Profile management with image picker & cropper  
• Game analytics and leader-board

---

## 2  Tech Stack & Versions

### Flutter / Dart

• Flutter SDK ≥ 3.24.0   (see `.flutter` in repo)  
• Dart SDK ≥ 3.5.2 (defined in `pubspec.yaml`)

### Core Dependencies (direct)

| Package                     | Version | Purpose                  |
|-----------------------------|---------|--------------------------|
| provider                    | 6.1.5   | State management         |
| firebase_core               | 3.15.1  | Firebase core bindings   |
| firebase_auth               | 5.6.2   | User auth                |
| cloud_firestore             | 5.6.11  | Realtime data            |
| firebase_database           | 11.3.9  | Legacy realtime DB       |
| firebase_storage            | 12.4.9  | File storage             |
| firebase_messaging          | 15.2.9  | Push notifications       |
| firebase_app_check          | 0.3.2+9 | Device/App integrity     |
| google_sign_in              | 6.2.2   | Google OAuth             |
| razorpay_flutter            | 1.4.0   | Payments                 |
| flutter_chess_board         | 1.0.1   | Chess board widget       |
| bishop                      | 1.4.4   | Chess logic              |
| square_bishop               | 0.3.0   | Chess square helpers     |
| squares                     | 1.2.1   | Chess UI helpers         |
| stockfish                   | 1.7.1   | Embedded chess engine    |
| cached_network_image        | 3.4.1   | Image caching            |
| image_picker                | 1.1.2   | Select images            |
| image_cropper               | 8.1.0   | Crop images              |
| permission_handler          | 11.4.0  | Runtime permissions      |
| shared_preferences          | 2.5.3   | Key-value storage        |
| flutter_local_notifications | 19.4.0  | Local notifications      |
| intl                        | 0.20.2  | Date & number formatting |
| share_plus                  | 10.1.4  | System share sheet       |
| uuid                        | 4.5.1   | ID generation            |

Full locked versions are recorded in `pubspec.lock`.

### Android

• compileSdk 35  
• minSdk 23  
• targetSdk 35 (inherited from Flutter 3.24)  
• Kotlin 1.9.23 (via Flutter Gradle)

### iOS

• Xcode 15 or higher  
• Platform iOS 12.0+

---

## 3  Folder Structure (top-level)

```text
lib/              → Dart source code
  ├─ Constant/     → Static values & helpers
  ├─ Firebase/     → Firebase service helpers + `serverKey.json`
  ├─ Providers/    → Provider state classes
  ├─ Screens/      → UI screens & flows
  ├─ Services/     → Business logic / API wrappers
  ├─ Widgets/      → Re-usable UI widgets
assets/           → Images & splash icons
android/          → Android Gradle project
ios/              → Xcode project
web/ linux/ macos/ windows/ → Desktop / Web targets
analysis_options.yaml → Static analysis rules
pubspec.yaml      → Dependencies & assets list
```

---

## 4  Prerequisites

1. **Flutter SDK** 3.24.0 stable (install
   from [flutter.dev](https://flutter.dev/docs/get-started/install)).
   ```bash
   flutter --version   # should report 3.24.x
   ```
2. **Firebase Project** with Android & iOS apps added.  
   • Download `google-services.json` → place in `android/app/`.  
   • Download `GoogleService-Info.plist` → place in `ios/Runner/`.
3. **Android Studio / Xcode** for platform builds.
4. (Android release only) create `key.properties` & keystore:

---

## 5  Getting Started

```bash
# 1. Clone
$ git clone <repo-url> && cd Chess4Cash

# 2. Install packages
$ flutter pub get

# 3. Generate native splash (only first time)
$ flutter pub run flutter_native_splash:create
```

---

## 6  Running & Building

### Debug

```bash
flutter run            # picks first connected device
flutter run -d chrome  # web
```

### Release APK

```bash
flutter build apk --release
```

### Release AppBundle (Play Store)

```bash
flutter build appbundle --release
```

### iOS (macOS only)

```bash
flutter build ios --release
open ios/Runner.xcworkspace     # archive in Xcode
```

---

## 7  Environment / Secrets

| File                                    | Purpose                   |
|-----------------------------------------|---------------------------|
| `android/app/google-services.json`      | Firebase Android config   |
| `ios/Runner/GoogleService-Info.plist`   | Firebase iOS config       |
| `key.properties` / `my-release-key.jks` | Android signing           |
| `lib/Firebase/serverKey.json`           | Firebase server key (FCM) |

**‼️ NEVER commit secret keys to public repos.**

---

## 8  Useful Commands

```bash
flutter pub outdated            # check newer package versions
flutter pub upgrade --major-versions
flutter analyze                 # static analysis
flutter test                    # run widget tests
```

---

## 9  Contributing

Internal project – contact maintainer before opening PRs.

---

## 10  License

© 2025 Chess4Cash. All rights reserved.
