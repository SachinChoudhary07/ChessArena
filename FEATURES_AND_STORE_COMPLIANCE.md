# Chess4Cash — Feature Inventory and Store / Legal Review Notes

**Purpose of this document:** list every product feature found in the current codebase so you can decide whether the app is ready to publish, and whether it looks like a betting / real-money gaming product.

**This is not legal advice.** Store policy and Indian (or other country) law change often. Before publishing, talk to a lawyer who handles gaming / payments, and read Google Play’s current gambling and real-money gaming rules for each country you want to ship in.

---

## 1. What this app is, in one sentence

**Chess4Cash is a live online chess app where players can play for free or stake wallet money (entry fee) and win a cash prize after the platform takes a cut.**

The product name, wallet, paid matches, tournaments, friend challenges with an amount, Razorpay deposits, and UPI withdrawals are all part of the same real-money loop.

---

## 2. Is this a betting / gambling-style mobile app?

**Functionally: yes, it is a real-money staking product built around chess, not a casual free chess app.**

| Question | What the code does |
| --- | --- |
| Can users play without money? | Yes — free rated matchmaking exists. |
| Can users put money at risk on a game? | Yes — paid matches, paid contests, paid friend challenges, paid tournaments. |
| Do winners get cash in-app? | Yes — prize is credited to the in-app `Balance` (typically **82% of the prize pool**; **18% kept as admin commission / rake**). |
| Can users add real money? | Yes — Razorpay checkout (UPI, cards, netbanking, wallets). Currently a **test** Razorpay key is in the client. |
| Can users take money out? | Yes — withdrawal request with UPI ID; status is stored as `pending` (manual / backend processing implied). |
| Is there an age gate? | Registration checkbox: **“I am 18+ years old.”** There is no government ID / KYC flow in the app. |
| Is the outcome based on skill? | Chess is generally treated as a **game of skill**, not a slot/roulette game of chance. That does **not** automatically make real-money chess legal everywhere or allowed on Play Store. |

**Google Play often treats “real money wagered on an outcome” as gambling / real-money gaming**, even if the game is skill-based. Chess.com-style *free* play is a different category from *stake ₹X, winner takes the pool minus rake*.

So for store and government review:

- **Casual chess only:** not this app’s full product.
- **Real-money skill gaming / staking:** this is what Chess4Cash implements.
- **Casino / sportsbook / betting odds:** the app does not offer sports bets, roulette, or slots. It still lets two (or more) players put money on who wins a chess game.

---

## 3. Does “the government” allow this?

**There is no single worldwide “yes.”** You must decide **country + states + licence + tax**.

### India (relevant because the UI uses ₹, UPI, Razorpay)

High-level picture (verify with counsel; this is a snapshot, not a ruling):

- **Chess is usually argued as a game of skill**, not chance.
- **Several Indian states restrict or ban real-money online games** (rules differ by state: some ban all RMG, some ban only games of chance).
- **National / GST treatment of online real-money gaming has been tightening** (high GST on RMG in recent years). Operators typically need proper company structure, GST, payment-aggregator compliance, and sometimes state-by-state geo-blocking.
- **A self-declared 18+ checkbox is not the same as KYC** (PAN, Aadhaar, bank verification) that many payment and gaming regulators expect for cash-out products.
- **Razorpay / banks / UPI** may refuse or restrict merchant categories that look like betting.

**You should not assume “skill game = automatically allowed in all of India.”** Many Play Store listings for similar products are rejected, geo-restricted, or require a gambling licence in the target country.

### Other countries

- US, UK, EU, etc. treat paid contests, pools, and rake very differently. Some need a **gambling licence**; some ban it for Android consumers entirely.

### Practical recommendation

Treat this as **real-money gaming (RMG)**, not a hobby chess app, until a lawyer and Google Play’s gambling policy say otherwise for your target countries.

---

## 4. Google Play publish checklist (product vs policy)

Things in **this codebase** that typically trigger extra Play review:

