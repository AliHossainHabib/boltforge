import 'dart:io';

import 'package:boltforge/src/generators/feature_generator.dart';
import 'package:boltforge/src/services/di_registrar.dart';
import 'package:boltforge/src/services/feature_validator.dart';
import 'package:boltforge/src/services/file_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The real bundled templates/ directory. `dart test` is required to be
/// run from the package root (it locates pubspec.yaml/test/ that way),
/// so `Directory.current` reliably *is* the package root. This is a
/// simpler, synchronous alternative to `PackagePaths.resolveTemplatesRoot`
/// for tests — that resolver now works correctly under `dart test` too
/// (see `test/package_paths_test.dart`), but tests here inject a known
/// directory directly to keep setup synchronous and independent of it.
Directory get _realTemplatesRoot =>
    Directory(p.join(Directory.current.path, 'templates'));

/// A minimal but realistic `service_locator.dart`, matching what
/// `ProjectGenerator` actually produces from
/// `templates/base/lib/core/di/service_locator.dart.tmpl` — including the
/// two marker comments `DiRegistrar` relies on. Tests in this file build
/// a bare temp "project" (no real `flutter create` run), so this stands
/// in for the file `create` would have generated.
String _fakeServiceLocatorContent() => '''
import 'package:get_it/get_it.dart';

import '../../features/auth/repository/auth_repository.dart';
// boltforge:imports

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  // boltforge:registrations
}
''';

