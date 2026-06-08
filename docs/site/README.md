# GRID_BREAKER — site (privacy + support pages)

Static pages for the App Store **Privacy Policy URL** (required) and **Support URL**
(required). No build step — plain HTML, self-contained.

## ⚠️ Before hosting: set your contact email
Replace `REPLACE_WITH_YOUR_EMAIL` (in `privacy.html` and `support.html`) with the email
you want shown publicly for support.

## Host for free with GitHub Pages
1. Create a public GitHub repo (e.g. `gridbreaker-site`) and put these files in its root.
2. Repo ▸ Settings ▸ Pages ▸ Source: `Deploy from a branch` → `main` / root → Save.
3. After a minute your URLs are live:
   - Privacy: `https://<user>.github.io/gridbreaker-site/privacy.html`
   - Support: `https://<user>.github.io/gridbreaker-site/support.html`
   - (Marketing/root, optional: `https://<user>.github.io/gridbreaker-site/`)
4. Paste the Privacy + Support URLs into App Store Connect (plan steps D3 / D-listing).

Any static host works (Netlify, Cloudflare Pages, your own domain) — just upload the
three HTML files.