1. **Real-money wallet** (deposit + withdraw).
2. **Entry fees and cash prizes** on matches / contests / tournaments / friend challenges.
3. **Platform rake (18%)**.
4. **UPI / cards via Razorpay**.
5. **18+ only** (you must also set Play Console content rating and target age correctly).
6. **Push notifications** for challenges.
7. **User-generated content:** chat during games, usernames, profile photos.

Google Play typically requires, among other things:

- Accurate **Data safety** form (Firebase Auth, Firestore, Storage, FCM, payments, photos).
- **Privacy policy URL** (the app has an in-app Privacy Policy page; you still need a hosted public URL).
- **Account deletion** (the app has Delete Account).
- Clear disclosure if the app is **gambling / real-money**.
- In many countries: **gambling licence documents** or **the listing is not allowed**.

Also **not store-ready yet** from an engineering/compliance view (found in code):

- Razorpay **test** key (`rzp_test_...`) in the client.
- Hardcoded Firebase options in `main.dart`.
- Placeholder payment prefill (`9876543210`, `user@example.com`).
- Invite Friends shows **“Coming Soon”**.
- Withdrawals are **pending records**, not an automated payout pipeline visible in the app.
- No obvious geo-blocking of banned Indian states.
- No KYC before withdraw.

---

## 5. Complete feature list (from the current project)

### 5.1 Accounts and access

- Email + password **login**.
- **Registration:** username, email, phone, password, profile photo (gallery), skill level (Beginner / Intermediate / Expert).
- **Phone OTP** verification during signup (Firebase phone auth).
- Age confirmation: **18+**.
- Privacy Policy and Terms checkbox (opens in-app Privacy Policy page).
- **Forgot password** (email reset).
- **Change password** (logged-in).
- **Logout**.
- **Delete account**.
- **Ban / suspend:** if Firestore `isBanned` is true, user is logged out and shown a ban dialog (reason field exists).
- Splash: restore session via SharedPreferences `isLoggedIn` + Firebase user; skip dashboard if banned.
- Online **presence** service after login.

Google Sign-In exists in dependencies / commented UI; **in-app Google button is currently commented out**.

### 5.2 Home / dashboard

- Player name, rating (Elo), wallet balance.
- Time controls for free play (home: 3 / 5 / 10 / 15 / 30 min).
- **Find an opponent** → free rated matchmaking.
- Shortcuts: Paid match, Friends challenge, Tournaments, Create/Join room.

Bottom navigation: **Home, Wallet, History, Friends, Profile**.

### 5.3 Chess gameplay (skill)

- Live two-player chess (custom board, not only a packaged widget).
- Time controls / clocks; timeout can decide the game.
- Check, checkmate, stalemate, draw offer / accept / reject.
- Resign, abort (early, if few/no moves), leave handling.
- Pawn promotion picker.
- Board flipped for Black.
- In-game **chat**.
- Friend request from the game screen.
- Game end dialog: result, prize, Elo change explanation.
- Elo updates (e.g. ±10 / ±15 / ±20 depending on rating difference).
- Stockfish is in `pubspec.yaml` (engine dependency); the main published flow in screens is **human vs human online**.

### 5.4 Free matchmaking

- Queue in Firestore `matchmaking_queue`.
- Phase 1: prefer similar Elo (~first 15 seconds).
- Phase 2: wider / any opponent.
- Wait timer, empty-queue message, auto-return home after countdown.
- Creates a `games` document and opens the game screen.

### 5.5 Paid 1v1 / paid contest

- Browse or create paid games with **entry fee** (example amounts in UI such as ₹100).
- Wallet balance check; insufficient-funds dialog.
- Prize pool shown after **18% admin cut**.
- Paid matchmaking / join existing paid table.
- Winner wallet credit after commission.

### 5.6 Tournaments and private contests

- Public **tournament list**.
- Tournament details, waiting room, matches under a tournament.
- **Create contest / tournament** (room code, share via `share_plus`).
- **Join by room code**.
- Entry fees and prizes can apply; tournament winner credit also applies **18% admin deduction** in game provider logic.

### 5.7 Friends and challenges

- Friends list with **online / offline**.
- Challenge online friends from Friends tab.
- **Play with Friends:** pick friend, time control, **stake amount (₹0 / 10 / 20 / 50 / 100)**, send challenge.
- Push notification + in-app Accept / Reject dialog.
- Challenge expiry service.
- Challenge waiting room and challenge history.