void main() {
  late Directory tempProject;
  late File serviceLocatorFile;

  setUp(() {
    tempProject =
        Directory.systemTemp.createTempSync('boltforge_feature_gen_test_');
    Directory(p.join(tempProject.path, 'lib')).createSync(recursive: true);
    serviceLocatorFile = File(
      p.join(tempProject.path, 'lib', 'core', 'di', 'service_locator.dart'),
    )..createSync(recursive: true);
    serviceLocatorFile.writeAsStringSync(_fakeServiceLocatorContent());
  });

  tearDown(() {
    if (tempProject.existsSync()) tempProject.deleteSync(recursive: true);
  });

  test(
      'the real templates/feature directory exists (sanity check for other tests)',
      () {
    expect(_realTemplatesRoot.existsSync(), isTrue,
        reason: 'Expected to find templates/ next to pubspec.yaml. '
            'Run `dart test` from the boltforge package root.');
    expect(Directory(p.join(_realTemplatesRoot.path, 'feature')).existsSync(),
        isTrue);
  });

  group('FeatureGenerator.generate — new feature', () {
    late FeatureGenerationResult result;
    late Directory featuresDir;

    setUp(() {
      final generator = FeatureGenerator(
        onExistingFeature: (_) =>
            fail('should not prompt for a brand new feature'),
        templatesRoot: _realTemplatesRoot,
      );
      result = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );
      featuresDir = Directory(p.join(tempProject.path, 'lib', 'features'));
    });

    test('is not cancelled, reports written files, and is valid', () {
      expect(result.wasCancelled, isFalse);
      expect(result.writtenFiles, isNotEmpty);
      expect(result.skippedExistingFiles, isEmpty);
      expect(result.isValid, isTrue,
          reason: result.validationIssues.map((i) => i.toString()).join('; '));
    });

    test('creates the expected directory structure under lib/features/offer',
        () {
      expect(
          File(p.join(featuresDir.path, 'offer', 'model', 'offer_model.dart'))
              .existsSync(),
          isTrue);
      expect(
        File(p.join(featuresDir.path, 'offer', 'repository',
                'offer_repository.dart'))
            .existsSync(),
        isTrue,
      );
      expect(
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_cubit.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_state.dart'))
              .existsSync(),
          isTrue);
      expect(
        File(p.join(featuresDir.path, 'offer', 'presentation', 'screen',
                'offer_screen.dart'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
          featuresDir.path,
          'offer',
          'presentation',
          'widgets',
          'offer_list_item.dart',
        )).existsSync(),
        isTrue,
        reason:
            'presentation/widgets/ must contain a real generated widget, not stay empty',
      );
    });

    test('does not leak any .tmpl suffix onto disk', () {
      final leftoverTmplFiles = featuresDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmpl'));
      expect(leftoverTmplFiles, isEmpty);
    });

    test(
        'does not leave any unrendered {{ }} placeholder in any generated file',
        () {
      final allFiles = featuresDir.listSync(recursive: true).whereType<File>();
      for (final file in allFiles) {
        expect(file.readAsStringSync(), isNot(contains('{{')),
            reason: '${file.path} still contains an unrendered placeholder');
      }
    });

    test('renders correct PascalCase class names into generated code', () {
      final model =
          File(p.join(featuresDir.path, 'offer', 'model', 'offer_model.dart'))
              .readAsStringSync();
      expect(model, contains('class OfferModel'));

      final repository = File(p.join(
              featuresDir.path, 'offer', 'repository', 'offer_repository.dart'))
          .readAsStringSync();
      expect(repository, contains('class OfferRepository'));

      final cubit =
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_cubit.dart'))
              .readAsStringSync();
      expect(cubit, contains('class OfferCubit extends Cubit<OfferState>'));

      final state =
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_state.dart'))
              .readAsStringSync();
      expect(state, contains('sealed class OfferState'));
      expect(state, contains('class OfferLoaded extends OfferState'));

      final screen = File(
        p.join(featuresDir.path, 'offer', 'presentation', 'screen',
            'offer_screen.dart'),
      ).readAsStringSync();
      expect(screen, contains('class OfferScreen extends StatelessWidget'));

      final listItem = File(p.join(
        featuresDir.path,
        'offer',
        'presentation',
        'widgets',
        'offer_list_item.dart',
      )).readAsStringSync();
      expect(listItem, contains('class OfferListItem extends StatelessWidget'));
    });

    test(
        'generated cubit imports its own state, model, and repository files correctly',
        () {
      final cubit =
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_cubit.dart'))
              .readAsStringSync();
      expect(cubit, contains("part 'offer_state.dart';"));
      expect(cubit, contains("import '../model/offer_model.dart';"));
      expect(cubit, contains("import '../repository/offer_repository.dart';"));
    });

    test('generated state file declares itself as part of the cubit file', () {
      final state =
          File(p.join(featuresDir.path, 'offer', 'cubit', 'offer_state.dart'))
              .readAsStringSync();
      expect(state, contains("part of 'offer_cubit.dart';"));
    });

    test('generated screen imports resolve to the correct relative depth', () {
      final screen = File(
        p.join(featuresDir.path, 'offer', 'presentation', 'screen',
            'offer_screen.dart'),
      ).readAsStringSync();
      // lib/features/offer/presentation/screen/ -> lib/core/ is four levels up.
      expect(screen,
          contains("import '../../../../core/di/service_locator.dart';"));
      expect(screen,
          contains("import '../../../../core/ui/feedback/feedback.dart';"));
      // -> lib/features/offer/cubit/, repository/, presentation/widgets/ are within the feature.
      expect(screen, contains("import '../../cubit/offer_cubit.dart';"));
      expect(
          screen, contains("import '../../repository/offer_repository.dart';"));
      expect(screen, contains("import '../widgets/offer_list_item.dart';"));
    });

    test('generated repository imports resolve to the correct relative depth',
        () {
      final repository = File(p.join(
              featuresDir.path, 'offer', 'repository', 'offer_repository.dart'))
          .readAsStringSync();
      // lib/features/offer/repository/ -> lib/core/ is three levels up.
      expect(repository,
          contains("import '../../../core/network/api_result.dart';"));
      expect(repository,
          contains("import '../../../core/network/dio_client.dart';"));
      expect(repository, contains("import '../model/offer_model.dart';"));
    });

    test(
        'generated widget imports the feature model at the correct relative depth',
        () {
      final listItem = File(p.join(
        featuresDir.path,
        'offer',
        'presentation',
        'widgets',
        'offer_list_item.dart',
      )).readAsStringSync();
      expect(listItem, contains("import '../../model/offer_model.dart';"));
    });

    test(
        'screen uses the generated OfferListItem widget instead of a bare ListTile',
        () {
      final screen = File(
        p.join(featuresDir.path, 'offer', 'presentation', 'screen',
            'offer_screen.dart'),
      ).readAsStringSync();
      expect(screen, contains('OfferListItem('));
    });
  });

  group('FeatureGenerator.generate — automatic DI registration', () {
    test('adds the import and registration to service_locator.dart', () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      final result = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );

      expect(result.diResult, isNotNull);
      expect(result.diResult!.status, DiRegistrationStatus.registered);
      expect(result.diResult!.importAdded, isTrue);
      expect(result.diResult!.registrationAdded, isTrue);

      final content = serviceLocatorFile.readAsStringSync();
      expect(
        content,
        contains(
            "import '../../features/offer/repository/offer_repository.dart';"),
      );
      expect(
        content,
        contains(
            'sl.registerLazySingleton<OfferRepository>(() => OfferRepository());'),
      );
    });

    test(
        'does not remove or duplicate the pre-existing AuthRepository registration',
        () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      final content = serviceLocatorFile.readAsStringSync();
      final authOccurrences =
          'registerLazySingleton<AuthRepository>'.allMatches(content).length;
      expect(authOccurrences, 1);
      expect(
          content,
          contains(
              "import '../../features/auth/repository/auth_repository.dart';"));
    });

    test(
        'keeps both markers in the file after insertion, so a second feature can still be added',
        () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      final content = serviceLocatorFile.readAsStringSync();
      expect(content, contains(DiRegistrar.importMarker));
      expect(content, contains(DiRegistrar.registrationMarker));
    });

    test('generating a second feature appends without disturbing the first',
        () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');
      generator.generate(
          projectRoot: tempProject,
          featureName: 'payment',
          packageName: 'my_app');

      final content = serviceLocatorFile.readAsStringSync();
      expect(content, contains('registerLazySingleton<OfferRepository>'));
      expect(content, contains('registerLazySingleton<PaymentRepository>'));
      expect(content, contains('registerLazySingleton<AuthRepository>'));
      // Each exactly once.
      expect(
          'registerLazySingleton<OfferRepository>'.allMatches(content).length,
          1);
      expect(
          'registerLazySingleton<PaymentRepository>'.allMatches(content).length,
          1);
    });

    test(
        're-generating the same feature (overwrite) does not duplicate the DI registration',
        () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => ConflictAction.overwrite,
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');
      final second = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );

      expect(second.diResult!.alreadyPresent, isTrue);
      final content = serviceLocatorFile.readAsStringSync();
      expect(
          'registerLazySingleton<OfferRepository>'.allMatches(content).length,
          1);
      expect(
        "import '../../features/offer/repository/offer_repository.dart';"
            .allMatches(content)
            .length,
        1,
      );
    });

    test('reports fileMissing when service_locator.dart does not exist', () {
      serviceLocatorFile.deleteSync();
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      final result = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );

      expect(result.diResult!.status, DiRegistrationStatus.fileMissing);
      // Missing DI file is a warning, not a hard failure of generation.
      expect(result.isValid, isTrue);
      expect(
        result.validationIssues.any((i) =>
            i.severity == ValidationSeverity.warning &&
            i.message.contains('service_locator.dart')),
        isTrue,
      );
    });

    test('reports markersMissing and leaves a hand-edited file untouched', () {
      const handEdited = '''
import 'package:get_it/get_it.dart';
final GetIt sl = GetIt.instance;
void configureDependencies() {
  // no boltforge markers here — developer removed them
}
''';
      serviceLocatorFile.writeAsStringSync(handEdited);

      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      final result = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );

      expect(result.diResult!.status, DiRegistrationStatus.markersMissing);
      expect(serviceLocatorFile.readAsStringSync(), handEdited,
          reason: 'a file without markers must never be modified');
    });
  });

  group('FeatureGenerator.generate — post-generation validation', () {
    test('flags a duplicate DI registration as an error', () {
      // Pre-seed a duplicate registration to simulate corruption/manual
      // editing that happened before boltforge ran.
      serviceLocatorFile.writeAsStringSync('''
import 'package:get_it/get_it.dart';

import '../../features/auth/repository/auth_repository.dart';
import '../../features/offer/repository/offer_repository.dart';
// boltforge:imports

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<OfferRepository>(() => OfferRepository());
  sl.registerLazySingleton<OfferRepository>(() => OfferRepository());
  // boltforge:registrations
}
''');
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      final result = generator.generate(
        projectRoot: tempProject,
        featureName: 'offer',
        packageName: 'my_app',
      );

      expect(result.isValid, isFalse);
      expect(
        result.validationIssues.any((i) =>
            i.severity == ValidationSeverity.error &&
            i.message.contains('Duplicate DI registration')),
        isTrue,
      );
    });

    test('flags a missing expected file as an error', () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      // Simulate an external process deleting a generated file right
      // after generation, before validation would normally run — here we
      // just re-run validate() directly against the now-incomplete tree.
      final modelFile = File(p.join(
        tempProject.path,
        'lib',
        'features',
        'offer',
        'model',
        'offer_model.dart',
      ));
      modelFile.deleteSync();

      const validator = FeatureValidator();
      final validation = validator.validate(
        destinationRoot: Directory(p.join(tempProject.path, 'lib', 'features')),
        featureNameSnake: 'offer',
        expectedRelativePaths: [p.join('offer', 'model', 'offer_model.dart')],
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        repositoryImportPath:
            '../../features/offer/repository/offer_repository.dart',
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.issues.any((i) =>
            i.severity == ValidationSeverity.error &&
            i.message.contains('missing')),
        isTrue,
      );
    });

    test('flags a leaked .tmpl file as an error', () {
      final featureDir = Directory(p.join(
        tempProject.path,
        'lib',
        'features',
        'offer',
      ))
        ..createSync(recursive: true);
      File(p.join(featureDir.path, 'stray.dart.tmpl'))
          .writeAsStringSync('// oops');

      const validator = FeatureValidator();
      final validation = validator.validate(
        destinationRoot: Directory(p.join(tempProject.path, 'lib', 'features')),
        featureNameSnake: 'offer',
        expectedRelativePaths: const [],
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        repositoryImportPath:
            '../../features/offer/repository/offer_repository.dart',
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.issues.any((i) => i.message.contains('Leaked .tmpl file')),
        isTrue,
      );
    });

    test('flags an unresolved placeholder as an error', () {
      final featureDir = Directory(p.join(
        tempProject.path,
        'lib',
        'features',
        'offer',
        'model',
      ))
        ..createSync(recursive: true);
      File(p.join(featureDir.path, 'offer_model.dart'))
          .writeAsStringSync('class OfferModel { String x = "{{oops}}"; }');

      const validator = FeatureValidator();
      final validation = validator.validate(
        destinationRoot: Directory(p.join(tempProject.path, 'lib', 'features')),
        featureNameSnake: 'offer',
        expectedRelativePaths: const [],
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        repositoryImportPath:
            '../../features/offer/repository/offer_repository.dart',
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.issues
            .any((i) => i.message.contains('Unresolved template placeholder')),
        isTrue,
      );
    });

    test('warns (not errors) when the repository is not yet registered', () {
      // service_locator.dart exists with markers but no Offer registration.
      const validator = FeatureValidator();
      final validation = validator.validate(
        destinationRoot: Directory(p.join(tempProject.path, 'lib', 'features')),
        featureNameSnake: 'offer',
        expectedRelativePaths: const [],
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        repositoryImportPath:
            '../../features/offer/repository/offer_repository.dart',
      );

      expect(validation.isValid, isTrue,
          reason: 'a missing registration is a warning, not an error');
      expect(
        validation.issues.any((i) =>
            i.severity == ValidationSeverity.warning &&
            i.message.contains('not registered')),
        isTrue,
      );
    });
  });

  group('FeatureGenerator.generate — multi-word feature name casing', () {
    test(
        'converts a snake_case feature name to Pascal/camel consistently across files',
        () {
      final generator = FeatureGenerator(
        onExistingFeature: (_) => fail('should not prompt'),
        templatesRoot: _realTemplatesRoot,
      );
      generator.generate(
        projectRoot: tempProject,
        featureName: 'user_profile',
        packageName: 'my_app',
      );

      final featuresDir =
          Directory(p.join(tempProject.path, 'lib', 'features'));
      expect(
        File(p.join(featuresDir.path, 'user_profile', 'model',
                'user_profile_model.dart'))
            .existsSync(),
        isTrue,
      );
      final model = File(
        p.join(featuresDir.path, 'user_profile', 'model',
            'user_profile_model.dart'),
      ).readAsStringSync();
      expect(model, contains('class UserProfileModel'));

      final screen = File(p.join(
        featuresDir.path,
        'user_profile',
        'presentation',
        'screen',
        'user_profile_screen.dart',
      )).readAsStringSync();
      expect(screen, contains('class UserProfileScreen'));
      expect(screen, contains("Text('User Profile')"));

      final content = serviceLocatorFile.readAsStringSync();
      expect(content, contains('registerLazySingleton<UserProfileRepository>'));
      expect(
        content,
        contains(
            "import '../../features/user_profile/repository/user_profile_repository.dart';"),
      );
    });
  });

  group('FeatureGenerator.generate — duplicate feature handling', () {
    void generateOnce(Directory projectRoot) {
      FeatureGenerator(
        onExistingFeature: (_) => fail('first generation must not conflict'),
        templatesRoot: _realTemplatesRoot,
      ).generate(
          projectRoot: projectRoot,
          featureName: 'offer',
          packageName: 'my_app');
    }

    test('prompts via onExistingFeature when the feature already exists', () {
      generateOnce(tempProject);

      var wasPrompted = false;
      FeatureGenerator(
        onExistingFeature: (name) {
          wasPrompted = true;
          expect(name, 'offer');
          return ConflictAction.cancel;
        },
        templatesRoot: _realTemplatesRoot,
      ).generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      expect(wasPrompted, isTrue);
    });

    test(
        'cancel leaves every existing file byte-for-byte untouched and does not touch DI',
        () {
      generateOnce(tempProject);
      final modelFile = File(
        p.join(tempProject.path, 'lib', 'features', 'offer', 'model',
            'offer_model.dart'),
      );
      modelFile.writeAsStringSync('// hand-edited by the developer\n');
      final beforeModel = modelFile.readAsStringSync();
      final beforeDi = serviceLocatorFile.readAsStringSync();

      final result = FeatureGenerator(
        onExistingFeature: (_) => ConflictAction.cancel,
        templatesRoot: _realTemplatesRoot,
      ).generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      expect(result.wasCancelled, isTrue);
      expect(result.writtenFiles, isEmpty);
      expect(result.diResult, isNull);
      expect(modelFile.readAsStringSync(), beforeModel);
      expect(serviceLocatorFile.readAsStringSync(), beforeDi);
    });

    test('overwrite replaces every existing file with freshly rendered content',
        () {
      generateOnce(tempProject);
      final modelFile = File(
        p.join(tempProject.path, 'lib', 'features', 'offer', 'model',
            'offer_model.dart'),
      );
      modelFile.writeAsStringSync('// hand-edited, should be replaced\n');

      final result = FeatureGenerator(
        onExistingFeature: (_) => ConflictAction.overwrite,
        templatesRoot: _realTemplatesRoot,
      ).generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      expect(result.wasCancelled, isFalse);
      expect(modelFile.readAsStringSync(), contains('class OfferModel'));
      expect(modelFile.readAsStringSync(), isNot(contains('hand-edited')));
    });

    test('merge keeps hand-edited files but still writes any missing file', () {
      generateOnce(tempProject);
      final modelFile = File(
        p.join(tempProject.path, 'lib', 'features', 'offer', 'model',
            'offer_model.dart'),
      );
      modelFile.writeAsStringSync('// hand-edited, must survive merge\n');
      // Simulate a partially-deleted feature: remove the screen file so
      // merge has something legitimate to (re)create.
      final screenFile = File(p.join(
        tempProject.path,
        'lib',
        'features',
        'offer',
        'presentation',
        'screen',
        'offer_screen.dart',
      ));
      screenFile.deleteSync();

      final result = FeatureGenerator(
        onExistingFeature: (_) => ConflictAction.merge,
        templatesRoot: _realTemplatesRoot,
      ).generate(
          projectRoot: tempProject,
          featureName: 'offer',
          packageName: 'my_app');

      expect(result.wasCancelled, isFalse);
      expect(
          modelFile.readAsStringSync(), '// hand-edited, must survive merge\n');
      expect(screenFile.existsSync(), isTrue);
      expect(screenFile.readAsStringSync(), contains('class OfferScreen'));
    });
  });
}
