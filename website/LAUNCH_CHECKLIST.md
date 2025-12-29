# Launch Checklist for fluvie.dev

Use this checklist to ensure a smooth deployment of the Fluvie marketing website.

## Pre-Deployment (Local Testing)

- [ ] **Test locally**
  ```bash
  cd website
  python3 -m http.server 8000
  # Visit http://localhost:8000
  ```

- [ ] **Verify all pages/sections**
  - [ ] Hero section loads with badges and buttons
  - [ ] All feature cards render correctly
  - [ ] Code playground (Monaco Editor) initializes
  - [ ] All code examples load from dropdown
  - [ ] Template gallery images display
  - [ ] All links work (internal anchor + external)
  - [ ] Mobile navigation toggle works
  - [ ] Footer links correct

- [ ] **Browser Testing**
  - [ ] Chrome/Edge (latest)
  - [ ] Firefox (latest)
  - [ ] Safari (latest)
  - [ ] Mobile Safari (iOS)
  - [ ] Mobile Chrome (Android)

- [ ] **Responsive Design**
  - [ ] Test at 375px (mobile)
  - [ ] Test at 768px (tablet)
  - [ ] Test at 1024px (laptop)
  - [ ] Test at 1920px (desktop)

- [ ] **Console Errors**
  - [ ] No JavaScript errors in console
  - [ ] No 404 errors for assets
  - [ ] Monaco Editor loads without errors

## Commit & Push

- [ ] **Git status clean**
  ```bash
  git status
  # Ensure all files are tracked
  ```

- [ ] **Add all files**
  ```bash
  git add docs/
  git add README.md CHANGELOG.md
  ```

- [ ] **Commit**
  ```bash
  git commit -m "Add professional marketing website at fluvie.dev

  - Single-page responsive design with 12 sections
  - Interactive Monaco Editor code playground
  - Feature showcase and template gallery
  - SEO-optimized with Schema.org, Open Graph
  - Mobile-first glassmorphic UI
  - Deployment guide and documentation

  🤖 Generated with Claude Code

  Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
  ```

- [ ] **Push to GitHub**
  ```bash
  git push origin main
  ```

## GitHub Pages Configuration

- [ ] **Enable GitHub Pages**
  1. Go to repository Settings → Pages
  2. Source: Branch `main`, folder `/website`
  3. Save

- [ ] **Verify default URL**
  - Visit: https://simonerich.github.io/fluvie/
  - Ensure site loads correctly

- [ ] **Configure custom domain**
  1. In Settings → Pages
  2. Custom domain: `fluvie.dev`
  3. Save
  4. Wait for DNS check

## DNS Configuration

- [ ] **Add DNS Records** (in your DNS provider)

  **A Records** (for apex domain):
  ```
  Type: A
  Name: @
  Value: 185.199.108.153

  Repeat for:
  - 185.199.109.153
  - 185.199.110.153
  - 185.199.111.153
  ```

  **CNAME Record** (for www subdomain):
  ```
  Type: CNAME
  Name: www
  Value: simonerich.github.io
  ```

- [ ] **Wait for DNS Propagation**
  - Check: https://dnschecker.org/#A/fluvie.dev
  - May take 10 minutes to 48 hours

## Post-Deployment Verification

- [ ] **Test Custom Domain**
  - [ ] http://fluvie.dev loads
  - [ ] http://www.fluvie.dev redirects to fluvie.dev
  - [ ] All assets load (no mixed content errors)

- [ ] **Enable HTTPS**
  - [ ] In Settings → Pages, check "Enforce HTTPS"
  - [ ] Wait for certificate provisioning (1-5 minutes)
  - [ ] Verify https://fluvie.dev works

- [ ] **Final Checks**
  - [ ] All images load correctly
  - [ ] Monaco Editor works on live site
  - [ ] All external links open in new tabs
  - [ ] Mobile navigation works on real devices
  - [ ] No console errors on production

## Quality Assurance

- [ ] **Run Lighthouse Audit** (in Chrome DevTools)
  - Target scores:
    - Performance: 95+
    - SEO: 100
    - Accessibility: 95+
    - Best Practices: 95+

- [ ] **PageSpeed Insights**
  - Visit: https://pagespeed.web.dev/
  - Analyze: https://fluvie.dev
  - Check both mobile and desktop scores

- [ ] **Validate HTML**
  - Visit: https://validator.w3.org/
  - Check: https://fluvie.dev
  - Fix any errors/warnings

- [ ] **Social Media Preview**
  - Test Open Graph: https://www.opengraph.xyz/
  - Test Twitter Card: https://cards-dev.twitter.com/validator
  - Ensure og-image.png loads correctly

## Assets TODO (Optional Enhancements)

- [ ] **Generate Proper Favicons** (replace SVG placeholders)
  ```bash
  cd website/assets/images
  convert favicon.svg -resize 16x16 favicon/favicon-16x16.png
  convert favicon.svg -resize 32x32 favicon/favicon-32x32.png
  convert favicon.svg -resize 180x180 favicon/apple-touch-icon.png
  ```

- [ ] **Render Template Videos**
  - [ ] Run example templates through Fluvie
  - [ ] Take screenshots or create short MP4s
  - [ ] Replace placeholder template images in `website/assets/images/templates/`

- [ ] **Create Demo Video** (optional)
  - [ ] Render "Hello Fluvie" example
  - [ ] Convert to MP4 loop for hero section
  - [ ] Add to `website/assets/videos/demo-intro.mp4`

## Marketing & Announcements

- [ ] **Update Package Homepage**
  - [ ] Update `pubspec.yaml` homepage to `https://fluvie.dev`
  - [ ] Publish updated package to pub.dev

- [ ] **Social Media Announcements**
  - [ ] Twitter/X: Announce launch with screenshot
  - [ ] Reddit: Post to r/FlutterDev
  - [ ] Flutter Community Discord
  - [ ] LinkedIn (optional)

- [ ] **GitHub**
  - [ ] Update repository description to mention fluvie.dev
  - [ ] Pin repository (if desired)
  - [ ] Create announcement in GitHub Discussions

- [ ] **Documentation Updates**
  - [ ] Ensure all doc files link to fluvie.dev where appropriate
  - [ ] Update any "getting started" guides to reference the website

## Monitoring

- [ ] **Set up monitoring** (optional)
  - [ ] GitHub Actions: Monitor deployment workflows
  - [ ] Analytics: Add Plausible or similar (privacy-friendly)
  - [ ] Uptime monitoring: UptimeRobot or similar

## Success Metrics (Track after 30 days)

- [ ] **Traffic Goals**
  - [ ] 1,000+ unique visitors
  - [ ] 3+ minute average session duration
  - [ ] 100+ clicks to pub.dev

- [ ] **SEO Goals**
  - [ ] Indexed by Google: `site:fluvie.dev`
  - [ ] Top 10 for "flutter video generation"
  - [ ] Top 10 for "programmatic video flutter"

- [ ] **Engagement Goals**
  - [ ] 50+ new GitHub stars
  - [ ] 500+ pub.dev package points increase
  - [ ] 10+ community contributions

---

## Issue Tracker

If you encounter issues during deployment, document them here:

| Issue | Solution | Status |
|-------|----------|--------|
| Example: DNS not propagating | Waited 24 hours, cleared Cloudflare cache | ✅ Resolved |
|       |          |        |

---

**Deployment Date**: _____________

**Deployed By**: _____________

**Live URL**: https://fluvie.dev

**Status**: ⏳ Pending → ✅ Live
