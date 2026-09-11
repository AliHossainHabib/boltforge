# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-09

Initial release.

### Added

- **`boltforge create <name>`** — scaffolds a new Flutter project:
  - Runs `flutter create`, then adds `flutter_bloc`, `bloc`, `dio`, `get_it`,
    and `shared_preferences` via `flutter pub add`.
  - Applies a base architecture under `lib/core/`: a `GetIt` service
    locator, a `Dio` client with a Token → Retry → ErrorMapper interceptor
    chain, an `ApiResult<T>` / `ApiError` contract, a lightweight
    `Navigator`-based router, shared loading/error/empty widgets, and
    reusable form widgets.
  - `--auth=password`: generates a login / register / forgot-password flow.
  - `--auth=otp`: generates an email-or-phone verification flow that only
    asks for a name when the identifier is new.
  - Runs `flutter pub get`, `flutter analyze`, and `flutter test`, and
    reports the first real failure instead of claiming success.
- **`boltforge generate <name>`** — generates a feature
  (`cubit`, `repository`, `model`, `presentation/{screen,widgets}`) under
  `lib/features/<name>/` inside an existing project, following the same
  Cubit + Repository conventions as the rest of the app.
  - Automatically registers the new repository into
    `lib/core/di/service_locator.dart` (import + `registerLazySingleton`),
    with no duplicate imports or registrations on repeated runs.
  - Prompts to cancel, overwrite, or merge when the feature already exists.
  - Validates the result after generation: missing files, leaked `.tmpl`
    files, unresolved template placeholders, and missing or duplicated DI
    registrations are reported, with a non-zero exit code on real errors.
- **`boltforge doctor`** — checks that Dart and Flutter are available.
- Backend-agnostic networking: `ApiConstants.baseUrl` and endpoint paths
  are left for the user to fill in; nothing assumes a specific backend.
- Package resource resolution (`lib/src/core/package_paths.dart`) via
  `Isolate.resolvePackageUri`, correct whether boltforge is run from
  source, via a cached `dart pub global activate` snapshot, or once
  installed from pub.dev.
- Full documentation site under `docs/` (in Arabic; code, commands, and
  file names stay in English), and an interactive, `localStorage`-backed
  `project-dashboard.html`.
- A test suite covering the template engine, name casing/validation, file
  generation with conflict handling, DI registration, post-generation
  validation, process execution, and the CLI commands themselves.

[0.1.0]: https://github.com/alihossainhabib/boltforge/releases/tag/v0.1.0
