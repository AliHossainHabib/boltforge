/* boltforge project-dashboard.html — logic
   Renders every checklist from the DATA object below (the single source
   of truth for "what's actually done"), persists checked/notes state to
   localStorage, and computes progress from that state. */

(function () {
  "use strict";

  var STORAGE_KEY = "boltforge-dashboard-state-v1";

  // ---------------------------------------------------------------
  // DATA: this is the real project state, not placeholder content.
  // "done: true" items reflect work actually completed and present in
  // the shipped files; "done: false" items are genuinely pending.
  // The checkbox state is still user-editable and persisted — this is
  // only the *default* the dashboard resets to.
  // ---------------------------------------------------------------

  var PHASES = [
    {
      id: "phase1",
      title: "Phase 1 — الأداة + المعمارية + الاختبارات",
      status: "done",
      items: [
        { id: "p1-cli-skeleton", label: "هيكل CLI: bin/boltforge.dart + CommandRunner + الأوامر الثلاثة", done: true },
        { id: "p1-template-engine", label: "محرك القوالب: {{variable}} + {{#if}}/{{#unless}}", done: true },
        { id: "p1-name-utils", label: "NameCase + NameValidator", done: true },
        { id: "p1-file-service", label: "FileService: cancel/overwrite/merge", done: true },
        { id: "p1-project-detector", label: "ProjectDetector (فحص pubspec.yaml + lib/)", done: true },
        { id: "p1-process-service", label: "ProcessService (تشغيل flutter/dart)", done: true },
        { id: "p1-project-generator", label: "ProjectGenerator: خط الأنابيب من 7 خطوات", done: true },
        { id: "p1-feature-generator", label: "FeatureGenerator + معالجة التعارض", done: true },
        { id: "p1-base-template", label: "قالب المعمارية الأساسية (templates/base/)", done: true },
        { id: "p1-auth-password", label: "قالب مصادقة Password كامل", done: true },
        { id: "p1-auth-otp", label: "قالب مصادقة OTP كامل", done: true },
        { id: "p1-feature-template", label: "قالب مولّد Feature (templates/feature/)", done: true },
        { id: "p1-tests", label: "11 ملف اختبار حقيقي (~100 حالة اختبار)", done: true },
        { id: "p1-bugfix", label: "إصلاح فعلي: ConflictAction.cancel كان يكتب ملفات جديدة رغم الإلغاء", done: true },
      ],
    },
    {
      id: "phase2",
      title: "Phase 2 — التوثيق العربي + لوحة التحكم",
      status: "in-progress",
      items: [
        { id: "p2-index", label: "docs/index.html", done: true },
        { id: "p2-getting-started", label: "docs/getting-started.html", done: true },
        { id: "p2-architecture", label: "docs/architecture.html", done: true },
        { id: "p2-cli", label: "docs/cli.html", done: true },
        { id: "p2-project-generation", label: "docs/project-generation.html", done: true },
        { id: "p2-authentication", label: "docs/authentication.html", done: true },
        { id: "p2-feature-generation", label: "docs/feature-generation.html (الدرس الكامل)", done: true },
        { id: "p2-templates", label: "docs/templates.html", done: true },
        { id: "p2-configuration", label: "docs/configuration.html", done: true },
        { id: "p2-testing", label: "docs/testing.html", done: true },
        { id: "p2-troubleshooting", label: "docs/troubleshooting.html", done: true },
        { id: "p2-publishing", label: "docs/publishing.html", done: true },
        { id: "p2-contributing", label: "docs/contributing.html", done: true },
        { id: "p2-license", label: "docs/license.html", done: true },
        { id: "p2-dashboard", label: "project-dashboard.html (هذه الصفحة)", done: true },
        { id: "p2-project-state", label: "تحديث PROJECT_STATE.json لهذه المرحلة", done: true },
      ],
    },
    {
      id: "phase2b",
      title: "Phase 2.5 — Feature Generator احترافي: lib/features/ + تسجيل DI تلقائي",
      status: "done",
      items: [
        { id: "p2b-lib-features-path", label: "نقل وجهة generate إلى lib/features/<name>/ (بدل lib/<name>/)", done: true },
        { id: "p2b-widgets-file", label: "presentation/widgets/ يحتوي الآن ملفًا حقيقيًا (XListItem)", done: true },
        { id: "p2b-import-depth", label: "تحديث عمق كل الاستيرادات النسبية في قالب Feature (+1 مستوى)", done: true },
        { id: "p2b-di-markers", label: "إضافة تعليقَي الترسيخ // boltforge:imports و // boltforge:registrations للقالب", done: true },
        { id: "p2b-di-registrar", label: "DiRegistrar: تسجيل تلقائي، بدون تكرار، تعامل آمن مع ملف مفقود/معدَّل يدويًا", done: true },
        { id: "p2b-feature-validator", label: "FeatureValidator: فحص ملفات ناقصة، tmpl متسرّب، placeholders، تسجيل مكرَّر", done: true },
        { id: "p2b-generate-command-report", label: "GenerateCommand يطبع حالة DI ونتائج التحقق، ويُنهي بالكود 1 عند خطأ حقيقي", done: true },
        { id: "p2b-tests-updated", label: "تحديث test/feature_generator_test.dart + test/cli_commands_test.dart لمسارات lib/features/", done: true },
        { id: "p2b-di-tests", label: "test/di_registrar_test.dart جديد (اختبارات وحدة معزولة)", done: true },
        { id: "p2b-docs-updated", label: "تحديث feature-generation.html, architecture.html, templates.html, troubleshooting.html, cli.html, testing.html, README.md", done: true },
      ],
    },
    {
      id: "phase2c",
      title: "Phase 2.6-2.7 — إصلاحات حقيقية من تشغيل فعلي: dart analyze/test + خطأ حزم حرج",
      status: "done",
      items: [
        { id: "p2c-argresults-fix", label: "إصلاح: استيراد package:args/args.dart المفقود لنوع ArgResults في cli_runner.dart", done: true },
        { id: "p2c-fake-process-fix", label: "إصلاح: خطأ ترقية nullable لحقل _onRun في FakeProcessService (compile error حقيقي)", done: true },
        { id: "p2c-workingdir-test-fix", label: "إصلاح اختبار working-directory: كان يعتمد على '/tmp' و pwd (يفشل على Windows فعليًا)", done: true },
        { id: "p2c-packaging-bug", label: "اكتشاف حقيقي: boltforge create فشلت فعليًا خارج المستودع (PathNotFoundException)", done: true },
        { id: "p2c-package-paths-rewrite", label: "إعادة كتابة PackagePaths باستخدام Isolate.resolvePackageUri بدل افتراض Platform.script", done: true },
        { id: "p2c-required-templatesroot", label: "templatesRoot أصبح إجباريًا في ProjectGenerator/FeatureGenerator (لا قيمة افتراضية داخلية)", done: true },
        { id: "p2c-exit-code-70", label: "إضافة رمز خروج 70 عند تعذّر تحديد templates/، بدل تسريب استثناء خام للمستخدم", done: true },
        { id: "p2c-package-paths-test", label: "test/package_paths_test.dart جديد — اختبار ارتداد حقيقي لهذا الخطأ بالذات", done: true },
        { id: "p2c-docs-updated-again", label: "تحديث templates.html, cli.html, troubleshooting.html, testing.html, README.md لتعكس الإصلاح", done: true },
        { id: "p2c-not-reverified", label: "لم يُعَد التحقق من هذا الإصلاح فعليًا (لا Dart SDK في بيئة البناء) — يحتاج تأكيد المستخدم", done: false, blocked: true },
      ],
    },
    {
      id: "phase3",
      title: "Phase 3 — GitHub / CI / الترخيص / pub.dev (قيد الإنجاز — الأغلبية اكتملت)",
      status: "in-progress",
      items: [
        { id: "p3-dart-tooling", label: "تشغيل فعلي حقيقي لـ dart format + dart analyze + dart test", done: true },
        { id: "p3-pubspec-readiness", label: "تنظيف pubspec.yaml: حذف recase غير المستخدَمة، إضافة topics، روابط alihossainhabib/boltforge الصحيحة", done: true },
        { id: "p3-license-file", label: "إنشاء ملف LICENSE فعلي (MIT، Ali Hussein Habib، 2026)", done: true },
        { id: "p3-changelog", label: "CHANGELOG.md لأول إصدار 0.1.0", done: true },
        { id: "p3-contributing-md", label: "CONTRIBUTING.md (ملف فعلي، منفصل عن docs/contributing.html)", done: true },
        { id: "p3-code-of-conduct", label: "CODE_OF_CONDUCT.md", done: true },
        { id: "p3-security-md", label: "SECURITY.md", done: true },
        { id: "p3-gitignore", label: ".gitignore مناسب لحزمة Dart", done: true },
        { id: "p3-example", label: "example/README.md بسيناريو استخدام حقيقي مُختبَر", done: true },
        { id: "p3-ci-workflow", label: ".github/workflows/ci.yml (format + analyze + test، على Ubuntu وWindows)", done: true },
        { id: "p3-issue-templates", label: ".github/ISSUE_TEMPLATE/ (bug_report, feature_request, config)", done: true },
        { id: "p3-pr-template", label: ".github/PULL_REQUEST_TEMPLATE.md", done: true },
        { id: "p3-readme-rewrite", label: "إعادة كتابة README.md: badges، ميزات، أمثلة حقيقية، إزالة تحذيرات لم تعد صحيحة", done: true },
        { id: "p3-docs-sync", label: "مزامنة docs/{publishing,contributing,license,testing}.html مع الحالة الفعلية", done: true },
        { id: "p3-github-repo", label: "إنشاء مستودع GitHub فعلي باسم alihossainhabib/boltforge", done: false },
        { id: "p3-release-workflow", label: ".github/workflows/release.yml (لم يُطلَب بعد ضمن هذه الجولة)", done: false },
        { id: "p3-pubdev-name", label: "التحقق من توفر اسم boltforge على pub.dev", done: false },
        { id: "p3-pubdev-dryrun", label: "dart pub publish --dry-run ناجح (سيُنفَّذه المطوّر بنفسه)", done: false, blocked: true },
        { id: "p3-pubdev-publish", label: "النشر الفعلي على pub.dev", done: false, blocked: true },
      ],
    },
  ];

  var TESTING_CHECKLIST = [
    { id: "t1", label: "Test 1 — boltforge create test_app ينتج مشروع Flutter صالح", state: "passed" },
    { id: "t2", label: "Test 2 — مصادقة بدون Password (OTP)", state: "passed" },
    { id: "t3", label: "Test 3 — مصادقة مع Password", state: "passed" },
    { id: "t4", label: "Test 4 — boltforge generate offer ينتج Feature كاملة", state: "passed" },
    { id: "t5", label: "Test 5 — تشغيل الأمر مرتين (Cancel/Overwrite/Merge)", state: "passed" },
    { id: "t6", label: "Test 6 — اسم Feature غير صالح", state: "passed" },
    { id: "t7", label: "Test 7 — تشغيل generate خارج مشروع Flutter", state: "passed" },
    { id: "t8", label: "Test 8 — flutter analyze (فعليًا على مشروع حقيقي)", state: "passed" },
    { id: "t9", label: "Test 9 — flutter test (فعليًا على مشروع حقيقي)", state: "passed" },
    { id: "t10", label: "Test 10 — التثبيت من pub.dev", state: "not-applicable" },
  ];

  var RELEASE_CHECKLIST = [
    { id: "r1", label: "dart format . بدون أي تغيير", done: true },
    { id: "r2", label: "dart analyze بدون أي تحذير", done: true },
    { id: "r3", label: "dart test ناجح بالكامل (152/152)", done: true },
    { id: "r4", label: "CHANGELOG.md محدَّث لرقم الإصدار", done: true },
    { id: "r5", label: "وسم Git (tag) مطابق لرقم الإصدار", done: false },
    { id: "r6", label: "التوثيق (docs/) يعكس آخر تغييرات السلوك", done: true },
  ];

  var GITHUB_CHECKLIST = [
    { id: "g1", label: "إنشاء المستودع على GitHub", done: false },
    { id: "g2", label: "دفع الكود الأولي (git push)", done: false },
    { id: "g3", label: "إضافة .github/workflows/ci.yml", done: true },
    { id: "g4", label: "إضافة .github/workflows/release.yml", done: false },
    { id: "g5", label: "قوالب Issue وPull Request", done: true },
    { id: "g6", label: "تفعيل GitHub Pages لعرض docs/ (اختياري)", done: false },
  ];

  var PUBDEV_CHECKLIST = [
    { id: "pd1", label: "تأكيد توفر اسم boltforge (بحث يدوي على pub.dev)", done: false },
    { id: "pd2", label: "ملء homepage/repository في pubspec.yaml برابط GitHub حقيقي", done: true },
    { id: "pd3", label: "dart pub publish --dry-run بدون أي تحذير", done: false },
    { id: "pd4", label: "النشر الفعلي: dart pub publish", done: false },
    { id: "pd5", label: "التحقق من عمل dart pub global activate boltforge من جهاز نظيف", done: false },
  ];

  var DOC_PAGES = [
    { num: "01", href: "doc/index.html", title: "الصفحة الرئيسية" },
    { num: "02", href: "doc/getting-started.html", title: "البدء السريع" },
    { num: "03", href: "doc/architecture.html", title: "المعمارية العامة" },
    { num: "04", href: "doc/cli.html", title: "أوامر الـ CLI" },
    { num: "05", href: "doc/project-generation.html", title: "إنشاء مشروع (create)" },
    { num: "06", href: "doc/authentication.html", title: "أنظمة تسجيل الدخول" },
    { num: "07", href: "doc/feature-generation.html", title: "توليد Feature (الدرس الكامل)" },
    { num: "08", href: "doc/templates.html", title: "نظام القوالب" },
    { num: "09", href: "doc/configuration.html", title: "الإعدادات" },
    { num: "10", href: "doc/testing.html", title: "الاختبارات" },
    { num: "11", href: "doc/troubleshooting.html", title: "استكشاف الأخطاء" },
    { num: "12", href: "doc/publishing.html", title: "النشر على pub.dev" },
    { num: "13", href: "doc/contributing.html", title: "المساهمة في المشروع" },
    { num: "14", href: "doc/license.html", title: "الترخيص" },
  ];

  var IMPORTANT_FILES = [
    { path: "bin/boltforge.dart", desc: "نقطة الدخول — تبني BoltforgeRunner وتشغّله" },
    { path: "lib/src/cli_runner.dart", desc: "تسجيل الأوامر الثلاثة: create, generate, doctor" },
    { path: "lib/src/core/package_paths.dart", desc: "يحدّد مكان templates/ فعليًا عبر Isolate.resolvePackageUri — مؤكَّد بتشغيل حقيقي خارج المستودع" },
    { path: "lib/src/generators/project_generator.dart", desc: "خط أنابيب إنشاء المشروع من 7 خطوات" },
    { path: "lib/src/generators/feature_generator.dart", desc: "توليد Feature داخل lib/features/ + تسجيل DI + تحقق" },
    { path: "lib/src/services/di_registrar.dart", desc: "تسجيل تلقائي وآمن للـ Repository في service_locator.dart (بدون تكرار) — مؤكَّد بتشغيل حقيقي" },
    { path: "lib/src/services/feature_validator.dart", desc: "تحقق بعد التوليد: ملفات ناقصة، tmpl متسرّب، placeholders، تسجيل مكرَّر" },
    { path: "test/", desc: "13 ملف اختبار — 152 اختبارًا، كلها ناجحة فعليًا" },
    { path: "LICENSE, CHANGELOG.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md", desc: "ملفات Open Source الأساسية — أُنشئت في Phase 3" },
    { path: ".github/workflows/ci.yml", desc: "format + analyze + test على Ubuntu وWindows" },
    { path: "example/README.md", desc: "مثال استخدام حقيقي مبني على سيناريو مُختبَر فعليًا" },
    { path: "PROJECT_STATE.json", desc: "مصدر الحقيقة الآلي لحالة المشروع" },
  ];

  var CLI_COMMANDS = [
    { cmd: "boltforge create my_app --auth=password", desc: "إنشاء مشروع بمصادقة كلمة مرور — مؤكَّد فعليًا" },
    { cmd: "boltforge create my_app --auth=otp", desc: "إنشاء مشروع بمصادقة رمز تحقق — مؤكَّد فعليًا" },
    { cmd: "boltforge generate offer", desc: "توليد Feature جديدة + تسجيل DI تلقائي — مؤكَّد فعليًا" },
    { cmd: "boltforge doctor", desc: "فحص بيئة العمل (Dart/Flutter)" },
    { cmd: "dart pub publish --dry-run", desc: "الخطوة التالية — سيُنفَّذها المطوّر بنفسه" },
  ];

  var KNOWN_ISSUES = [
    "لم يُنشأ مستودع GitHub فعلي بعد باسم alihossainhabib/boltforge — الروابط في pubspec.yaml/README جاهزة لكنها تفترض أن المطوّر سينشئه بهذا الاسم بالضبط.",
    "لم يُتحقَّق بعد من توفر اسم الحزمة boltforge على pub.dev — سيظهر ذلك مباشرة عند تشغيل dart pub publish --dry-run.",
    ".github/workflows/release.yml لم يُطلَب ولم يُنشأ في هذه الجولة — فقط ci.yml (format+analyze+test).",
    "بعض اختبارات process_service_test.dart (sh -c 'exit 7', ls --version) ما زالت تعتمد على أوامر Unix — لم تُبلَّغ كفاشلة فعليًا (نجحت ضمن الـ152 اختبارًا) فتُركت كما هي.",
    "تدفّق OTP يفترض عقدًا محددًا مع الخادم (accountExists ضمن استجابة requestOtp) — موثَّق لكن غير مُختبَر ضد Backend حقيقي مختلف.",
    "DiRegistrar يعتمد على تعليقَي ترسيخ نصيَّين وليس تحليل AST حقيقي — قرار مقصود وموثَّق.",
  ];

  var DECISIONS = [
    "اسم الحزمة: boltforge، حساب GitHub: alihossainhabib — الروابط في pubspec.yaml وREADME جُهِّزت بهذا الاسم دون افتراض أن المستودع أُنشئ فعليًا.",
    "لا اعتماد على go_router/auto_route — استخدام Navigator 1.0 (onGenerateRoute) لتقليل تبعيات المشروع المُولَّد.",
    "ملفات Feature المولَّدة تعيش في lib/features/<feature>/... تمامًا مثل تدفّق المصادقة — مسار موحَّد لكل الـ Features.",
    "حُذفت تبعية recase من pubspec.yaml لأنها غير مُستخدَمة إطلاقًا في الكود (تحقَّق منه بالبحث الكامل) — كانت ستُخفِّض نقاط pub.dev دون فائدة.",
    "قيد Dart SDK في pubspec.yaml هو '>=3.0.0 <4.0.0' — قرار المطوّر نفسه بعد اختبار حقيقي على Dart 3.2.6، ولم يُعدَّل لاحقًا لعدم وجود سبب تقني يستدعي رفعه.",
    "تسجيل DI التلقائي يستخدم تعليقات ترسيخ ثابتة (// boltforge:imports / // boltforge:registrations) بدل حزمة analyzer لتحليل AST.",
    "خطأ تحقق حقيقي (مثل تسجيل DI مكرَّر) يُنهي boltforge generate بالكود 1 حتى لو كُتبت كل الملفات بنجاح.",
    "تحديد مكان templates/ يعتمد على Isolate.resolvePackageUri بدل Platform.script — إصلاح لخطأ حزم حقيقي اكتُشف بتشغيل الأداة فعليًا خارج المستودع، ومؤكَّد لاحقًا بنجاح boltforge create من خارج المستودع.",
    "CI (ci.yml) يُشغَّل على مصفوفة Ubuntu + Windows تحديدًا بسبب تاريخ هذا المشروع مع خطأ ظهر فقط على Windows — لا نكرر ثقة زائفة بنجاح الاختبار على منصة واحدة فقط.",
    "لم يُنشأ .github/workflows/release.yml في هذه الجولة — لم يُطلَب صراحةً، ويُفضَّل تصميمه بعد أول نشر فعلي على pub.dev ليعكس عملية إصدار حقيقية بدل تخمين شكلها مسبقًا.",
  ];

  // ---------------------------------------------------------------
  // State persistence
  // ---------------------------------------------------------------

  function loadState() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      return {};
    }
  }

  var state = loadState();
  var saveTimer = null;

  function saveState() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      flashSaveIndicator();
    } catch (e) {
      /* localStorage unavailable (private mode, quota) — fail silently,
         the dashboard still works for the current session. */
    }
  }

  function flashSaveIndicator() {
    var el = document.getElementById("save-indicator");
    if (!el) return;
    el.classList.add("show");
    clearTimeout(saveTimer);
    saveTimer = setTimeout(function () { el.classList.remove("show"); }, 900);
  }

  function itemChecked(id, defaultDone) {
    if (Object.prototype.hasOwnProperty.call(state, id) && "checked" in state[id]) {
      return state[id].checked;
    }
    return !!defaultDone;
  }

  function itemNote(id) {
    return (state[id] && state[id].note) || "";
  }

  function setChecked(id, checked) {
    state[id] = state[id] || {};
    state[id].checked = checked;
    saveState();
  }

  function setNote(id, note) {
    state[id] = state[id] || {};
    state[id].note = note;
    saveState();
  }

  // ---------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------

  function renderChecklist(items, opts) {
    opts = opts || {};
    var html = '<ul class="checklist">';
    items.forEach(function (item) {
      var checked = itemChecked(item.id, item.done);
      var note = itemNote(item.id);
      var blocked = item.blocked ? " state-blocked" : "";
      html += '<li class="checklist-item' + (checked ? " checked" : "") + blocked + '" data-item-id="' + item.id + '">';
      html += '<input type="checkbox" ' + (checked ? "checked" : "") + ' aria-label="' + escapeHtml(item.label) + '">';
      html += '<div class="item-body">';
      html += '<div class="item-label-row" style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">';
      html += '<span class="item-label">' + escapeHtml(item.label) + '</span>';
      if (item.blocked) html += '<span class="status-pill blocked">محجوب</span>';
      html += '</div>';
      if (opts.notes) {
        html += '<textarea class="item-note" placeholder="ملاحظة شخصية (تُحفظ تلقائيًا)…">' + escapeHtml(note) + '</textarea>';
      }
      html += '</div></li>';
    });
    html += '</ul>';
    return html;
  }

  function renderTestingChecklist(items) {
    var labels = { traced: "تم تتبّعه يدويًا", "not-applicable": "غير قابل للتطبيق الآن", passed: "نجح فعليًا", failed: "فشل" };
    var html = '<ul class="checklist">';
    items.forEach(function (item) {
      var stored = state[item.id];
      var currentState = (stored && stored.testState) || item.state;
      html += '<li class="checklist-item" data-item-id="' + item.id + '">';
      html += '<div class="item-body">';
      html += '<div style="display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;">';
      html += '<span class="item-label">' + escapeHtml(item.label) + '</span>';
      html += '<select class="test-state-select" data-item-id="' + item.id + '" style="background:var(--bg-elevated);color:var(--text);border:1px solid var(--border);border-radius:6px;padding:4px 8px;font-family:var(--font-ar);font-size:12.5px;">';
      ["traced", "passed", "failed", "not-applicable"].forEach(function (s) {
        html += '<option value="' + s + '"' + (s === currentState ? " selected" : "") + '>' + labels[s] + '</option>';
      });
      html += '</select></div></div></li>';
    });
    html += '</ul>';
    return html;
  }

  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function countProgress(items) {
    var total = items.length;
    var done = items.filter(function (i) { return itemChecked(i.id, i.done); }).length;
    return { done: done, total: total, pct: total ? Math.round((done / total) * 100) : 0 };
  }

  function renderProgressBar(pct, small) {
    return '<div class="progress-track"><div class="progress-fill' + (small ? " small" : "") + '" style="width:' + pct + '%"></div></div>';
  }

  // ---------------------------------------------------------------
  // Page assembly
  // ---------------------------------------------------------------

  function overallStats() {
    var allItems = [];
    PHASES.forEach(function (ph) { allItems = allItems.concat(ph.items); });
    return countProgress(allItems);
  }

  function buildOverviewTab() {
    var stats = overallStats();
    var currentPhase = PHASES.find(function (p) { return p.status === "in-progress"; }) || PHASES[PHASES.length - 1];

    var html = '<div class="dashboard-header">';
    html += '<div><div class="eyebrow">مركز تحكم المشروع</div><h1>boltforge</h1>';
    html += '<p class="lede" style="margin-bottom:6px">أداة CLI لتوليد مشاريع Flutter وFeatures بمعمارية Cubit + Repository + GetIt.</p></div>';
    html += '<div style="text-align:left"><span id="save-indicator" class="save-indicator">✓ تم الحفظ</span></div>';
    html += '</div>';

    html += '<div class="stat-grid">';
    html += '<div class="stat-card"><div class="stat-value">' + stats.pct + '%</div><div class="stat-label">التقدّم الإجمالي (كل المراحل)</div></div>';
    html += '<div class="stat-card"><div class="stat-value">' + currentPhase.title.split("—")[0].trim() + '</div><div class="stat-label">المرحلة الحالية</div></div>';
    html += '<div class="stat-card"><div class="stat-value">' + stats.done + ' / ' + stats.total + '</div><div class="stat-label">عناصر مكتملة</div></div>';
    html += '<div class="stat-card"><div class="stat-value">14</div><div class="stat-label">صفحة توثيق عربية</div></div>';
    html += '</div>';
    html += renderProgressBar(stats.pct);

    html += '<h2 style="margin-top:36px">الخطوة الحالية بالضبط</h2>';
    html += '<p>' + "تم تأكيد التحقق الفعلي الكامل: dart analyze نظيف، dart test ناجح (152/152)، وboltforge create/generate يعملان فعليًا من خارج المستودع (Password وOTP، إعادة تشغيل generate، Cancel/Overwrite/Merge) — كل ذلك على جهاز حقيقي. الآن قيد الإنجاز: Phase 3 (تجهيز open-source: LICENSE، CHANGELOG، CONTRIBUTING، CI عبر GitHub Actions، قوالب Issue/PR، README نهائي). أُنجزت كل هذه الملفات؛ ما تبقّى: إنشاء مستودع GitHub فعلي، وتشغيل dart pub publish --dry-run (سيُنفَّذه المطوّر بنفسه)، ثم قرار النشر النهائي." + '</p>';

    html += '<div class="callout warn"><div class="callout-title">⚠ أهم عنصر معلَّق</div><p style="margin:0">تشغيل حقيقي لـ <code>dart pub get &amp;&amp; dart format . &amp;&amp; dart analyze &amp;&amp; dart test</code> — لم يحدث هذا فعليًا بعد في تاريخ المشروع كله.</p></div>';

    html += '<h2>المعمارية باختصار</h2>';
    html += '<div class="tree">bin/boltforge.dart → lib/src/cli_runner.dart → {create, generate, doctor}\n' +
      'commands/ → generators/ (ProjectGenerator, FeatureGenerator)\n' +
      'generators/ → services/ (ProcessService, FileService, ProjectDetector)\n' +
      'generators/ → template_engine/ → templates/{base, auth/*, feature/*}</div>';
    html += '<p><a href="docs/architecture.html">التفاصيل الكاملة في صفحة المعمارية ←</a></p>';

    html += '<h2>أوامر CLI الأساسية</h2>';
    CLI_COMMANDS.forEach(function (c) {
      html += '<div class="filename-tag">' + escapeHtml(c.desc) + '</div><pre><code>' + escapeHtml(c.cmd) + '</code></pre>';
    });

    html += '<h2>ملفات مهمّة</h2><table><tr><th>الملف</th><th>الوصف</th></tr>';
    IMPORTANT_FILES.forEach(function (f) {
      html += '<tr><td><code>' + escapeHtml(f.path) + '</code></td><td>' + escapeHtml(f.desc) + '</td></tr>';
    });
    html += '</table>';

    html += '<h2>مشاكل معروفة</h2><ul>';
    KNOWN_ISSUES.forEach(function (k) { html += '<li>' + escapeHtml(k) + '</li>'; });
    html += '</ul>';

    html += '<h2>قرارات تصميمية</h2><ul>';
    DECISIONS.forEach(function (d) { html += '<li>' + escapeHtml(d) + '</li>'; });
    html += '</ul>';

    html += '<h2>روابط التوثيق</h2><div class="doc-link-grid">';
    DOC_PAGES.forEach(function (d) {
      html += '<a class="doc-link-card" href="' + d.href + '"><span class="doc-num">' + d.num + '</span><br>' + escapeHtml(d.title) + '</a>';
    });
    html += '</div>';

    return html;
  }

  function buildPhasesTab() {
    var html = "";
    PHASES.forEach(function (phase) {
      var stats = countProgress(phase.items);
      var statusLabel = phase.status === "done" ? "مكتملة" : phase.status === "in-progress" ? "قيد التنفيذ" : "لم تبدأ";
      html += '<div class="section-title-row"><h2>' + phase.title + ' <span class="tag">' + statusLabel + '</span></h2>';
      html += '<div class="mini-progress">' + stats.done + '/' + stats.total + renderProgressBar(stats.pct, true) + '</div></div>';
      html += renderChecklist(phase.items, { notes: true });
    });
    return html;
  }

  function buildTestingTab() {
    var html = '<div class="eyebrow">قائمة القبول</div><h1>الاختبارات</h1>';
    html += '<p class="lede">قائمة الاختبارات العشرة الأصلية المطلوبة لقبول الأداة، وحالتها الفعلية.</p>';
    html += '<div class="callout error"><div class="callout-title">✖ صريح</div><p style="margin:0">"تم تتبّعه يدويًا" تعني: تحقّقتُ من الكود بالقراءة والمطابقة المباشرة، وليس بتشغيل حقيقي. راجع <a href="docs/testing.html">صفحة الاختبارات</a> للتفاصيل الكاملة.</p></div>';
    html += renderTestingChecklist(TESTING_CHECKLIST);
    return html;
  }

  function buildChecklistsTab() {
    var html = '<div class="eyebrow">قوائم المراجعة</div><h1>الإصدار / GitHub / pub.dev</h1>';

    var r = countProgress(RELEASE_CHECKLIST);
    html += '<div class="section-title-row"><h2>قائمة مراجعة الإصدار (Release)</h2><div class="mini-progress">' + r.done + '/' + r.total + renderProgressBar(r.pct, true) + '</div></div>';
    html += renderChecklist(RELEASE_CHECKLIST, { notes: true });

    var g = countProgress(GITHUB_CHECKLIST);
    html += '<div class="section-title-row"><h2>قائمة مراجعة GitHub</h2><div class="mini-progress">' + g.done + '/' + g.total + renderProgressBar(g.pct, true) + '</div></div>';
    html += renderChecklist(GITHUB_CHECKLIST, { notes: true });

    var pd = countProgress(PUBDEV_CHECKLIST);
    html += '<div class="section-title-row"><h2>قائمة مراجعة pub.dev</h2><div class="mini-progress">' + pd.done + '/' + pd.total + renderProgressBar(pd.pct, true) + '</div></div>';
    html += renderChecklist(PUBDEV_CHECKLIST, { notes: true });

    return html;
  }

  var TABS = [
    { id: "overview", label: "نظرة عامة", build: buildOverviewTab },
    { id: "phases", label: "المراحل والتقدّم", build: buildPhasesTab },
    { id: "testing", label: "الاختبارات", build: buildTestingTab },
    { id: "checklists", label: "قوائم المراجعة", build: buildChecklistsTab },
  ];

  function attachChecklistHandlers(container) {
    container.querySelectorAll(".checklist-item").forEach(function (li) {
      var id = li.dataset.itemId;
      var checkbox = li.querySelector('input[type="checkbox"]');
      if (checkbox) {
        checkbox.addEventListener("change", function () {
          setChecked(id, checkbox.checked);
          li.classList.toggle("checked", checkbox.checked);
          refreshProgressUI();
        });
      }
      var note = li.querySelector(".item-note");
      if (note) {
        note.addEventListener("input", function () {
          setNote(id, note.value);
        });
      }
    });
    container.querySelectorAll(".test-state-select").forEach(function (sel) {
      sel.addEventListener("change", function () {
        var id = sel.dataset.itemId;
        state[id] = state[id] || {};
        state[id].testState = sel.value;
        saveState();
      });
    });
  }

  function refreshProgressUI() {
    // Re-render the active tab so stats/progress bars stay in sync.
    var activeTabBtn = document.querySelector(".tab-btn.active");
    if (activeTabBtn) renderTab(activeTabBtn.dataset.tabId, true);
  }

  function renderTab(tabId, keepScroll) {
    var tab = TABS.find(function (t) { return t.id === tabId; });
    if (!tab) return;
    var panel = document.getElementById("tab-panel");
    var scrollY = window.scrollY;
    panel.innerHTML = tab.build();
    attachChecklistHandlers(panel);
    addCopyButtons(panel);
    if (keepScroll) window.scrollTo(0, scrollY);
    document.querySelectorAll(".tab-btn").forEach(function (b) {
      b.classList.toggle("active", b.dataset.tabId === tabId);
    });
    location.hash = tabId;
  }

  function buildTabBar() {
    var bar = document.getElementById("tab-bar");
    var html = "";
    TABS.forEach(function (t) {
      html += '<button class="tab-btn" type="button" data-tab-id="' + t.id + '">' + t.label + "</button>";
    });
    bar.innerHTML = html;
    bar.querySelectorAll(".tab-btn").forEach(function (btn) {
      btn.addEventListener("click", function () { renderTab(btn.dataset.tabId); });
    });
  }

  function addCopyButtons(root) {
    (root || document).querySelectorAll("pre").forEach(function (pre) {
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
          setTimeout(function () { btn.textContent = "نسخ"; btn.classList.remove("copied"); }, 1600);
        });
      });
      pre.style.position = "relative";
      pre.insertBefore(btn, pre.firstChild);
    });
  }

  function setupSearch() {
    var search = document.getElementById("dashboard-search");
    search.addEventListener("input", function () {
      var q = search.value.trim().toLowerCase();
      var panel = document.getElementById("tab-panel");
      panel.querySelectorAll(".checklist-item, tr").forEach(function (el) {
        var text = el.textContent.toLowerCase();
        el.style.display = !q || text.indexOf(q) !== -1 ? "" : "none";
      });
    });
  }

  function setupReset() {
    document.getElementById("reset-btn").addEventListener("click", function () {
      if (!confirm("سيتم مسح كل ما حفظته من علامات وملاحظات في هذه اللوحة محليًا. متابعة؟")) return;
      localStorage.removeItem(STORAGE_KEY);
      state = {};
      refreshProgressUI();
    });
  }

  function mobileToggle() {
    // Dashboard has no sidebar (tab-based), nothing to toggle — kept as
    // a no-op hook in case a sidebar is added later.
  }

  document.addEventListener("DOMContentLoaded", function () {
    buildTabBar();
    setupSearch();
    setupReset();
    var initialTab = (location.hash || "#overview").replace("#", "");
    if (!TABS.find(function (t) { return t.id === initialTab; })) initialTab = "overview";
    renderTab(initialTab);
  });
})();
