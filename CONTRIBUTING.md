# Contributing to boltforge

Thanks for considering a contribution. boltforge is a Dart CLI tool, so
contributing to it looks like contributing to any Dart package — clone,
install the SDK, run the tests.

For the fuller, example-driven version of everything below (including a
complete walkthrough of adding a new feature generator or a new auth
mode), see [`docs/contributing.html`](doc/contributing.html) and the
rest of the [documentation site](doc/index.html).

## Getting set up

You need the Dart SDK (Flutter's bundled Dart SDK works fine too, since
boltforge only depends on core Dart packages).

```bash
git clone https://github.com/alihossainhabib/boltforge.git
cd boltforge
dart pub get
```

To try your local changes as the real `boltforge` command:

```bash
dart pub global activate --source path .
boltforge doctor
```

## Before you open a pull request

```bash
dart format .
dart analyze
dart test
```

All three must be clean. CI runs the same three commands on both Ubuntu
and Windows, so a change that only works on one platform will be caught.

## Architectural rules this project relies on

These aren't style preferences — the test suite and the generated
projects depend on them:

1. **Only `Repository` classes are registered in `GetIt`.** Cubits are
   created per-screen via `BlocProvider`, never registered in
   `service_locator.dart`.
2. **Every external process call goes through `ProcessService`.** Never
   call `Process.run` directly from a command or generator — it makes the
   code untestable without a real Flutter/Dart install on the test
   machine.
3. **Every generator/command that reads `templates/` accepts an
   injectable `templatesRoot`.** Production code resolves it via
   `PackagePaths.resolveTemplatesRoot()`; tests pass a known directory
   directly. See `lib/src/core/package_paths.dart` for why this matters —
   it's the fix for a real packaging bug that only showed up when running
   the installed CLI outside the repository.
4. **No silent overwrites.** Any operation that could clobber an existing
   file goes through the cancel/overwrite/merge `ConflictAction` pattern.
5. **A missing template variable is a hard error, not an empty string.**
   `TemplateEngine` throws `TemplateVariableError` on purpose — don't
   catch it to paper over a typo'd placeholder.

## Tests

Every test in `test/` verifies something real — actual generated files,
actual directory structure, actual process output — not just "did it
throw". If you change behavior, add or update a test that would have
caught the change; don't just update an assertion to match new output
without checking the new output is actually correct.

`test/support/fake_process_service.dart` is the pattern to follow for
anything that would otherwise need a real Flutter install to test.

## Reporting bugs / requesting features

Use the GitHub issue templates — they ask for exactly what's needed to
reproduce a CLI bug (OS, Dart/Flutter version, exact command, full
output).

## Security issues

Please don't open a public issue for a security concern — see
[`SECURITY.md`](SECURITY.md).
