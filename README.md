# boltforge

[![CI](https://github.com/alihossainhabib/boltforge/actions/workflows/ci.yml/badge.svg)](https://github.com/alihossainhabib/boltforge/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/boltforge.svg)](https://pub.dev/packages/boltforge)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A CLI that scaffolds production-ready Flutter projects — Cubit +
Repository + GetIt architecture, a wired authentication flow, and a
feature generator that wires itself into dependency injection
automatically — so every project your team starts looks the same on day
one, and every feature you add afterward follows the same pattern without
manual wiring.

## What is boltforge?

Two commands. `boltforge create` turns an empty directory into a working
Flutter app with a real architecture already in place — networking,
error handling, DI, routing, and a complete login flow. `boltforge
generate` adds a new feature (cubit, repository, model, screen) to that
app later, on demand, wired into the same DI container automatically.

It is deliberately backend-agnostic: nothing it generates assumes
Node.js, Firebase, Laravel, or any specific backend — you fill in one
constant (`ApiConstants.baseUrl`) and it works with any REST API.

## Features

- **`boltforge create <name>`** — Flutter project scaffolding with a
  Cubit + Repository + GetIt architecture, a Dio client with a
  Token → Retry → ErrorMapper interceptor chain, and a wired
  authentication flow: `--auth=password` (login/register/forgot-password)
  or `--auth=otp` (email/phone verification, account creation only for
  new identifiers).
- **`boltforge generate <name>`** — adds a feature
  (`lib/features/<name>/{cubit,repository,model,presentation}`) to an
  existing project and **registers its repository into
  `lib/core/di/service_locator.dart` automatically** — no manual DI edit,
  no duplicate registrations even if you run it twice.
- **Post-generation validation** — every `generate` run checks for
  missing files, leaked template files, unresolved placeholders, and
  missing/duplicate DI registrations, and reports real errors with a
  non-zero exit code instead of a silent false "success".
- **`boltforge doctor`** — confirms Dart and Flutter are set up correctly.
- **Safe by default** — no file is ever silently overwritten; conflicting
  generation always asks to cancel, overwrite, or merge.
- A [14-page documentation site](doc/index.html) (in Arabic; code and
  commands stay in English) and an interactive
  [project dashboard](project-dashboard.html).

## Install

```bash
dart pub global activate boltforge
```

## Usage

```bash
# Create a new project (interactive auth prompt if --auth is omitted)
boltforge create my_app
boltforge create my_app --auth=password
boltforge create my_app --auth=otp

# Generate a feature inside an existing boltforge project
cd my_app
boltforge generate offer

# Check your environment
boltforge doctor
```

### A complete example

```bash
$ boltforge create shop_app --auth=password
boltforge — creating "shop_app"

  → Creating Flutter project "shop_app"
  ✔ Flutter project scaffolded
  → Adding required dependencies
  ✔ Dependencies added to pubspec.yaml
  → Applying base architecture
  ✔ Base architecture applied (core/ layer)
  → Configuring authentication (password)
  ✔ Authentication flow generated (password)
  → Installing dependencies
  ✔ Dependencies installed
  → Validating generated code (flutter analyze)
  ✔ No analysis issues found
  → Running tests
  ✔ Tests passed

Project created successfully!
cd shop_app && flutter run

$ cd shop_app && boltforge generate offer
boltforge — generating feature "offer"

  ✔ Wrote lib/features/offer/model/offer_model.dart
  ✔ Wrote lib/features/offer/repository/offer_repository.dart
  ✔ Wrote lib/features/offer/cubit/offer_state.dart
  ✔ Wrote lib/features/offer/cubit/offer_cubit.dart
  ✔ Wrote lib/features/offer/presentation/screen/offer_screen.dart
  ✔ Wrote lib/features/offer/presentation/widgets/offer_list_item.dart

  ✔ DI: registered the repository in lib/core/di/service_locator.dart automatically.

Feature "offer" generated.
```

See [`example/`](example/README.md) for the full walkthrough, including
what to do next (pointing the project at a real backend).

## What `create` does

1. Validates the project name.
2. Runs `flutter create`.
3. Adds `flutter_bloc`, `bloc`, `dio`, `get_it`, `shared_preferences` via
   `flutter pub add`.
4. Applies the base architecture (`lib/core/...`): Dio client with a
   Token → Retry → ErrorMapper interceptor chain, an `ApiResult<T>` /
   `ApiError` contract, a `GetIt` service locator, a lightweight
   `Navigator`-based router, shared loading/error/empty widgets, and a
   couple of reusable form widgets.
5. Applies your chosen authentication flow — `--auth=password` (login,
   register, forgot password) or `--auth=otp` (email/phone verification,
   with account creation only when the identifier is new).
6. Runs `flutter pub get`, `flutter analyze`, and `flutter test`, and
   **stops and reports honestly** if any step fails — it will not tell
   you the project was created successfully if `flutter analyze` found
   problems.

## What `generate` does

Inside an existing project, `boltforge generate <name>` writes
`lib/features/<name>/{cubit,repository,model,presentation/{screen,widgets}}`
with real, compiling starter code (not empty files), following the same
Cubit + Repository conventions as the rest of the app. It then:

- **Automatically registers the new repository** in
  `lib/core/di/service_locator.dart` — adding the import and a
  `sl.registerLazySingleton<XRepository>(() => XRepository());` line, with
  no duplicate imports or registrations even if you run it again. This
  works by inserting before two stable marker comments
  (`// boltforge:imports` / `// boltforge:registrations`) baked into the
  generated `service_locator.dart` — if those markers are missing (e.g.
  you hand-rewrote the file), boltforge leaves it untouched and tells you
  to register the repository yourself, rather than guessing.
- **Validates the result**: checks every expected file was written, that
  no `.tmpl` suffix leaked onto disk, that no `{{placeholder}}` was left
  unresolved, and that the DI registration exists exactly once (not zero,
  not more than one). Problems are printed as errors (exit code `1`) or
  warnings (exit code `0`, but flagged) — never silently swallowed.

If the feature already exists, you're prompted to cancel, overwrite, or
merge (write only the files that don't already exist); DI registration is
similarly idempotent, so re-running `generate` never produces a duplicate
entry.

## Backend-agnostic by design

Nothing in the generated project assumes a specific backend. Set
`ApiConstants.baseUrl` and the endpoint paths in
`lib/core/constants/api_constants.dart` to point at your Node.js,
Firebase, Laravel, Django, or any REST backend — the `ApiResult<T>` /
`ApiError` contract and the Dio interceptor chain don't change.

## Architecture of this repository

```
bin/boltforge.dart          Entry point
lib/
  boltforge.dart             Tiny public barrel — also the resolution
                             target PackagePaths uses to find the
                             package root reliably (see below)
  src/
    cli_runner.dart          CommandRunner wiring
    commands/                create / generate / doctor
    generators/              ProjectGenerator, FeatureGenerator (orchestration)
    core/package_paths.dart  Resolves templates/ correctly whether run
                             from source, a cached pub-global snapshot,
                             or an installed pub.dev package
    services/                ProcessService, FileService, ProjectDetector,
                             DiRegistrar, FeatureValidator
    template_engine/         {{variable}} + {{#if}} rendering
    utils/                   NameCase, Logger
    validators/              NameValidator
templates/
  base/                      Core architecture applied to every project
                             (service_locator.dart.tmpl includes the DI
                             marker comments FeatureGenerator relies on)
  auth/{password,otp}/       Authentication flow variants
  feature/{{featureName}}/   Feature generator template (generates into
                             lib/features/<name>/, same convention as
                             the auth flow)
docs/                        14-page Arabic documentation site
project-dashboard.html       Interactive project control center
```

## Template resolution (read this if you're modifying `templates/`)

`boltforge create`/`generate` need to find the bundled `templates/`
directory at runtime — a non-Dart resource outside `lib/`. This is
**not** as simple as "look next to the running script": when boltforge is
activated globally (`dart pub global activate`), Dart caches a compiled
snapshot one directory level *deeper* than `bin/boltforge.dart`
(`.dart_tool/pub/bin/boltforge/boltforge.dart-<sdk>.snapshot`), which
broke exactly that assumption in an earlier version — `boltforge create`
would fail with a `PathNotFoundException` the moment it was run from
outside the repository, i.e. the way real users actually run it. This has
been fixed and confirmed working with a real `boltforge create` run
outside the repository (see `CHANGELOG.md`).

`lib/src/core/package_paths.dart` resolves `templates/` via
`Isolate.resolvePackageUri('package:boltforge/boltforge.dart')` — the
same mechanism Dart itself uses to make every `import 'package:boltforge/...'`
in this program work at all, so it's correct regardless of how the
program was invoked. `ProjectGenerator`/`FeatureGenerator` require
`templatesRoot` as an explicit constructor parameter (no internal
default); `CreateCommand`/`GenerateCommand` resolve it once, `async`,
before constructing the generator, and fail clearly (exit code `70`)
rather than surface a raw filesystem exception if it can't be found.
Tests pass a known directory directly — see `test/package_paths_test.dart`
for a regression test proving the resolver actually finds the real
`templates/` tree.

## Testing

```bash
dart pub get
dart format .
dart analyze
dart test
```

The test suite verifies real generated files, directory structure, and
process behavior — not just "did it throw". CI runs the same three
commands on both Ubuntu and Windows.

## Documentation

Full documentation (in Arabic; code/commands/filenames stay in English)
lives under `docs/` — start at `docs/index.html`. `project-dashboard.html`
is a live, localStorage-backed project control center with phase
checklists, testing status, and release/GitHub/pub.dev checklists.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md). Security issues should be reported
per [`SECURITY.md`](SECURITY.md), not as a public issue.

## License

MIT — see [`LICENSE`](LICENSE).