₹0 challenges are “play for honour”; non-zero amounts are **real-money stakes** between friends.

### 5.8 Wallet and money movement

- Display **Total Balance**.
- **Add cash** via Razorpay (amounts via keypad or chips 50–5000).
- On payment success: increase `Balance`, write `transactions` (`type: deposit`, `status: success`).
- **Withdraw:** amount + UPI ID; writes `type: withdrawal`, `status: pending`.
- Transaction history stream (date, deposit/withdrawal, amount, status).

This is the core of why stores and regulators will not treat the app as “just chess.”

### 5.9 Profile, rating, history

- View/edit username, email (read-only), profile image (crop/upload).
- **Elo leaderboard**.
- Match **history** (opponent, result, prize).
- Invite Friends: **Coming Soon** snackbar.

### 5.10 Chat, notifications, media

- Firebase Cloud Messaging + local notifications.
- Challenge notifications.
- In-game chat messages.
- Profile images via Firebase Storage + cached network images.
- Image picker / cropper.

### 5.11 Safety / admin-oriented fields (backend-shaped)

User documents include fields such as: Elo, games played/won/lost/drawn, ranking, Balance, `isBanned`, `banReason`, `isVerified`, `suspiciousFlag`, FCM token, device info.

The **mobile app** enforces ban on login/session. Full admin dashboard is not in this Flutter client.

### 5.12 Tech stack (for reviewers)

- Flutter (Android / iOS / desktop folders present).
- Firebase: Auth, Firestore, Storage, Messaging, Database, App Check (commented).
- Provider state management.
- Razorpay Flutter plugin.
- Permissions: typical camera/gallery/notifications (via packages).

---

## 6. Feature map vs “can I ship on Play Store?”

| Mode | Money | Typical Play Store difficulty |
| --- | --- | --- |
| Free rated match only | No | Similar to a normal chess app (still need privacy, ratings, data safety). |
| Friends challenge with ₹0 | No | Usually OK if no deposits. |
| Paid match / contest / tournament / ₹ challenge | Yes | **High risk of rejection** unless you meet gambling/RMG rules for that country. |
| Wallet add + withdraw | Yes | Treated as **real-money**; payments + possibly gambling policy. |

**If you want a straightforward Play Store chess app:** ship a build with wallet, paid entry, prizes, and withdrawals **removed or fully disabled**, and only free play.

**If you want to ship Chess4Cash as it works today:** budget for legal review, possible licences, geo-blocking, KYC, production payments, tax, and a high chance Google classifies it as **real-money gambling/gaming**.

---

## 7. Suggested questions to ask a lawyer / Play Console review

1. In each Indian state I serve, is **real-money online chess with rake** allowed?
2. Do I need a **gaming / betting licence**, GST registration as RMG, or both?
3. Must I **geo-block** banned states and minors?
4. Does Google Play in **India** (or my target country) allow this listing **without** a gambling licence document?
5. Are **Razorpay + UPI payouts** allowed for this merchant category?
6. Is an **18+ checkbox** enough, or is **KYC before deposit/withdraw** required?
7. How must I disclose **rake (18%)**, odds of winning, and that this is **not a guaranteed income product**?

---

## 8. Short answers to your three questions

1. **What features exist?**  
   Full online chess plus friends, tournaments, rooms, Elo, history, chat, notifications, **and a complete cash wallet (add money, stake, win prize minus 18%, withdraw via UPI).** See section 5.

2. **Is it a kind of betting mobile application?**  
   It is **real-money staking on chess results** (skill-based contest with a house commission). It is **not** a sportsbook, but it **is** a cash-contest / RMG product, not a free puzzle app.

3. **Does the government allow it?**  
   **Not automatically.** Legality depends on **country and (in India) state**, tax, and licences. **Do not publish based on this file alone.** Get qualified legal advice for every market you target.

---

*Generated from the Chess4Cash Flutter codebase as it exists in this repository. If you later remove wallet/paid modes, update this document so it matches the build you actually submit.*
