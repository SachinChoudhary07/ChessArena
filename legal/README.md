# Legal pages

Host these files on HTTPS before Play submission:

- `privacy-policy.html`
- `delete-account.html`

Then set the same URLs in:

- Play Console → App content → Privacy policy
- Play Console → App content → Account deletion
- `lib/Constant/legal_urls.dart`

Firebase Hosting example:

```
firebase deploy --only hosting
```

Also deploy `firestore.rules` and `storage.rules` from the repo root.
