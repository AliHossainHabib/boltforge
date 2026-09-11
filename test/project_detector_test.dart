import 'dart:io';

import 'package:boltforge/src/services/project_detector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('boltforge_project_detector_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('detects a valid Flutter project and extracts its package name', () {
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
description: A test app.
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');
    Directory(p.join(tempDir.path, 'lib')).createSync();

    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isTrue);
    expect(result.packageName, 'my_app');
  });

  test('rejects a directory with no pubspec.yaml at all', () {
    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isFalse);
    expect(result.reason, contains('pubspec.yaml'));
  });

  test('rejects a directory with pubspec.yaml but no lib/', () {
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isFalse);
    expect(result.reason, contains('lib'));
  });

  test('rejects a plain Dart package (no flutter dependency)', () {
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_package
dependencies:
  path: ^1.9.0
''');
    Directory(p.join(tempDir.path, 'lib')).createSync();

    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isFalse);
    expect(result.reason, contains('flutter'));
  });

  test('rejects a pubspec.yaml with no name field', () {
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
dependencies:
  flutter:
    sdk: flutter
''');
    Directory(p.join(tempDir.path, 'lib')).createSync();

    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isFalse);
    expect(result.reason, contains('name'));
  });

  test('rejects a pubspec.yaml that fails to parse as YAML', () {
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies: [flutter
''');
    Directory(p.join(tempDir.path, 'lib')).createSync();

    final result = ProjectDetector().detect(tempDir);

    expect(result.isFlutterProject, isFalse);
    expect(result.reason, contains('could not be parsed'));
  });
}
