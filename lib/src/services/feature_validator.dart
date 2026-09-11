import 'dart:io';
import 'package:path/path.dart' as p;

enum ValidationSeverity { error, warning }

class ValidationIssue {
  final ValidationSeverity severity;
  final String message;
  const ValidationIssue(this.severity, this.message);

  @override
  String toString() =>
      '[${severity == ValidationSeverity.error ? "ERROR" : "WARNING"}] $message';
}

class FeatureValidationResult {
  final List<ValidationIssue> issues;
  const FeatureValidationResult(this.issues);

  bool get isValid =>
      !issues.any((i) => i.severity == ValidationSeverity.error);
  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();
}

/// Runs after a feature is generated to catch exactly the class of bugs
/// this generator has actually had in the past (a leaked `.tmpl` suffix,
/// an unrendered `{{placeholder}}`, a DI registration that silently
/// didn't happen or happened twice) — this is a safety net on top of,
/// not a replacement for, `TemplateEngine` throwing on unknown variables
/// at render time.
class FeatureValidator {
  const FeatureValidator();

  FeatureValidationResult validate({
    required Directory destinationRoot,
    required String featureNameSnake,
    required List<String> expectedRelativePaths,
    required File serviceLocatorFile,
    required String repositoryClassName,
    required String repositoryImportPath,
  }) {
    final issues = <ValidationIssue>[];

    for (final relative in expectedRelativePaths) {
      final file = File(p.join(destinationRoot.path, relative));
      if (!file.existsSync()) {
        issues.add(ValidationIssue(
          ValidationSeverity.error,
          'Expected generated file is missing: $relative',
        ));
      }
    }

    final featureDir =
        Directory(p.join(destinationRoot.path, featureNameSnake));
    if (featureDir.existsSync()) {
      for (final entity in featureDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.tmpl')) {
          issues.add(ValidationIssue(
            ValidationSeverity.error,
            'Leaked .tmpl file (should have been rendered and renamed): '
            '${p.relative(entity.path, from: destinationRoot.path)}',
          ));
          continue;
        }
        final content = entity.readAsStringSync();
        if (content.contains('{{')) {
          issues.add(ValidationIssue(
            ValidationSeverity.error,
            'Unresolved template placeholder found in: '
            '${p.relative(entity.path, from: destinationRoot.path)}',
          ));
        }
      }
    }

    if (!serviceLocatorFile.existsSync()) {
      issues.add(ValidationIssue(
        ValidationSeverity.warning,
        'lib/core/di/service_locator.dart not found — could not verify or '
        'register $repositoryClassName. Register it there manually.',
      ));
    } else {
      final content = serviceLocatorFile.readAsStringSync();

      final registrationCount = _countOccurrences(
          content, 'registerLazySingleton<$repositoryClassName>');
      if (registrationCount == 0) {
        issues.add(ValidationIssue(
          ValidationSeverity.warning,
          '$repositoryClassName is not registered in service_locator.dart. '
          'Add: sl.registerLazySingleton<$repositoryClassName>(() => $repositoryClassName());',
        ));
      } else if (registrationCount > 1) {
        issues.add(ValidationIssue(
          ValidationSeverity.error,
          'Duplicate DI registration for $repositoryClassName found '
          '$registrationCount times in service_locator.dart.',
        ));
      }

      final importCount =
          _countOccurrences(content, "import '$repositoryImportPath';");
      if (importCount > 1) {
        issues.add(ValidationIssue(
          ValidationSeverity.error,
          'Duplicate import of $repositoryImportPath found $importCount '
          'times in service_locator.dart.',
        ));
      }
    }

    return FeatureValidationResult(issues);
  }

  int _countOccurrences(String haystack, String needle) {
    if (needle.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while (true) {
      final found = haystack.indexOf(needle, index);
      if (found == -1) break;
      count++;
      index = found + needle.length;
    }
    return count;
  }
}
