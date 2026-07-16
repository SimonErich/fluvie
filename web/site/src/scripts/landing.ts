// The landing page's interactivity, ported verbatim from the original inline
// script: the nav theme/scroll progress, the hero scrubber, copy buttons, the
// trigger tabs + lever, the gallery filter, and the "pick your seat" tabs. The
// only change from the original is that the
// gallery data (GAL) is read from a build-rendered JSON element (#gal-data),
// so the tiles come from the repo's lessons instead of a hardcoded array.
(function () {
  "use strict";
  var GRAD = "linear-gradient(120deg,#36E1FF,#1668E3 60%,#0B3FB0)";
  var $ = function (s: string, r?: ParentNode) { return (r || document).querySelector(s); };
  var $$ = function (s: string, r?: ParentNode) {
    return Array.prototype.slice.call((r || document).querySelectorAll(s));
  };

  // ---- style-hover applier (mirrors the design runtime) ----
  function parseStyle(text: string) {
    var out: Record<string, string> = {};
    (text || "").split(";").forEach(function (decl) {
      var i = decl.indexOf(":");
      if (i < 0) return;
      var prop = decl.slice(0, i).trim();
      var val = decl.slice(i + 1).trim();
      if (prop) out[prop] = val;
    });
    return out;
  }
  $$("[style-hover]").forEach(function (el) {
    var hover = parseStyle(el.getAttribute("style-hover"));
    var keys = Object.keys(hover);
    if (!keys.length) return;
    var saved: Record<string, string> | null = null;
    var apply = function () {
      saved = {};
      keys.forEach(function (k) {
        saved![k] = el.style.getPropertyValue(k);
        el.style.setProperty(k, hover[k]);
      });
    };
    var revert = function () {
      if (!saved) return;
      keys.forEach(function (k) {
        if (saved![k]) el.style.setProperty(k, saved![k]);
        else el.style.removeProperty(k);
      });
      saved = null;
    };
    el.addEventListener("mouseenter", apply);
    el.addEventListener("mouseleave", revert);
    el.addEventListener("focus", apply);
    el.addEventListener("blur", revert);
  });

  // ---- copy helper ----
  function copyText(text: string) {
    try { if (navigator.clipboard) navigator.clipboard.writeText(text); } catch (e) {}
  }

  // ---- nav: theme over hero, scroll progress, whisper, spotlight ----
  var nav = $("[data-flv-nav]");
  var prog = $("[data-flv-progress]");
  var hero = $("[data-flv-hero]");
  var navLogo = $("#navLogo");
  var navDark: boolean | null = null;
  function setNav(dark: boolean) {
    if (!nav) return;
    var c = dark
      ? { bg: "rgba(10,14,30,0.5)", bd: "rgba(255,255,255,0.12)", fg: "rgba(255,255,255,0.82)", lo: "#fff" }
      : { bg: "rgba(255,255,255,0.72)", bd: "#E6ECF7", fg: "#51607F", lo: "#0B1020" };
    nav.style.background = c.bg; nav.style.borderColor = c.bd;
    $$("[data-flv-navlink]", nav).forEach(function (a) { a.style.color = c.fg; });
    var lt = $("[data-flv-logotext]", nav); if (lt) lt.style.color = c.lo;
    // Inverted (white) logo over the dark hero, normal logo on the white body.
    if (navLogo && navDark !== dark) {
      navLogo.src = dark ? "fluvie_logo_inverted.svg" : "fluvie_logo.svg";
      navDark = dark;
    }
  }
  function tick() {
    setNav(hero ? hero.getBoundingClientRect().bottom > 80 : true);
    var doc = document.documentElement;
    var max = (doc.scrollHeight - doc.clientHeight) || 1;
    var p = Math.min(1, Math.max(0, (window.scrollY || doc.scrollTop || 0) / max));
    if (prog) prog.style.width = (p * 100) + "%";
    requestAnimationFrame(tick);
  }
  tick();
  var logo = $("[data-flv-logo]"), whisper = $("[data-flv-whisper]");
  if (logo && whisper) {
    logo.addEventListener("mouseenter", function () { whisper.style.opacity = "1"; });
    logo.addEventListener("mouseleave", function () { whisper.style.opacity = "0"; });
  }
  document.addEventListener("mousemove", function (e) {
    if (!hero) return;
    var r = hero.getBoundingClientRect();
    if (e.clientY < r.top || e.clientY > r.bottom) return;
    hero.style.setProperty("--mx", (((e.clientX - r.left) / r.width) * 100) + "%");
    hero.style.setProperty("--my", (((e.clientY - r.top) / r.height) * 100) + "%");
  }, { passive: true });

  // ---- hero scrubber ----
  var heroRange = $("#heroRange"), heroTitle = $("#heroTitle"),
      heroStrip = $("#heroStrip"), heroFrameText = $("#heroFrameText");
  function renderHero(hf: number) {
    var op = Math.max(0, Math.min(1, (hf - 2) / 6));
    var sc = 0.7 + Math.max(0, Math.min(1, (hf - 2) / 7)) * 0.3 + (hf >= 12 ? (hf - 12) * 0.02 : 0);
    if (heroTitle) { heroTitle.style.opacity = op.toFixed(2); heroTitle.style.transform = "scale(" + sc.toFixed(2) + ")"; }
    if (heroStrip) {
      var html = "";
      for (var i = 0; i < 16; i++) {
        var bg = i <= hf ? (i === hf ? "#36E1FF" : "rgba(54,225,255,0.45)") : "rgba(255,255,255,0.1)";
        html += '<span style="flex:1; height:18px; border-radius:2px; background:' + bg + ';"></span>';
      }
      heroStrip.innerHTML = html;
    }
    var txt = "frame " + (hf + 1) + " of 16";
    if (heroFrameText) heroFrameText.textContent = txt;
    if (heroRange) heroRange.setAttribute("aria-valuetext", txt);
  }
  if (heroRange) {
    heroRange.addEventListener("input", function () { renderHero(parseInt(heroRange.value, 10)); });
    renderHero(parseInt(heroRange.value, 10));
  }

  // ---- copy: hero render + steps ----
  var copyRenderBtn = $("#copyRenderBtn"), copyRenderMsg = $("#copyRenderMsg"), renderMsgTimer: number;
  if (copyRenderBtn) {
    copyRenderBtn.addEventListener("click", function () {
      copyText(copyRenderBtn.getAttribute("data-cmd"));
      if (copyRenderMsg) {
        copyRenderMsg.textContent = "Copied. Now run it.";
        clearTimeout(renderMsgTimer);
        renderMsgTimer = setTimeout(function () { copyRenderMsg.textContent = ""; }, 2000);
      }
    });
  }
  $$(".stepCopy").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var pre = btn.parentNode.querySelector("pre");
      if (pre) copyText(pre.textContent);
      var step = btn.getAttribute("data-step");
      var num = $('.stepNum[data-step="' + step + '"]');
      var icon = btn.querySelector("span");
      if (num) { num.style.color = "#fff"; num.style.background = "#1668E3"; num.style.borderColor = "#1668E3"; }
      if (icon) icon.innerHTML = "&#10003;";
      clearTimeout(btn._t);
      btn._t = setTimeout(function () {
        if (num) { num.style.color = "#1668E3"; num.style.background = "#EEF3FD"; num.style.borderColor = "#D8E5FE"; }
        if (icon) icon.innerHTML = "&#9112;";
      }, 2000);
    });
  });

  // ---- triggers: tabs + lever ----
  var C = { ty: "#36E1FF", st: "#7CF3C2", nu: "#F78C6C", fn: "#82AAFF", cm: "#6A7796" };
  var trigCodeEl = $("#trigCode"), syncBadge = $("#syncBadge"), leverMsg = $("#leverMsg");
  var trigTabTimeline = $("#trigTabTimeline"), trigTabFluvie = $("#trigTabFluvie");
  var CODE_TL =
    '<span style="color:' + C.cm + ';">// hardcoded milliseconds</span>\n' +
    'title<span style="color:' + C.fn + ';">.fadeIn</span>(at: <span style="color:' + C.nu + ';">0</span>);\n' +
    'subtitle<span style="color:' + C.fn + ';">.show</span>(at: <span style="color:' + C.nu + ';">650</span>);\n' +
    'chart<span style="color:' + C.fn + ';">.grow</span>(at: <span style="color:' + C.nu + ';">900</span>);\n\n' +
    '<span style="color:#F3849B;">// move the title? retype everything.</span>';
  var CODE_FL =
    '<span style="color:' + C.cm + ';">// triggers, not timecodes</span>\n' +
    'title<span style="color:' + C.fn + ';">.show</span>();\n' +
    'subtitle.<span style="color:' + C.fn + ';">show</span>(<span style="color:' + C.ty + ';">Trigger</span>.<span style="color:' + C.fn + ';">after</span>(title));\n' +
    'chart.<span style="color:' + C.fn + ';">grow</span>(<span style="color:' + C.ty + ';">Trigger</span>.<span style="color:' + C.fn + ';">after</span>(<span style="color:' + C.st + ';">previous</span>));\n\n' +
    '<span style="color:#7CF3C2;">// move the title? everything follows.</span>';
  function setTrig(isTl: boolean) {
    if (trigCodeEl) trigCodeEl.innerHTML = isTl ? CODE_TL : CODE_FL;
    if (trigTabTimeline) {
      trigTabTimeline.setAttribute("aria-selected", isTl ? "true" : "false");
      trigTabTimeline.style.background = isTl ? "#1a2240" : "transparent";
      trigTabTimeline.style.color = isTl ? "#fff" : "#6A7796";
    }
    if (trigTabFluvie) {
      trigTabFluvie.setAttribute("aria-selected", isTl ? "false" : "true");
      trigTabFluvie.style.background = isTl ? "transparent" : GRAD;
      trigTabFluvie.style.color = isTl ? "#6A7796" : "#fff";
    }
    if (syncBadge) {
      syncBadge.style.background = isTl ? "#FCE9EC" : "#E4F7EE";
      syncBadge.style.color = isTl ? "#D7415E" : "#0E9E6E";
      syncBadge.innerHTML = isTl ? "✕ drifted" : "✓ in sync";
    }
    if (leverMsg) leverMsg.textContent = isTl
      ? "On the timeline side the hardcoded subtitle stays at 650ms while the title moved. It is out of sync now."
      : "On the Fluvie side, the subtitle is anchored after the title, so it followed automatically.";
  }
  if (trigTabTimeline) trigTabTimeline.addEventListener("click", function () { setTrig(true); });
  if (trigTabFluvie) trigTabFluvie.addEventListener("click", function () { setTrig(false); });
  setTrig(false);

  var leverRange = $("#leverRange"), leverFill = $("#leverFill"), subFollowFill = $("#subFollowFill");
  if (leverRange) {
    leverRange.addEventListener("input", function () {
      var v = parseInt(leverRange.value, 10);
      if (leverFill) leverFill.style.left = v + "%";
      if (subFollowFill) subFollowFill.style.left = (v + 34) + "%";
      leverRange.setAttribute("aria-valuetext", "Title starts at " + v + "%");
    });
  }

  // ---- gallery: build tiles + filter ----
  // GAL is rendered at build time from the repo's lessons (see Reel.astro).
  var galEl = document.getElementById("gal-data");
  var GAL = galEl ? JSON.parse(galEl.textContent || "[]") : [];
  var POSTERS = [
    "radial-gradient(120% 120% at 50% 35%,#16357f,#06070F)",
    "radial-gradient(120% 120% at 50% 35%,#13409a,#06070F)",
    "linear-gradient(135deg,#10307a,#06070F)",
    "radial-gradient(120% 120% at 40% 30%,#0E9E8E,#06351f)",
    "linear-gradient(135deg,#3a2a6e,#06070F)"
  ];
  var grid = $("#galleryGrid");
  function esc(s: string) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
  function buildGallery(filter: string) {
    if (!grid) return;
    var html = "";
    GAL.forEach(function (g, i) {
      if (filter !== "all" && g[3] !== filter) return;
      var n = g[0], t = g[1], d = g[2], real = g[4], poster = POSTERS[i % POSTERS.length];
      var badge = real
        ? '<span aria-hidden="true" style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center;"><span style="font-family:\'Sora\'; font-weight:800; color:#fff; font-size:18px; animation:flvFadeScale 3.4s ease-in-out infinite; text-shadow:0 2px 20px rgba(124,243,255,0.5);">' + esc(t) + '</span></span>'
          + '<span aria-hidden="true" style="position:absolute; top:10px; right:10px; font-size:9px; font-family:\'JetBrains Mono\'; color:#7CF3C2; padding:2px 7px; border:1px solid rgba(124,243,255,0.4); border-radius:5px;">LIVE CLIP</span>'
        : '<span aria-hidden="true" style="position:absolute; bottom:10px; left:10px; display:inline-flex; align-items:center; gap:6px; font-size:10px; color:#cfe0ff; padding:3px 9px; background:rgba(0,0,0,0.45); border-radius:20px;"><svg width="9" height="9" viewBox="0 0 12 12" fill="currentColor"><path d="M2 1l8 5-8 5z"></path></svg> play in demo</span>';
      html +=
        '<a href="https://demo.fluvie.dev/#' + n + '" aria-label="Lesson ' + n + ', ' + esc(t) + ', opens the live demo (external)" style="display:block; text-decoration:none; color:inherit; border-radius:16px; overflow:hidden; border:1px solid var(--line); background:#fff; box-shadow:0 1px 3px rgba(11,16,32,0.05); transition:transform .28s ease, box-shadow .28s ease, border-color .28s ease;" style-hover="transform:translateY(-4px); box-shadow:0 28px 56px -26px rgba(11,16,32,0.22); border-color:#BFE6FF;">'
        + '<div style="position:relative; aspect-ratio:16/10; background:' + poster + '; overflow:hidden; display:flex; align-items:center; justify-content:center;">'
        + '<span aria-hidden="true" style="font-family:\'Sora\'; font-weight:800; font-size:34px; color:rgba(255,255,255,0.16);">' + n + '</span>'
        + badge
        + '<div aria-hidden="true" style="position:absolute; inset:0; box-shadow:inset 0 0 70px 14px rgba(0,0,0,0.45); pointer-events:none;"></div>'
        + '</div>'
        + '<div style="padding:14px 16px; border-top:1px solid var(--line); display:flex; align-items:center; gap:10px;">'
        + '<span aria-hidden="true" style="font-family:\'JetBrains Mono\'; font-size:12px; font-weight:700; color:var(--acc); padding:3px 8px; background:#EEF3FD; border-radius:6px;">' + n + '</span>'
        + '<div><div style="font-family:\'Sora\'; font-weight:700; font-size:14.5px;">' + esc(t) + '</div><div style="font-size:12px; color:var(--muted); margin-top:2px; line-height:1.4;">' + esc(d) + '</div></div>'
        + '</div></a>';
    });
    grid.innerHTML = html;
    bindHover(grid);
  }
  function bindHover(root: ParentNode) {
    $$("[style-hover]", root).forEach(function (el) {
      if (el._hoverBound) return;
      el._hoverBound = true;
      var hover = parseStyle(el.getAttribute("style-hover"));
      var keys = Object.keys(hover); if (!keys.length) return;
      var saved: Record<string, string> | null = null;
      var apply = function () { saved = {}; keys.forEach(function (k) { saved![k] = el.style.getPropertyValue(k); el.style.setProperty(k, hover[k]); }); };
      var revert = function () { if (!saved) return; keys.forEach(function (k) { if (saved![k]) el.style.setProperty(k, saved![k]); else el.style.removeProperty(k); }); saved = null; };
      el.addEventListener("mouseenter", apply); el.addEventListener("mouseleave", revert);
      el.addEventListener("focus", apply); el.addEventListener("blur", revert);
    });
  }
  buildGallery("all");
  $$(".filterBtn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var f = btn.getAttribute("data-filter");
      $$(".filterBtn").forEach(function (b) {
        var on = b === btn;
        b.setAttribute("aria-pressed", on ? "true" : "false");
        b.style.background = on ? "#1668E3" : "#fff";
        b.style.color = on ? "#fff" : "#51607F";
        b.style.borderColor = on ? "#1668E3" : "#ECEFF7";
      });
      buildGallery(f);
    });
  });

  // ---- seats ----
  var SEATS: Record<string, { forL: string; snip: string; cta: string; href: string; glyph: string }> = {
    live: { forL: "For the cold visitor", snip: "open https://demo.fluvie.dev", cta: "Open the live demo", href: "https://demo.fluvie.dev", glyph: "▶" },
    cli:  { forL: "For your terminal", snip: "fluvie render ./lib/hello.dart --out hello.mp4", cta: "Read the CLI docs", href: "https://pub.dev/packages/fluvie_cli", glyph: "⎘" },
    http: { forL: "Render from anywhere", snip: 'POST /render\n{ "video": "hello" }\n\n200 OK  →  hello.mp4', cta: "Self-host the API", href: "https://docs.fluvie.dev/guides/rendering-on-a-server", glyph: "⛁" },
    mcp:  { forL: "Let an assistant shoot it", snip: 'tool: fluvie.render\n{ "key": "hello" }', cta: "Read the MCP guide", href: "https://docs.fluvie.dev/guides/ai-and-mcp", glyph: "⌘" }
  };
  var seatFor = $("#seatFor"), seatSnippet = $("#seatSnippet"), seatCta = $("#seatCta"), seatGlyph = $("#seatGlyph");
  $$(".seatBtn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var k = btn.getAttribute("data-seat"), s = SEATS[k]; if (!s) return;
      $$(".seatBtn").forEach(function (b) {
        var on = b === btn;
        b.setAttribute("aria-selected", on ? "true" : "false");
        b.style.background = on ? GRAD : "transparent";
        b.style.color = on ? "#fff" : "#AEBBD8";
      });
      if (seatFor) seatFor.textContent = s.forL;
      if (seatSnippet) seatSnippet.textContent = s.snip;
      if (seatCta) { seatCta.firstChild.nodeValue = s.cta + " "; seatCta.setAttribute("href", s.href); }
      if (seatGlyph) seatGlyph.textContent = s.glyph;
    });
  });
})();
