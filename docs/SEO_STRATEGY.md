# QuestKids — SEO Hardening & Backlink Strategy

Written 2026-09-17, covers the technical SEO pass on the Flutter web build
plus the off-page backlink plan. Read the "Constraint" section first — it
changes what several of these checklist items actually mean for this app.

## The core constraint

QuestKids' web target (`web/`) is a Flutter web app, not a traditional
multi-page website. It renders into a `<canvas>` (CanvasKit) and uses classic
`Navigator` routing (not `go_router`), so there is exactly **one** crawlable
URL — there's no second page for Google to find, and no real DOM text for it
to read once the app takes over.

This is why Google wasn't indexing it — it's not a missing-tags problem, it's
architectural. The fix applied here (`web/index.html`, `#seo-content`) embeds
real, static, semantic HTML — an `<h1>`, section headings, descriptive text,
and an `<img alt>` — that's visible in the initial page load and only hidden
once Flutter's `flutter-first-frame` event fires. Crawlers and no-JS clients
see real content; real visitors see a branded loading screen that becomes the
app. This is the standard workaround for Flutter-web SEO.

## What was changed

| Item | Status |
|---|---|
| `web/robots.txt` | Added — allows all, points at sitemap |
| `web/sitemap.xml` | Added — single URL (see constraint above) |
| noindex tags | None existed — nothing to remove |
| Canonical tag | Added to `web/index.html` |
| Meta title | Rewritten, keyword-relevant, was just "questkids" |
| Meta description | Rewritten, was generic ("EdTech Learning Platform") |
| Viewport meta tag | **Was missing entirely** — added. This alone likely hurt mobile usability/indexing; Google uses mobile-first indexing. |
| H1 / heading hierarchy | Added via the `#seo-content` shell (h1 → h2) |
| Alt text | Added on the logo image in the shell |
| Schema markup | Added `SoftwareApplication` JSON-LD |
| OG image | Generated at `web/og-image.jpg` (1200x630, logo on brand background, 57KB) |
| OG / Twitter Card tags | Added |
| Internal links | N/A — single-URL SPA, nothing to link between yet |
| Broken links | Checked README/docs — none found. Nothing live to crawl yet. |
| Image compression | `assets/questkids_logo.png` + app icons: ~3.6MB → ~0.6MB combined, no visible quality loss (verified visually) |
| HTTPS | Already enforced automatically by Vercel — nothing to configure |
| URL slugs | N/A — no per-screen URLs exist (see below) |
| Mobile responsiveness | Not independently audited this pass — see Open Items |
| Core Web Vitals | Viewport fix + image compression help; renderer-level change (below) needs testing before adopting |

**Placeholder domain:** every new tag uses `https://questkids.vercel.app/` as
a placeholder. Once the real production URL exists, replace it in
`web/index.html` (canonical, OG, JSON-LD), `web/robots.txt`, and
`web/sitemap.xml` — grep for `questkids.vercel.app` to find every instance.

## Open items — need a decision or can't be verified here

1. **Custom domain.** Still none. Search Console verification, canonical
   URLs, and any backlinks below should ultimately point at a domain you'll
   keep — a `*.vercel.app` URL works today but backlinks built against it
   won't fully carry over if you move to a custom domain later.
2. **`go_router` migration.** Without it, screens have no real URLs, so
   "internal links" and "clean URL slugs" have nothing to attach to. This is
   a real architecture change, not a tag — flagging it, not doing it
   unprompted.
3. **`flutter build web --wasm`.** Would likely improve load performance
   (Core Web Vitals), but some Firebase/JS-interop plugins may not yet be
   wasm-compatible. I did not apply this to `vercel.json` — it needs a real
   test build before adopting, which needs the actual Flutter SDK running
   somewhere I can verify output.
4. **Mobile responsiveness audit.** Needs the app actually running in a
   browser at phone width to check properly rather than guessing from code.

## Search Console verification (needs your Google login — I can't do this part)

1. Go to https://search.google.com/search-console
2. Add a property using **URL prefix** with your live URL (the `*.vercel.app`
   one for now).
3. Choose the **HTML tag** verification method. Google gives you a
   `<meta name="google-site-verification" content="...">` tag.
4. Send me that exact tag (or add it yourself) into `web/index.html`'s
   `<head>`, anywhere above `</head>`.
5. Deploy, then click Verify in Search Console.
6. Once verified, submit `sitemap.xml` under Search Console → Sitemaps.

## Backlink strategy

QuestKids' audience is South African parents of Grade 1-7 kids. Backlinks
should come from places that audience — or Google — already trusts:

**Direct / high-intent**
- Google Play Store listing (once published) — Play Store pages are
  themselves heavily crawled and cross-linked, and the listing can link back
  to the site.
- Product Hunt / BetaList launch — cheap, fast, gets an initial batch of
  real referring domains and some launch-day traffic.

**South African EdTech & parenting**
- Local parenting blogs and Facebook parenting groups (SA-specific, e.g.
  provincial parenting communities) — outreach/guest post offering a free
  trial or review copy.
- Teacher communities (SA teacher Facebook groups, CAPS resource forums) as
  a *distribution* channel — a teacher recommending QuestKids to parents is
  still valuable word-of-mouth even though the app itself no longer has a
  teacher-facing dashboard (that role was removed in favor of an internal
  admin role, commit `d64e46d`, 2026-09-14) — don't pitch it to teachers as
  a classroom tool, pitch it as something to recommend to parents.
- EdTech directories: Common Sense Education, EdSurge product directory,
  Capterra/GetApp (EdTech category) — free or low-cost listings, decent
  domain authority.

**Institutional / PR**
- Since this is solo-developed by a student: your university's
  innovation/entrepreneurship or CS department page is a legitimate, easy
  backlink (`.ac.za` domains carry real authority) if they have a student
  projects/showcase page.
- Local tech press (e.g. MyBroadband, Ventureburn, ITWeb) — a short pitch
  about a CAPS-aligned EdTech app from a solo SA developer is a realistic
  story angle for these outlets.
- School pilot partnerships: if any school agrees to trial QuestKids, ask for
  a mention/link on the school's own site (many SA schools have a "resources"
  or "news" page).

**Owned profiles (low effort, do these regardless)**
- Create/claim QuestKids profiles on Facebook, Instagram, LinkedIn (and
  YouTube if you ever post a demo video) — these are indexed, linkable, and
  reinforce the brand name in search results even before backlinks accrue.

None of the backlink items above are things I can execute — they're outreach
and require your voice/judgment. Happy to draft the actual outreach email or
Play Store copy if useful.
