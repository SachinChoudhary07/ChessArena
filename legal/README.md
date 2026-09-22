# Legal pages

Hosted on Netlify: https://chessarena-legal.netlify.app

## Live links (Play Console + app)

| Page | URL |
|------|-----|
| Privacy Policy | https://chessarena-legal.netlify.app/privacy-policy.html |
| Account Deletion | https://chessarena-legal.netlify.app/delete-account.html |
| Terms of Service | https://chessarena-legal.netlify.app/terms.html |

App wires these via `lib/Constant/legal_urls.dart` (Profile + Register).

## Local files

- `index.html`
- `privacy-policy.html`
- `delete-account.html`
- `terms.html`
- `styles.css`
- `netlify.toml`

## Redeploy

```bash
# zip the HTML/CSS/toml and upload via Netlify UI, or:
# netlify deploy --prod --dir=. --site=chessarena-legal
```

After changing pages, keep `LegalUrls` and Play Console in sync.
