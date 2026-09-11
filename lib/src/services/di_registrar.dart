import 'dart:io';

/// Outcome of attempting to register a repository in `service_locator.dart`.
enum DiRegistrationStatus {
  /// Import and/or registration were added (or were already both present —
  /// see [DiRegistrationResult.alreadyPresent] to distinguish).
  registered,

  /// `service_locator.dart` does not exist at the expected path at all —
  /// most likely `generate` was run against a project not scaffolded by
  /// `boltforge create` (or `lib/core/di/` was renamed/removed).
  fileMissing,

  /// The file exists but is missing one or both of the
  /// `// boltforge:imports` / `// boltforge:registrations` marker
  /// comments boltforge relies on to insert safely. This happens if a
  /// developer manually rewrote the file. boltforge never guesses at an
  /// insertion point in that case — it leaves the file untouched.
  markersMissing,
}

/// What actually happened to the file, independent of [status] —
/// `registered` covers both "freshly added" and "was already there",
/// and callers (tests, CLI output) usually care which.
class DiRegistrationResult {
  final DiRegistrationStatus status;
  final bool importAdded;
  final bool registrationAdded;

  const DiRegistrationResult({
    required this.status,
    this.importAdded = false,
    this.registrationAdded = false,
  });

  /// True if both the import and the registration were already present
  /// before this call — i.e. nothing changed (safe to call repeatedly).
  bool get alreadyPresent =>
      status == DiRegistrationStatus.registered &&
      !importAdded &&
      !registrationAdded;
}

/// Edits `lib/core/di/service_locator.dart` to register a newly generated
/// feature's repository, using two stable marker comments
/// (`// boltforge:imports` and `// boltforge:registrations`) baked into
/// the template as insertion points — deliberately not a Dart AST parse,
/// since the file's shape is one boltforge itself controls and a plain,
/// auditable string insertion is easier to reason about and test than a
/// parser dependency.
class DiRegistrar {
  static const importMarker = '// boltforge:imports';
  static const registrationMarker = '// boltforge:registrations';

  const DiRegistrar();

  DiRegistrationResult registerRepository({
    required File serviceLocatorFile,
    required String repositoryClassName,
    required String importPath,
  }) {
    if (!serviceLocatorFile.existsSync()) {
      return const DiRegistrationResult(
          status: DiRegistrationStatus.fileMissing);
    }

    var content = serviceLocatorFile.readAsStringSync();
    if (!content.contains(importMarker) ||
        !content.contains(registrationMarker)) {
      return const DiRegistrationResult(
          status: DiRegistrationStatus.markersMissing);
    }

    final importLine = "import '$importPath';";
    final alreadyImported = content.contains(importLine);

    // Matched without the trailing "();" so formatting differences (extra
    // whitespace, trailing comma) don't cause a false "not registered".
    final registrationNeedle = 'registerLazySingleton<$repositoryClassName>';
    final alreadyRegistered = content.contains(registrationNeedle);

    if (alreadyImported && alreadyRegistered) {
      return const DiRegistrationResult(
          status: DiRegistrationStatus.registered);
    }

    var importAdded = false;
    if (!alreadyImported) {
      content = content.replaceFirst(
        importMarker,
        '$importLine\n$importMarker',
      );
      importAdded = true;
    }

    var registrationAdded = false;
    if (!alreadyRegistered) {
      final registrationLine =
          'sl.registerLazySingleton<$repositoryClassName>(() => $repositoryClassName());';
      content = content.replaceFirst(
        registrationMarker,
        '$registrationLine\n  $registrationMarker',
      );
      registrationAdded = true;
    }

    serviceLocatorFile.writeAsStringSync(content);
    return DiRegistrationResult(
      status: DiRegistrationStatus.registered,
      importAdded: importAdded,
      registrationAdded: registrationAdded,
    );
  }
}
