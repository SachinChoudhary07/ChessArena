# ChessArena — Product Documentation (CodeCanyon)

**Version:** 1.0.0  
**Platform:** Flutter (Android-ready; iOS-capable)  
**Backend:** Firebase  
**Product type:** Free skill-based online chess (no wallets, no cash prizes)

Use this document when listing on CodeCanyon, onboarding buyers, or handing off the project to a client.

---

## 1. What is ChessArena?

**ChessArena** is a complete Flutter + Firebase online chess application. Players create accounts, play rated games, challenge friends, join public tournaments or private rooms, climb an Elo leaderboard, and manage their profile — with a modern dark UI inspired by premium chess apps.

It is positioned as **free rated chess** (skill / competition), **not** real-money gaming. Entry fees, wallets, withdrawals, and payment gateways are removed from the active product so buyers have a cleaner path toward Google Play review.

| Item | Value |
|------|--------|
| Display name | ChessArena |
| Motto | Play free. Climb your Elo. |
| Starting Elo | 1200 |
| Bottom navigation | Home · Ratings · History · Friends · Profile |

---

## 2. Feature overview (buyer checklist)

### 2.1 Authentication & account

| Feature | Description |
|---------|-------------|
| Email / password login | Firebase Auth sign-in |
| Google Sign-In | One-tap Google login on the login screen |
| Registration | Email, password, username, skill level, profile photo |
| Phone OTP | OTP verification during signup (configured for `+91` by default — change for your market) |
| Forgot password | Password reset via email |
| Change password | From Profile (re-auth required) |
| Session restore | Splash checks login state and routes to Home or Login |
| Ban handling | If `isBanned` is set on the user doc, the app logs the user out |
| Account deletion | In-app delete + public deletion help webpage (Play requirement) |
| Legal links | Privacy Policy, Terms of Service, Account deletion help (hosted HTTPS URLs) |

### 2.2 Home / dashboard

- Personalized greeting and Elo summary  
- Quick time-control picker: **3 / 5 / 10 / 15 / 30 minutes**  
- **Find match** — rated online matchmaking  
- Shortcuts: **Tournaments**, **Private room**, **Challenge a friend**  
- Double-back-to-exit snackbar on the Home tab  

### 2.3 Online rated matchmaking

1. Player selects a time control and starts matchmaking.  
2. App queues the player in Firestore (`matchmaking_queue`).  
3. Matching prefers similar Elo first, then widens if needed.  
4. When a pair is found, a live `games` document is created.  
5. Both players enter the live board with synchronized clocks.

### 2.4 Challenge a friend

1. Open **Friends** (or Home → Challenge a friend).  
2. Pick an online / listed friend and send a challenge (time control).  
3. Opponent gets an **FCM push notification** + in-app accept/reject dialog.  
4. On accept → waiting room → live game.  
5. Pending challenges **expire after ~2 minutes** if unanswered.  
6. Declined challenges show a dedicated **Challenge declined** screen.

### 2.5 Live gameplay

| Feature | Description |
|---------|-------------|
| Live board | Interactive chessboard; board flipped for Black |
| Clocks | Per-player countdown; synced over Firestore |
| Moves | Legal move generation and validation on device |
| Check | Moves that leave your king in check are blocked |
| Checkmate | Ends the game; winner recorded |
| Stalemate | Ends as a draw-style result |
| Promotion | Pawn promotion picker (Queen / Rook / Bishop / Knight) |
| Castling | Kingside and queenside when legal |
| Resign | Available after both sides have made a move |
| Abort | Available if a side has not yet moved |
| Draw offer | Offer / accept / reject draw via Firestore |
| Timeout | Flag fall → loss for the player out of time |
| In-game chat | Message bar during the game |
| Friend request | Add opponent from the game screen |
| End screen | Result dialog with Elo impact summary |

### 2.6 Chess rules covered (and not covered)

**Implemented**

- Standard piece movement (K, Q, R, B, N, P)  
- Check / checkmate / stalemate  
- Castling (with path and check restrictions)  
- Pawn promotion  
- Resign, abort, draw offer, timeout  

**Not implemented (important for honesty on CodeCanyon)**

