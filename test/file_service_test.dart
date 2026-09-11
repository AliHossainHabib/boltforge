import 'dart:io';

import 'package:boltforge/src/services/file_service.dart';
import 'package:boltforge/src/template_engine/template_context.dart';
import 'package:boltforge/src/template_engine/template_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Builds a small throwaway template tree:
///
///   <root>/{{featureName}}/model/{{featureName}}_model.dart.tmpl
///   <root>/{{featureName}}/cubit/{{featureName}}_cubit.dart.tmpl
///
/// so tests exercise real placeholder rendering in both file *content*
/// and file/directory *names*, without depending on the real
/// templates/feature tree.
Directory _buildSampleTemplate(Directory parent) {
  final root = Directory(p.join(parent.path, 'sample_template'))
    ..createSync(recursive: true);

  final modelDir = Directory(p.join(root.path, '{{featureName}}', 'model'))
    ..createSync(recursive: true);
  File(p.join(modelDir.path, '{{featureName}}_model.dart.tmpl'))
      .writeAsStringSync('class {{featureNamePascal}}Model {}\n');

  final cubitDir = Directory(p.join(root.path, '{{featureName}}', 'cubit'))
    ..createSync(recursive: true);
  File(p.join(cubitDir.path, '{{featureName}}_cubit.dart.tmpl'))
      .writeAsStringSync('class {{featureNamePascal}}Cubit {}\n');

  return root;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('boltforge_file_service_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  TemplateEngine engineFor(String featureName) {
    return TemplateEngine(TemplateContext.forFeature(
      featureName: featureName,
      packageName: 'my_app',
    ));
  }

  group('FileService.planOutputPaths', () {
    test('reports rendered relative paths without touching disk', () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final planned = service.planOutputPaths(templateRoot);

      expect(
        planned,
        containsAll([
          p.join('offer', 'model', 'offer_model.dart'),
          p.join('offer', 'cubit', 'offer_cubit.dart'),
        ]),
      );
      // Nothing should exist on disk yet.
      expect(destination.existsSync(), isFalse);
    });
  });

  group('FileService.renderTree', () {
    test('writes rendered content and rendered file/directory names', () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final written = service.renderTree(
        templateRoot: templateRoot,
        destinationRoot: destination,
        onConflict: ConflictAction.overwrite,
      );

      expect(written, hasLength(2));

      final modelFile =
          File(p.join(destination.path, 'offer', 'model', 'offer_model.dart'));
      final cubitFile =
          File(p.join(destination.path, 'offer', 'cubit', 'offer_cubit.dart'));

      expect(modelFile.existsSync(), isTrue);
      expect(cubitFile.existsSync(), isTrue);
      expect(modelFile.readAsStringSync(), 'class OfferModel {}\n');
      expect(cubitFile.readAsStringSync(), 'class OfferCubit {}\n');

      // .tmpl suffix must not leak onto disk.
      expect(
          File(p.join(
                  destination.path, 'offer', 'model', 'offer_model.dart.tmpl'))
              .existsSync(),
          isFalse);
    });

    test('overwrite conflict action replaces existing file content', () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final modelFile =
          File(p.join(destination.path, 'offer', 'model', 'offer_model.dart'))
            ..createSync(recursive: true);
      modelFile.writeAsStringSync('// hand-edited, should be replaced\n');

      service.renderTree(
        templateRoot: templateRoot,
        destinationRoot: destination,
        onConflict: ConflictAction.overwrite,
      );

      expect(modelFile.readAsStringSync(), 'class OfferModel {}\n');
    });

    test('merge conflict action keeps existing files untouched', () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final modelFile =
          File(p.join(destination.path, 'offer', 'model', 'offer_model.dart'))
            ..createSync(recursive: true);
      modelFile.writeAsStringSync('// hand-edited, must survive merge\n');

      final written = service.renderTree(
        templateRoot: templateRoot,
        destinationRoot: destination,
        onConflict: ConflictAction.merge,
      );

      // Only the cubit file (which didn't exist) should have been written.
      expect(written, hasLength(1));
      expect(
          modelFile.readAsStringSync(), '// hand-edited, must survive merge\n');

      final cubitFile =
          File(p.join(destination.path, 'offer', 'cubit', 'offer_cubit.dart'));
      expect(cubitFile.existsSync(), isTrue);
      expect(cubitFile.readAsStringSync(), 'class OfferCubit {}\n');
    });

    test('cancel conflict action writes nothing at all, even new files', () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final written = service.renderTree(
        templateRoot: templateRoot,
        destinationRoot: destination,
        onConflict: ConflictAction.cancel,
      );

      expect(written, isEmpty);
      expect(destination.existsSync(), isFalse);
    });

    test('cancel conflict action does not modify a pre-existing file either',
        () {
      final templateRoot = _buildSampleTemplate(tempDir);
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      final modelFile =
          File(p.join(destination.path, 'offer', 'model', 'offer_model.dart'))
            ..createSync(recursive: true);
      modelFile.writeAsStringSync('untouched\n');

      service.renderTree(
        templateRoot: templateRoot,
        destinationRoot: destination,
        onConflict: ConflictAction.cancel,
      );

      expect(modelFile.readAsStringSync(), 'untouched\n');
      // The cubit file must not have appeared either.
      expect(
          File(p.join(destination.path, 'offer', 'cubit', 'offer_cubit.dart'))
              .existsSync(),
          isFalse);
    });

    test(
        'throws TemplateVariableError and writes nothing from that file if a placeholder is unknown',
        () {
      final root = Directory(p.join(tempDir.path, 'broken_template'))
        ..createSync(recursive: true);
      File(p.join(root.path, 'broken.dart.tmpl'))
          .writeAsStringSync('{{doesNotExist}}');
      final destination = Directory(p.join(tempDir.path, 'lib'));
      final service = FileService(engineFor('offer'));

      expect(
        () => service.renderTree(
          templateRoot: root,
          destinationRoot: destination,
          onConflict: ConflictAction.overwrite,
        ),
        throwsA(isA<TemplateVariableError>()),
      );
    });
  });
}
