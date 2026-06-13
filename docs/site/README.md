# GRID_BREAKER — site (privacy + support pages)

Static pages for the App Store **Privacy Policy URL** (required) and **Support URL**
(required). No build step — plain HTML, self-contained.

## ✅ LIVE (hosted on GitHub Pages)
These files are the source of truth; they are deployed to the **user-site repo**
`k6czwyxg8g-cmyk/k6czwyxg8g-cmyk.github.io`, each app in its own subfolder:
- Privacy: https://k6czwyxg8g-cmyk.github.io/gridbreaker/privacy.html
- Support: https://k6czwyxg8g-cmyk.github.io/gridbreaker/support.html
- Hub: https://k6czwyxg8g-cmyk.github.io/

The contact email (`jimmy.rentmeester@gmail.com`) is already set in `privacy.html`
and `support.html`.

## Updating the live pages
Edit the files here (source of truth), then copy into the site repo's `gridbreaker/`
folder and push:
```
cp privacy.html support.html index.html <site-repo>/gridbreaker/
git -C <site-repo> add -A && git -C <site-repo> commit -m "update" && git -C <site-repo> push
```
Pages redeploys in ~1 min.

## Adding a future app
Add a new subfolder in that same repo (e.g. `/nextapp/privacy.html`) and link it from
the hub `index.html`. No new repo or Pages setup needed — that's why we used the
`<user>.github.io` user-site repo instead of a per-app repo.

Any static host works too (Netlify, Cloudflare Pages, a custom domain) — just upload
the HTML files.