- En passant  
- Threefold repetition  
- Fifty-move rule  
- Automatic draw by insufficient material  
- Offline / Stockfish AI opponent (Stockfish is in dependencies but **not wired** into the shipped UI)

### 2.7 Elo & ratings

- New users start at **1200 Elo**.  
- After a decisive game (not a draw/abort), ratings update with a simple delta:  
  - Similar Elo → **±15**  
  - Underdog wins → **±20**  
  - Favorite wins → **±10**  
- **Ratings** tab: podium + full Elo leaderboard.  
- Profile / home show current Elo and games played.

### 2.8 Match history

- Stream of finished games under the user profile.  
- Filters: **All / Wins / Losses**.  
- Stats chips (played / wins / losses).  
- Polished empty state when no games exist yet.

### 2.9 Friends & presence

- Friends list with **online / offline** presence (Realtime Database).  
- Friend requests from live games.  
- Empty state explaining how friendships start (play online → become friends → challenge).  
- Challenge flow from the Friends screen.

### 2.10 Chat moderation

- In-game chat with basic profanity sanitizing.  
- Long-press a message → **Report** or **Block** player.  
- Reports stored in Firestore for admin review.  
- Blocks stored under the user’s `blocked` subcollection.

### 2.11 Tournaments

**Public tournaments** (`tournaments` collection)

- Browse list with filters: All / Upcoming / Ongoing / Completed.  
- **Join** from the list or from **Tournament details → Overview**.  
- Join assigns the player into a free Round 1 bracket slot.  
- View schedule, player count, and matches.  
- **Play Match** when the round window is open and you are seated.

**Private rooms** (`user_tournaments`)

- Create a contest (default 4 players; entry/prize = 0).  
- Share a **6-character room code**.  
- Friends join via **Private room → Join** tab.  
- Same bracket / matches / play flow concept as public events.

### 2.12 Profile

- View / edit username and avatar.  
- Change password.  
- Open Privacy Policy, Terms, Account deletion help (external HTTPS).  
- Log out / delete account.  
- Invite friends (placeholder “Coming Soon”).

### 2.13 App polish

- Custom splash screen and launcher icon.  
- Dark green ChessArena theme (CSS-like color tokens in `ColorResources`).  
- Shimmer placeholders for avatars.  
- Loader components and consistent card UI.  
- Android notification permission + local notification display for FCM foreground messages.

---

## 3. What is intentionally NOT included

These are **removed or unlinked** so the product stays Play-friendly as free skill chess:

- Wallet / add cash / withdraw  
- Entry fees, stakes, cash prizes  
- Razorpay (or any payment gateway)  
- Rake / commission logic  

Orphan / legacy paid screens may still exist in the repo tree but are **not** part of the main navigation. Buyers who need RMG features must implement payments + legal compliance themselves and accept store policy risk.

---

## 4. User journeys (how the app “manages” flow)

### Journey A — First launch → first rated game

```text
Splash → Login / Register (OTP) → Home
  → Pick time control → Find match
  → Matchmaking queue → Game board
  → Play → Game end → Elo update → History
```

### Journey B — Challenge a friend

```text
Friends → Challenge → Opponent notified (FCM)
  → Accept → Waiting room → Game
  → Reject → Challenger sees Declined screen
  → No response → Expired after ~2 minutes
```

### Journey C — Join a public tournament

```text
Home → Tournaments → Upcoming event → Join
  → Details / Matches → Play Match (when time window opens)
  → Tournament waiting room → GameScreen
```

### Journey D — Private room

```text
Home → Private room → Create (get room code) → Share
Friend → Private room → Join (enter code) → Details / Matches
```

---

## 5. Tech stack

| Layer | Technology |
|--------|------------|
| Framework | Flutter (Dart 3.5+) |
| State management | Provider |
| Auth | Firebase Auth, Google Sign-In, Phone Auth |
| Database | Cloud Firestore |
| Presence | Firebase Realtime Database |
| Files | Firebase Storage (profile images) |
| Push | Firebase Cloud Messaging + flutter_local_notifications |
| Chess logic | Custom move engine in `GameProvider` |
| UI helpers | cached_network_image, shimmer, image_picker, share_plus, url_launcher, pinput |

