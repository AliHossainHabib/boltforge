/* boltforge docs — shared behavior
   Injected into every docs/*.html page. Builds the sidebar from a single
   source of truth (PAGES below) so adding/renaming a page means editing
   one array, not fourteen files. */

(function () {
  "use strict";

  var PAGES = [
    { group: "البداية", href: "index.html", title: "الصفحة الرئيسية" },
    { group: "البداية", href: "getting-started.html", title: "البدء السريع" },
    { group: "البداية", href: "architecture.html", title: "المعمارية العامة" },
    { group: "الأداة", href: "cli.html", title: "أوامر الـ CLI" },
    { group: "الأداة", href: "project-generation.html", title: "إنشاء مشروع (create)" },
    { group: "الأداة", href: "authentication.html", title: "أنظمة تسجيل الدخول" },
    { group: "الأداة", href: "feature-generation.html", title: "توليد Feature (generate)" },
    { group: "التخصيص", href: "templates.html", title: "نظام القوالب (Templates)" },
    { group: "التخصيص", href: "configuration.html", title: "الإعدادات (Configuration)" },
    { group: "الجودة", href: "testing.html", title: "الاختبارات (Testing)" },
    { group: "الجودة", href: "troubleshooting.html", title: "استكشاف الأخطاء" },
    { group: "النشر", href: "publishing.html", title: "النشر على pub.dev" },
    { group: "النشر", href: "contributing.html", title: "المساهمة في المشروع" },
    { group: "النشر", href: "license.html", title: "الترخيص" },
  ];

  function currentFile() {
    var parts = location.pathname.split("/");
    var last = parts[parts.length - 1];
    return last === "" ? "index.html" : last;
  }

  function buildSidebar() {
    var mount = document.getElementById("sidebar-mount");
    if (!mount) return;

    var current = currentFile();
    var groups = [];
    PAGES.forEach(function (p) {
      var g = groups.find(function (x) { return x.name === p.group; });
      if (!g) { g = { name: p.group, items: [] }; groups.push(g); }
      g.items.push(p);
    });

    var html = "";
    html += '<div class="sidebar-brand"><span class="dot"></span> boltforge</div>';
    html += '<div class="sidebar-sub">التوثيق الرسمي — بالعربية</div>';
    html += '<input type="text" class="search-box" id="docs-search" placeholder="ابحث في التوثيق… (مثال: generate, cubit, auth)">';
    html += '<div><a href="../project-dashboard.html" style="display:block;padding:8px 10px;border-radius:8px;background:var(--bg-card);border:1px solid var(--border);color:var(--text);text-align:center;margin-bottom:10px;">↩ لوحة تحكم المشروع</a></div>';

    groups.forEach(function (g) {
      html += '<div class="nav-group-title">' + g.name + "</div>";
      html += '<ul class="nav-list">';
      g.items.forEach(function (p) {
        var activeClass = p.href === current ? " active" : "";
        html += '<li><a href="' + p.href + '" class="nav-link' + activeClass +
          '" data-title="' + p.title.toLowerCase() + '">' + p.title + "</a></li>";
      });
      html += "</ul>";
    });

    mount.innerHTML = html;

    var search = document.getElementById("docs-search");
    search.addEventListener("input", function () {
      var q = search.value.trim().toLowerCase();
      document.querySelectorAll(".nav-link").forEach(function (a) {
        var matches = !q || a.dataset.title.indexOf(q) !== -1 || a.textContent.toLowerCase().indexOf(q) !== -1;
        a.classList.toggle("search-hidden", !matches);
      });
      highlightInPage(q);
    });
  }

  function highlightInPage(query) {
    var main = document.querySelector(".main");
    if (!main) return;
    // Clear previous marks.
    main.querySelectorAll("mark[data-auto]").forEach(function (m) {
      var parent = m.parentNode;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize();
    });
    if (!query || query.length < 2) return;

    var walker = document.createTreeWalker(main, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue.toLowerCase().includes(query)) return NodeFilter.FILTER_REJECT;
        if (node.parentNode.closest("pre, code, script, style")) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    var nodes = [];
    var n;
    while ((n = walker.nextNode())) nodes.push(n);

    nodes.forEach(function (node) {
      var text = node.nodeValue;
      var lower = text.toLowerCase();
      var idx = lower.indexOf(query);
      if (idx === -1) return;
      var before = text.slice(0, idx);
      var match = text.slice(idx, idx + query.length);
      var after = text.slice(idx + query.length);
      var mark = document.createElement("mark");
      mark.dataset.auto = "1";
      mark.textContent = match;
      var frag = document.createDocumentFragment();
      frag.appendChild(document.createTextNode(before));
      frag.appendChild(mark);
      frag.appendChild(document.createTextNode(after));
      node.parentNode.replaceChild(frag, node);
    });

    var firstMark = main.querySelector("mark[data-auto]");
    if (firstMark) firstMark.scrollIntoView({ behavior: "smooth", block: "center" });
  }

  function addCopyButtons() {
    document.querySelectorAll("pre").forEach(function (pre) {
      if (pre.dataset.copyReady) return;
      pre.dataset.copyReady = "1";
      var btn = document.createElement("button");
      btn.className = "copy-btn";
      btn.type = "button";
      btn.textContent = "نسخ";
      btn.addEventListener("click", function () {
        var text = pre.innerText.replace(/^نسخ\n?/, "");
        navigator.clipboard.writeText(text).then(function () {
          btn.textContent = "تم النسخ ✓";
          btn.classList.add("copied");
          setTimeout(function () {
            btn.textContent = "نسخ";
            btn.classList.remove("copied");
          }, 1600);
        });
      });
      pre.style.position = "relative";
      pre.insertBefore(btn, pre.firstChild);
    });
  }

  function mobileToggle() {
    var btn = document.getElementById("mobile-menu-btn");
    if (!btn) return;
    btn.addEventListener("click", function () {
      document.body.classList.toggle("sidebar-open");
    });
    document.addEventListener("click", function (e) {
      if (document.body.classList.contains("sidebar-open") &&
          !e.target.closest(".sidebar") &&
          !e.target.closest("#mobile-menu-btn")) {
        document.body.classList.remove("sidebar-open");
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    buildSidebar();
    addCopyButtons();
    mobileToggle();
  });
})();
