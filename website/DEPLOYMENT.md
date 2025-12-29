# Deployment Guide for fluvie.dev

This guide walks through deploying the Fluvie marketing website to GitHub Pages with the custom domain `fluvie.dev`.

## Prerequisites

- GitHub repository with push access
- Domain name `fluvie.dev` (or update CNAME file)
- DNS provider access (Cloudflare, Namecheap, etc.)

## Step 1: Enable GitHub Pages

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Pages**
3. Under "Build and deployment":
   - **Source**: Deploy from a branch
   - **Branch**: `main`
   - **Folder**: `/website`
4. Click **Save**

GitHub will automatically deploy the contents of the `website/` directory to:
- Default URL: `https://simonerich.github.io/fluvie/`

## Step 2: Configure Custom Domain (fluvie.dev)

### A. In GitHub Settings

1. Still in **Settings** → **Pages**
2. Under "Custom domain":
   - Enter: `fluvie.dev`
   - Click **Save**
3. Wait for DNS check (may take a few minutes)
4. Once verified, check **Enforce HTTPS**

### B. In Your DNS Provider

You have two options:

#### Option 1: CNAME Record (Recommended for subdomains)

If using `www.fluvie.dev` or a subdomain:

```
Type: CNAME
Name: www
Value: simonerich.github.io
TTL: Auto or 3600
```

#### Option 2: A Records (For apex domain fluvie.dev)

For the root domain `fluvie.dev`:

```
Type: A
Name: @ (or leave blank for root)
Value: 185.199.108.153
TTL: Auto or 3600

Add 3 more A records with the same settings but different IPs:
- 185.199.109.153
- 185.199.110.153
- 185.199.111.153
```

**For www subdomain**, also add:
```
Type: CNAME
Name: www
Value: simonerich.github.io
TTL: Auto or 3600
```

### C. Verify CNAME File

The file `website/CNAME` should contain only:
```
fluvie.dev
```

This file is already created and committed.

## Step 3: Wait for DNS Propagation

DNS changes can take anywhere from a few minutes to 48 hours to propagate globally.

Check propagation status:
- https://dnschecker.org/#A/fluvie.dev
- https://www.whatsmydns.net/#A/fluvie.dev

## Step 4: Test Deployment

1. **GitHub Pages default URL** (should work immediately):
   - https://simonerich.github.io/fluvie/

2. **Custom domain** (after DNS propagation):
   - http://fluvie.dev
   - https://fluvie.dev (after HTTPS is enabled)

### Expected Results

✅ Homepage loads correctly
✅ All CSS styles are applied
✅ Monaco Editor code playground works
✅ All images load (logo, architecture diagram, templates)
✅ Navigation links work (smooth scroll)
✅ Mobile responsive design works
✅ No console errors

## Step 5: Enable HTTPS (Recommended)

Once the custom domain is verified:

1. Go to **Settings** → **Pages**
2. Check **Enforce HTTPS**
3. GitHub will automatically provision a Let's Encrypt certificate

This may take a few minutes. Once enabled:
- http://fluvie.dev → redirects to https://fluvie.dev
- https://fluvie.dev → serves securely

## Troubleshooting

### Issue: "Improperly configured" error in GitHub Pages settings

**Solution**:
- Check that CNAME file contains only `fluvie.dev` (no `http://` or trailing slashes)
- Verify DNS records are correct
- Wait for DNS propagation

### Issue: 404 Page Not Found

**Solution**:
- Ensure GitHub Pages is enabled for `/website` folder on `main` branch
- Check that `index.html` exists in `/website` directory
- Verify the repository is public (or GitHub Pages is enabled for private repos)

### Issue: CSS/JS not loading

**Solution**:
- Check that asset paths in `index.html` are relative: `./assets/css/main.css`
- Not absolute: `/assets/css/main.css`
- This is already configured correctly in the current setup

### Issue: Monaco Editor not loading

**Solution**:
- Check browser console for errors
- Verify CDN links are accessible:
  - https://cdn.jsdelivr.net/npm/monaco-editor@0.44.0/min/vs/loader.js
