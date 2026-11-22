(function () {
  "use strict";
  var root = document.documentElement;

  // ---------- teks English (teks Indonesia ada langsung di HTML) ----------
  var EN = {
    skip: "Skip to content",
    theme_dark: "Dark", theme_light: "Light",
    nav_label: "Page sections",
    nav_story: "Story", nav_how: "How it works", nav_features: "Features", nav_install: "Install",
    hero_title: "Notes that stick to the edge of your screen.",
    hero_lead: "Sticky notes for Linux. Your notes become small tabs on the screen edge: point at them to peek, click to open. No window sitting on top of your work.",
    cta_deb: "Download the .deb for Ubuntu",
    cta_other: "Install on Arch / Omarchy",
    hero_fine: "Free and open source (GPLv3). No account, no cloud.",
    demo_alt: "EdgeNotes demo: the strip on the screen edge fans out into tabs, one tab grows into a peek card, then a click opens the note",
    story_head: "Why I made this",
    story_p1: "I made this app to take notes while working on my projects. The notes had to stay visible without getting in the way.",
    story_p2: "I built it with help from AI. The idea, the flow, and the daily testing are still mine. And it really helped: my project got finished.",
    how_title: "From a thin pill to a note, in one mouse move",
    strip_alt_light: "The four states of the strip, light theme",
    strip_alt_dark: "The four states of the strip, dark theme",
    stage1: "<b>At rest.</b> Just a thin pill on the screen edge.",
    stage2: "<b>Approach.</b> The pill fans out into colored tabs.",
    stage3: "<b>Hover a tab.</b> A peek card shows the note.",
    stage4: "<b>Checklists.</b> Progress is visible without opening anything.",
    editor_alt_light: "The note editor window, light theme",
    editor_alt_dark: "The note editor window, dark theme",
    editor_title: "Click a tab, the note opens",
    editor_p: "Saved as you type. Type <code>[ ]</code> for a checklist, <code>-</code> or <code>1.</code> for a list. Paste images, and links are clickable.",
    keys_title: "Or straight from the keyboard",
    key_new: "new note", key_all: "all notes", key_toggle: "open/close the last note", key_search: "quick search",
    feat_title: "What's inside?",
    feat_hint: "Go ahead and tick them, just like a checklist in the app.",
    feat_done: "ticked",
    f1: "Tabs on the screen edge, peek on hover", f2: "Checklists with progress", f3: "Reminders",
    f4: "Quick search", f5: "Pin important notes", f6: "Note groups",
    f7: "Focus mode: hide the strip for a while", f8: "Version history, so you can go back",
    f9: "Paste images from the clipboard", f10: "4 fonts and 8 note colors",
    f11: "Light and dark themes, following your system", f12: "Export and import: JSON, Markdown, text",
    priv_big: "Your notes stay right here.",
    priv_p: "No account, no cloud, and no network code at all. Everything lives in <code class=\"path\">~/.local/share/edgenotes/notes.json</code>, with an automatic <code>.bak</code> backup.",
    inst_title: "Install",
    inst_tabs: "Choose your distro",
    inst_other: "Other distros",
    inst_deb: "Download the <code>.deb</code> file from the <a href=\"https://github.com/ibeeng/edgenotes/releases/latest\">latest release page</a>, then:",
    inst_arch: "No sudo needed for the install itself. <code>~/.local/bin</code> is already on Omarchy's PATH.",
    inst_src: "Needs Python 3, PyGObject, pycairo, and GTK 3 from your distro's package manager.",
    copy: "Copy", copied: "Copied to clipboard.", copy_fail: "Could not copy. Select the text and copy it by hand.",
    foot: "EdgeNotes is made by ibeeng. Licensed under GPL-3.0.",
    foot_star: "If you like it, star it on GitHub"
  };
  var ID_EXTRA = {
    theme_dark: "Gelap", theme_light: "Terang",
    copied: "Tersalin ke clipboard.", copy_fail: "Gagal menyalin. Blok teksnya lalu salin manual."
  };

  // simpan teks Indonesia asli dari HTML
  var ID = Object.assign({}, ID_EXTRA);
  document.querySelectorAll("[data-i18n]").forEach(function (el) { ID[el.dataset.i18n] = el.innerHTML; });
  document.querySelectorAll("[data-i18n-alt]").forEach(function (el) { ID[el.dataset.i18nAlt] = el.alt; });
  document.querySelectorAll("[data-i18n-aria]").forEach(function (el) { ID[el.dataset.i18nAria] = el.getAttribute("aria-label"); });

  var lang = localStorage.getItem("en-lang") === "en" ? "en" : "id";
  function t(key) { return (lang === "en" ? EN : ID)[key] || ID[key] || ""; }

  var langBtn = document.getElementById("lang-btn");
  function applyLang() {
    root.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      if (!el.closest("#theme-btn")) el.innerHTML = t(el.dataset.i18n);
    });
    document.querySelectorAll("[data-i18n-alt]").forEach(function (el) { el.alt = t(el.dataset.i18nAlt); });
    document.querySelectorAll("[data-i18n-aria]").forEach(function (el) { el.setAttribute("aria-label", t(el.dataset.i18nAria)); });
    langBtn.textContent = lang === "en" ? "ID" : "EN";
    langBtn.setAttribute("aria-label", lang === "en" ? "Ganti ke Bahasa Indonesia" : "Switch to English");
    document.title = lang === "en"
      ? "EdgeNotes: sticky notes on the edge of your screen, for Linux"
      : "EdgeNotes: catatan tempel di pinggir layar, untuk Linux";
    applyThemeLabel();
  }
  langBtn.addEventListener("click", function () {
    lang = lang === "en" ? "id" : "en";
    localStorage.setItem("en-lang", lang);
    applyLang();
  });

  // ---------- tema ----------
  var themeBtn = document.getElementById("theme-btn");
  function applyThemeLabel() {
    var dark = root.dataset.theme === "dark";
    // tombol menyebut tema tujuan; aria-pressed = tema gelap aktif
    themeBtn.querySelector(".theme-label").textContent = dark ? t("theme_light") : t("theme_dark");
    themeBtn.setAttribute("aria-pressed", dark ? "true" : "false");
  }
  themeBtn.addEventListener("click", function () {
    root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
    localStorage.setItem("en-theme", root.dataset.theme);
    applyThemeLabel();
  });

  // ---------- tab tepi: tandai bagian yang sedang dibaca ----------
  var navLinks = Array.prototype.slice.call(document.querySelectorAll(".edge a"));
  if ("IntersectionObserver" in window) {
    var visible = {};
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting ? e.intersectionRatio : 0; });
      var best = null, score = 0;
      Object.keys(visible).forEach(function (id) { if (visible[id] > score) { score = visible[id]; best = id; } });
      navLinks.forEach(function (a) {
        if (best && a.getAttribute("href") === "#" + best) a.setAttribute("aria-current", "true");
        else a.removeAttribute("aria-current");
      });
    }, { threshold: [0, .15, .3, .5, .75] });
    navLinks.forEach(function (a) {
      var s = document.querySelector(a.getAttribute("href"));
      if (s) io.observe(s);
    });

    // kartu cerita: miring sampai terlihat, lalu "patah-patah" lurus sekali saja
    var tio = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); tio.unobserve(e.target); }
      });
    }, { threshold: .45 });
    document.querySelectorAll(".tilt").forEach(function (el) { tio.observe(el); });
  } else {
    document.querySelectorAll(".tilt").forEach(function (el) { el.classList.add("in"); });
  }

  // ---------- checklist fitur ----------
  var boxes = document.querySelectorAll(".checklist input");
  var done = document.getElementById("done");
  document.getElementById("total").textContent = boxes.length;
  function count() {
    var n = 0;
    boxes.forEach(function (b) { if (b.checked) n++; });
    done.textContent = n;
  }
  boxes.forEach(function (b) { b.addEventListener("change", count); });
  count();

  // ---------- tab distro (pola ARIA tabs, panah kiri/kanan) ----------
  var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
  function select(tab, focus) {
    tabs.forEach(function (x) {
      var on = x === tab;
      x.setAttribute("aria-selected", on ? "true" : "false");
      x.tabIndex = on ? 0 : -1;
      document.getElementById(x.getAttribute("aria-controls")).hidden = !on;
    });
    if (focus) tab.focus();
  }
  tabs.forEach(function (tab, i) {
    tab.addEventListener("click", function () { select(tab, false); });
    tab.addEventListener("keydown", function (e) {
      var j = null;
      if (e.key === "ArrowRight") j = (i + 1) % tabs.length;
      else if (e.key === "ArrowLeft") j = (i - 1 + tabs.length) % tabs.length;
      else if (e.key === "Home") j = 0;
      else if (e.key === "End") j = tabs.length - 1;
      if (j !== null) { e.preventDefault(); select(tabs[j], true); }
    });
  });

  // ---------- tombol salin ----------
  var status = document.querySelector(".copy-status");
  document.querySelectorAll(".copy").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.parentNode.querySelector("code").textContent;
      var ok = function () { status.textContent = t("copied"); };
      var fail = function () { status.textContent = t("copy_fail"); };
      if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(ok, fail);
      else fail();
    });
  });

  applyLang();
})();
