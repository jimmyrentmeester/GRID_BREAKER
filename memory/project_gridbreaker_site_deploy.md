---
name: project_gridbreaker_site_deploy
description: "GRID_BREAKER landing page deploys from a SEPARATE hub repo, not from GRID_BREAKER itself."
metadata: 
  node_type: memory
  type: project
  originSessionId: e15ba1d2-cd47-43d7-b56b-07356ba78cbb
---

The GRID_BREAKER landing page (https://jimmyrentmeester.github.io/gridbreaker/) is
served from a **separate hub repo** `jimmyrentmeester/jimmyrentmeester.github.io`
(a GitHub Pages user site), where each app lives in its own subfolder
(`gridbreaker/`). GitHub Pages is NOT enabled on the `GRID_BREAKER` repo at all.

`GRID_BREAKER/docs/site/` is only the **source/staging copy** — editing and pushing
it there does NOT update the live site. You must sync it into the hub repo and push
that. Run `scripts/deploy_site.sh` (added 2026-06-27) which clones/updates the hub
into `~/jimmyrentmeester.github.io`, rsyncs `docs/site/` → `gridbreaker/`, commits,
pushes, and waits for the Pages build.

**Why:** I once edited+pushed only `docs/site/` and reported the site live; the user
still saw the old version because the hub repo was never updated.
**How to apply:** any landing-page change = run `deploy_site.sh` (or sync to the hub
repo) to actually go live. Also note: the git account in this environment is a
collaborator (`k6czwyxg8g-cmyk`), so it can push but the Pages API 404s on repos
where it lacks admin. After deploy, hard-refresh — Pages + browser cache ~10 min.
