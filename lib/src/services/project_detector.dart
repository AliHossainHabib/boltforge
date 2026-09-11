import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class ProjectDetectionResult {
  final bool isFlutterProject;
  final String? packageName;
  final String? reason;

  const ProjectDetectionResult._({
    required this.isFlutterProject,
    this.packageName,
    this.reason,
  });

  factory ProjectDetectionResult.found(String packageName) =>
      ProjectDetectionResult._(
          isFlutterProject: true, packageName: packageName);

  factory ProjectDetectionResult.notFound(String reason) =>
      ProjectDetectionResult._(isFlutterProject: false, reason: reason);
}

/// Confirms `boltforge generate <feature>` is being run from the root of a
/// real Flutter project before writing anything to `lib/`.
class ProjectDetector {
  ProjectDetectionResult detect(Directory workingDirectory) {
    final pubspecFile = File(p.join(workingDirectory.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return ProjectDetectionResult.notFound(
        'No pubspec.yaml found in ${workingDirectory.path}.',
      );
    }

    final libDir = Directory(p.join(workingDirectory.path, 'lib'));
    if (!libDir.existsSync()) {
      return ProjectDetectionResult.notFound(
        'pubspec.yaml was found, but there is no lib/ directory — '
        'this does not look like a Dart/Flutter project.',
      );
    }

    late final YamlMap doc;
    try {
      doc = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    } catch (e) {
      return ProjectDetectionResult.notFound(
        'pubspec.yaml exists but could not be parsed: $e',
      );
    }

    final dependsOnFlutter = doc['dependencies'] is YamlMap &&
        (doc['dependencies'] as YamlMap).containsKey('flutter');
    if (!dependsOnFlutter) {
      return ProjectDetectionResult.notFound(
        'pubspec.yaml does not depend on the flutter SDK — '
        'this looks like a plain Dart package, not a Flutter app.',
      );
    }

    final packageName = doc['name']?.toString();
    if (packageName == null || packageName.isEmpty) {
      return ProjectDetectionResult.notFound(
        'pubspec.yaml has no "name" field.',
      );
    }

    return ProjectDetectionResult.found(packageName);
  }
}
