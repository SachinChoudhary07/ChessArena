# ChessArena

**Premium online chess app** built with Flutter + Firebase.  
Play rated matches, challenge friends, join tournaments, and climb the Elo leaderboard — **no wallets, no stakes, no cash prizes**.

Designed as a **Play Store–ready** skill chess product with a modern dark UI, ready for freelancers and studios to white-label, customize, and ship.

---

## Why buy / use this project?

- Clean **Chess.com-inspired** dark green UI (not a generic template look)
- Full **multiplayer online chess** flow already wired to Firebase
- **Real-money features removed** — safer path for Google Play submission
- Includes legal page templates, Firestore/Storage rules, and Data Safety notes
- Easy to rebrand (name, icon, colors, Firebase project)

Ideal for: Play Store launch, client delivery, portfolio demo, or white-label sale.

---

## Core features

### Play
- Rated online matchmaking with multiple time controls (3 / 5 / 10 / 15 / 30 min)
- Live chess board with clocks, moves, check detection, resign / abort flows
- Game end screen with Elo change summary

### Social
- Friends list with online / offline presence
- Challenge a friend to a rated game
- In-game chat with **report** and **block** moderation

### Events
- Public **tournaments** (bracket events)
- **Private rooms** — create / join with a room code and share
- Tournament overview + match brackets

### Progress
- Elo rating system
- Elo leaderboard (podium + ranked list)
- Match history with win / loss filters and stats

### Account
- Email/password auth + Google Sign-In
- Register flow with OTP, profile photo, skill level
- Profile edit, change password, logout, account deletion help
- Public privacy policy + account deletion webpages (templates included)

### App quality
- Custom splash screen + branded launcher icon
- Double-back-to-exit with snackbar
- Shimmer loading for profile avatars
- Bottom navigation: Home · Ratings · History · Friends · Profile

---

## What’s intentionally NOT included (Play Store friendly)

- No wallet / add cash / withdraw
- No entry fees, stakes, or cash prizes
- No payment gateway (Razorpay removed)
- No rake / commission logic

This keeps the product positioned as **free skill chess**, not real-money gaming.

---

## Tech stack

| Layer | Technology |
|--------|------------|
| Framework | Flutter (Dart 3.5+) |
| State | Provider |
| Auth | Firebase Auth, Google Sign-In |
| Database | Cloud Firestore, Firebase Realtime Database |
| Storage | Firebase Storage |
| Push | Firebase Messaging + local notifications |
| Chess logic | Bishop / Squares / flutter_chess_board |
| Engine | Stockfish (available in project) |
| Other | cached_network_image, image_picker, share_plus, url_launcher, shimmer |

---

## Project structure (high level)

```text
lib/
  Constant/          # theme, colors, app constants, legal URLs
  Providers/         # auth, game, profile, tournaments, leaderboard
  Screens/           # UI screens (home, game, friends, tournaments, auth…)
  Services/          # challenges, notifications, moderation, presence
  Widgets/           # shared premium UI components
  splash_screen.dart
  main.dart
legal/               # privacy-policy.html, delete-account.html
firestore.rules
storage.rules
PLAY_STORE_DATA_SAFETY.md
```

---

## Getting started

### Prerequisites
- Flutter SDK ≥ 3.24
- Android Studio / Xcode
- A Firebase project (Auth, Firestore, RTDB, Storage, Messaging)

### Setup
1. Clone the repo and open it in your IDE.
2. Create your own Firebase project and download:
   - `android/app/google-services.json`
   - iOS `GoogleService-Info.plist` (if shipping iOS)
3. **Do not commit secrets.** Use your own service account / FCM keys locally.
4. Update branding if needed:
   - App name: `lib/Constant/app_constant.dart`
   - Legal URLs: `lib/Constant/legal_urls.dart`
   - Icon: `assets/Icons/app_icon.png` → run `dart run flutter_launcher_icons`
5. Install & run:

```bash
flutter pub get
flutter run
```

### Deploy Firebase rules

```bash
firebase deploy --only firestore:rules,storage
```

### Host legal pages
Upload files from `/legal` to your domain and point Play Console + `LegalUrls` to them.

---

## Play Store notes

- Display name: **ChessArena**
- Package id in this repo may still be the original Android applicationId — change before publishing if you want a new listing identity.
- Use `PLAY_STORE_DATA_SAFETY.md` when filling Google Play Data Safety.
- Host privacy policy + account deletion URLs before submission.

---

## What you can sell / customize for clients

- Rebrand colors, fonts, icon, splash
- Add ads (AdMob) or premium subscription
- Add puzzles / bots / lessons on top of the engine
- Multi-language support
- Admin panel for reports / bans / tournaments
- iOS polish + App Store listing pack

---

## Screenshots

> Add your device screenshots here before listing on a freelancing marketplace  
> (Home, Matchmaking, Gameplay, Ratings, Tournaments, Profile, Login/Register)

---

## License / delivery

Delivered as source code for the buyer’s use.  
Replace Firebase credentials and legal URLs before production release.  
You are responsible for store policies, privacy compliance, and local laws in your target markets.

---

## Support for buyers

After purchase, typical handover includes:
1. Source code access
2. Setup steps (this README)
3. Firebase collections overview
4. How to change branding + icon

---

**ChessArena** — Play free. Climb your Elo.