- Clear browser cache and reload

### Issue: DNS not propagating

**Solution**:
- Wait up to 48 hours
- Check DNS provider settings (some require "Proxy" to be disabled for GitHub Pages)
- If using Cloudflare:
  - Set SSL/TLS to "Full" (not "Flexible")
  - Ensure "Always Use HTTPS" is off initially

## Updating the Site

### Content Changes

1. Edit files in `website/` directory locally
2. Test changes locally:
   ```bash
   cd website
   python3 -m http.server 8000
   # Visit http://localhost:8000
   ```
3. Commit and push changes:
   ```bash
   git add docs/
   git commit -m "Update marketing website"
   git push origin main
   ```
4. GitHub Pages will automatically rebuild and deploy (usually within 1-2 minutes)

### Monitoring Deployment

- Go to repository → **Actions** tab
- Click on the latest workflow run to see deployment status
- Look for "pages build and deployment" workflow

## DNS Provider Examples

### Cloudflare

1. Log in to Cloudflare dashboard
2. Select your domain `fluvie.dev`
3. Go to **DNS** → **Records**
4. Add the A records and CNAME as specified above
5. **Important**: Ensure "Proxy status" is set to "DNS only" (gray cloud icon)
6. Once GitHub Pages confirms HTTPS, you can enable proxy (orange cloud)

### Namecheap

1. Log in to Namecheap account
2. Go to **Domain List** → Manage `fluvie.dev`
3. Select **Advanced DNS** tab
4. Add Host Records:
   - Type: A Record, Host: @, Value: 185.199.108.153, TTL: Automatic
   - (Repeat for other 3 IPs)
   - Type: CNAME, Host: www, Value: simonerich.github.io, TTL: Automatic

### Google Domains

1. Go to DNS settings for `fluvie.dev`
2. Add Resource Records:
   - A records pointing @ to GitHub's IPs
   - CNAME for www pointing to simonerich.github.io

## Performance Optimization

After deployment, run these checks:

1. **Lighthouse Audit** (in Chrome DevTools):
   - Target: Performance 95+, SEO 100, Accessibility 95+

2. **PageSpeed Insights**:
   - https://pagespeed.web.dev/
   - Analyze both mobile and desktop

3. **Validate HTML**:
   - https://validator.w3.org/

4. **Check Links**:
   - Verify all internal and external links work

## Post-Deployment Tasks

- [ ] Update DNS records
- [ ] Verify fluvie.dev loads correctly
- [ ] Enable HTTPS in GitHub Pages settings
- [ ] Test on mobile devices
- [ ] Run Lighthouse audit
- [ ] Share on social media (Twitter, Reddit, Flutter community)
- [ ] Update pub.dev package homepage to `https://fluvie.dev`
- [ ] Announce on GitHub Discussions

## Security

- ✅ HTTPS enforced via GitHub Pages
- ✅ No sensitive data in static files
- ✅ CSP headers handled by GitHub Pages
- ✅ No backend, no database = minimal attack surface

## Analytics (Optional)

If you want to track visitors, add privacy-friendly analytics:

### Plausible Analytics (Recommended)

1. Sign up at https://plausible.io/
2. Add script to `<head>` in `index.html`:
   ```html
   <script defer data-domain="fluvie.dev" src="https://plausible.io/js/script.js"></script>
   ```

### Google Analytics

1. Create GA4 property
2. Add tracking code to `<head>` in `index.html`

## Maintenance

- Monitor GitHub Actions for deployment failures
- Check for broken links quarterly
- Update dependencies (Monaco Editor CDN) annually
- Refresh template screenshots when examples change
- Update version numbers and stats in content

## Support

For deployment issues:
- GitHub Pages Documentation: https://website.github.com/en/pages
- GitHub Community: https://github.community/

For site bugs:
- Open an issue: https://github.com/simonerich/fluvie/issues

---

**Deployment Status**: ⏳ Pending first deployment

Once deployed, update this status to: ✅ Live at https://fluvie.dev
