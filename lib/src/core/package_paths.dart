import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;

/// Locates the `templates/` directory bundled with the boltforge package —
/// a non-Dart resource that lives outside `lib/`, which Dart has no single
/// built-in "just give me my package root" API for.
///
/// **Why this is harder than it looks, and what actually broke:**
/// `Platform.script` only reliably points at `bin/boltforge.dart` when the
/// program is run directly from source (`dart bin/boltforge.dart` or
/// `dart run boltforge`). When a package is activated globally
/// (`dart pub global activate [--source path] boltforge`), pub compiles
/// and caches a kernel snapshot under
/// `<package>/.dart_tool/pub/bin/boltforge/boltforge.dart-<sdk>.snapshot`
/// — **one directory level deeper** than `bin/`. The old implementation's
/// "package root is always one level above the script" assumption was
/// therefore wrong specifically for the exact way real users run this
/// tool, and it resolved `templates/` to a nonexistent path nested inside
/// `.dart_tool/pub/bin/` instead of the real repository root. This is not
/// a hypothetical: it's exactly the `PathNotFoundException` seen when
/// running the globally-activated `boltforge` executable outside the
/// repository.
///
/// **The fix:** [Isolate.resolvePackageUri] is the mechanism Dart itself
/// uses to turn a `package:boltforge/...` import into a real file path —
/// every `import 'package:boltforge/...'` anywhere in this program already
/// depends on that resolution working correctly, regardless of whether the
/// program is running from source, from a cached JIT snapshot (the
/// pub-global-activate case that broke), or (once published) from
/// `~/.pub-cache/global_packages/boltforge/`. Resolving
/// `package:boltforge/boltforge.dart` and taking its parent's parent
/// directory gives the true package root in every one of those cases,
/// because it relies on the same package-resolution metadata the Dart VM
/// itself must already have correct to run this program at all — not on
/// guessing from the entrypoint script's path.
///
/// [Platform.script]-based resolution is kept only as a last-resort
/// fallback for unusual embeddings where isolate package resolution is
/// unavailable, and even then only trusted if a `templates/` directory
/// actually exists at the guessed location.
class PackagePaths {
  /// Resolves the `templates/` directory. Returns null if it could not be
  /// located by any strategy — callers must handle this explicitly (with
  /// a clear error) rather than assume it always succeeds.
  static Future<Directory?> resolveTemplatesRoot() async {
    final root = await _resolvePackageRoot();
    if (root == null) return null;
    final templates = Directory(p.join(root.path, 'templates'));
    return templates.existsSync() ? templates : null;
  }

  static Future<Directory?> _resolvePackageRoot() async {
    final fromPackageConfig = await _resolveViaPackageConfig();
    if (fromPackageConfig != null) return fromPackageConfig;

    return _resolveViaScriptPath();
  }

  /// Primary strategy: ask the Dart VM's own package resolver where
  /// `package:boltforge/` actually lives on disk.
  static Future<Directory?> _resolveViaPackageConfig() async {
    try {
      final libUri = await Isolate.resolvePackageUri(
        Uri.parse('package:boltforge/boltforge.dart'),
      );
      if (libUri == null) return null;

      // package:boltforge/boltforge.dart -> <root>/lib/boltforge.dart
      final libDir = Directory(p.dirname(libUri.toFilePath()));
      final root = Directory(p.normalize(p.join(libDir.path, '..')));
      final templatesDir = Directory(p.join(root.path, 'templates'));
      return templatesDir.existsSync() ? root : null;
    } catch (_) {
      // Package resolution can throw in unusual embeddings (e.g. no
      // package_config available at all) — fall through to strategy 2.
      return null;
    }
  }

  /// Fallback strategy: the historical assumption that the running
  /// script sits at `<root>/bin/<something>`. Correct when running
  /// directly from source; kept only as a safety net, and only trusted
  /// if a `templates/` directory is actually found there — never
  /// returned blindly.
  static Directory? _resolveViaScriptPath() {
    final scriptDir = Directory(p.dirname(p.fromUri(Platform.script)));
    final guessedRoot = Directory(p.normalize(p.join(scriptDir.path, '..')));
    return Directory(p.join(guessedRoot.path, 'templates')).existsSync()
        ? guessedRoot
        : null;
  }
}