---

## 6. Project structure

```text
lib/
  Constant/          # app name, colors, theme, legal URLs
  Providers/         # auth, game, profile, tournaments, leaderboard
  Screens/           # all UI screens
  Services/          # challenges, moderation, presence, tournament join, FCM helpers
  Widgets/           # shared premium UI
  Firebase/          # FCM access-token helper (+ local serverKey.json)
  splash_screen.dart
  main.dart
legal/               # privacy, terms, delete-account HTML (Netlify-ready)
firestore.rules
storage.rules
PLAY_STORE_DATA_SAFETY.md
README.md
DOCUMENTATION.md     # this file
```

---

## 7. Firebase data model (high level)

| Collection / path | Purpose |
|-------------------|---------|
| `users` | Profile, Elo, stats, FCM token, ban flags |
| `users/{uid}/friends` | Friend list |
| `users/{uid}/blocked` | Blocked players |
| `users/{uid}/gamehistory` | Finished games |
| `games` | Live 1v1 games (board, clocks, chat, status) |
| `matchmaking_queue` | Rated queue |
| `challenges` | Friend challenges |
| `friend_requests` | In-game friend requests |
| `tournaments` + `matches` | Public brackets |
| `user_tournaments` + `matches` | Private rooms |
| `reports` | Chat / player reports |
| RTDB `status/{uid}` | Online / offline presence |

---

## 8. Setup for buyers (summary)

1. Create your **own Firebase project** (Auth, Firestore, RTDB, Storage, Messaging).  
2. Add `google-services.json` (Android) and iOS plist if needed.  
3. Replace Firebase options / project IDs in the app.  
4. Deploy `firestore.rules` and `storage.rules`.  
5. Host `/legal` pages and set URLs in `lib/Constant/legal_urls.dart`.  
6. Add your own FCM service account as `lib/Firebase/serverKey.json` (gitignored; **never ship the seller’s key**). Prefer moving FCM sends to Cloud Functions for production.  
7. Update branding: app name, package id, icon, colors.  
8. Configure release signing (`key.properties` + keystore).  
9. Run:

```bash
flutter pub get
flutter run
```

Full setup notes also live in `README.md`.

---

## 9. Google Play notes

- Product type: **free skill chess** (no cash).  
- Provide Privacy Policy + Account deletion URLs before submission.  
- Use `PLAY_STORE_DATA_SAFETY.md` when filling Data Safety.  
- Change `applicationId` if you need a unique listing identity.  
- Content rating / 18+ checkbox: keep consistent with your store answers.  
- Client-side FCM service account is convenient for demos; **harden before production scale**.

---

## 10. Customization ideas (upsell for freelancers)

- Full white-label (colors, fonts, icon, splash)  
- Offline Stockfish bot / puzzles (engine already in deps)  
- En passant + advanced draw rules  
- Multi-language  
- Admin panel for reports, bans, tournament seeding  
- AdMob or subscription monetization  
- Cloud Functions for secure Elo + FCM  
- iOS polish + App Store assets  

---

## 11. Screens buyers should screenshot for the listing

1. Splash / Login / Register  
2. Home (time controls + find match)  
3. Matchmaking  
4. Live game (board + clocks + chat)  
5. Ratings / leaderboard  
6. History  
7. Friends + challenge  
8. Tournaments list + details (Join)  
9. Private room create/join  
10. Profile + legal links  

---

## 12. Support / delivery checklist

When you deliver this product, include:

- [ ] Full Flutter source  
- [ ] This documentation + README  
- [ ] Legal HTML templates  
- [ ] Firestore & Storage rules  
- [ ] Data Safety notes  
- [ ] Clear note: buyer must create their own Firebase + keys  
- [ ] Optional: sample screenshots and demo APK  

---

## Disclaimer

ChessArena is delivered as **source code**. The buyer is responsible for Firebase configuration, store policies, privacy compliance, and local laws in their target markets. Real-money gaming features are intentionally out of scope of the shipped product.

---

**Brand:** ChessArena  
**Stack:** Flutter + Firebase + Provider  
**Category suggestion (CodeCanyon):** Mobile → Flutter → Games / Social / Sports
