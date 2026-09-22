# Play Console — Data safety form (ChessArena)

Use this when filling **App content → Data safety**. ChessArena is a **free chess game**. It does **not** collect financial or purchase data.

Host `legal/privacy-policy.html` and `legal/delete-account.html` on HTTPS, then put those URLs in Play Console and in `lib/Constant/legal_urls.dart`.

## Does your app collect or share user data?

**Yes** — required for accounts and online play.

## Data collected (app-collected, account-required)

| Data type | Collected | Shared | Purpose | Optional? |
| --- | --- | --- | --- | --- |
| Name / username | Yes | No (only shown to other players in-app) | App functionality | No |
| Email | Yes | No (Firebase Auth) | Account | No |
| Phone number | Yes | No (Firebase OTP) | Account | No |
| User photos (profile) | Yes if uploaded | No (stored in Firebase Storage, visible to opponents) | App functionality | Yes |
| User IDs | Yes | No | Account / gameplay | No |
| Gameplay / in-app chat | Yes | No (other players in the same match can see chat) | App functionality, abuse reports | Chat is optional |
| Device or other IDs (FCM token) | Yes | No | Notifications / security | No |

## Data NOT collected

- Approximate or precise location  
- Financial info, payment info, purchase history, credit score  
- Health, contacts, calendar, SMS (SMS permissions were removed)  
- Web browsing, clipboard (beyond OS)

## Security

- Data is encrypted in transit (HTTPS / Firebase).  
- Users can request deletion (in-app + public webpage).

## Target audience

- Not designed for children.  
- Registration requires 18+ confirmation (keep this consistent with Play rating).

## Privacy policy

Must be a **public URL**. Deploy the files in `/legal` (Firebase Hosting, GitHub Pages, or your domain).
