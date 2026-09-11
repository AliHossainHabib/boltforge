import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:boltforge/src/commands/create_command.dart';
import 'package:boltforge/src/commands/generate_command.dart';
import 'package:boltforge/src/services/file_service.dart';
import 'package:boltforge/src/services/process_service.dart';
import 'package:boltforge/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fake_process_service.dart';

Logger _testLogger() => Logger(colorEnabled: false);

/// See feature_generator_test.dart for why `Directory.current` is a safe
/// stand-in for the package root under `dart test`.
Directory get _realTemplatesRoot =>
    Directory(p.join(Directory.current.path, 'templates'));

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('boltforge_cli_commands_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('CreateCommand — argument and input validation', () {
    Future<int> runCreate(List<String> args, {ProcessService? process}) {
      final runner = CommandRunner<int>('boltforge', 'test runner')
        ..addCommand(CreateCommand(
          logger: _testLogger(),
          process: process ?? FakeProcessService(),
          workingDirectory: tempDir,
          templatesRoot: _realTemplatesRoot,
        ));
      return runner.run(['create', ...args]).then((code) => code ?? 0);
    }

    test('returns exit code 64 when the project name is missing', () async {
      final code = await runCreate([]);
      expect(code, 64);
    });

    test('returns exit code 64 for a project name with uppercase letters',
        () async {
      final code = await runCreate(['MyApp']);
      expect(code, 64);
    });

    test('returns exit code 64 for a project name starting with a digit',
        () async {
      final code = await runCreate(['123app']);
      expect(code, 64);
    });

    test('returns exit code 65 when the target directory already exists',
        () async {
      Directory(p.join(tempDir.path, 'my_app')).createSync();
      final code = await runCreate(['my_app']);
      expect(code, 65);
    });

    test('returns exit code 69 when flutter is not available on PATH',
        () async {
      final code = await runCreate(
        ['my_app'],
        process: FakeProcessService(availability: {'flutter': false}),
      );
      expect(code, 69);
      // Nothing should have been created.
      expect(Directory(p.join(tempDir.path, 'my_app')).existsSync(), isFalse);
    });

    test('never calls the interactive prompt when --auth is supplied',
        () async {
      var promptCalled = false;
      final runner = CommandRunner<int>('boltforge', 'test runner')
        ..addCommand(CreateCommand(
          logger: _testLogger(),
          process: FakeProcessService(),
          workingDirectory: tempDir,
          templatesRoot: _realTemplatesRoot,
          promptAuthChoice: () {
            promptCalled = true;
            return 'password';
          },
        ));
      await runner.run(['create', 'my_app', '--auth=otp']);
      expect(promptCalled, isFalse);
    });

    test('rejects an --auth value outside password/otp via the arg parser',
        () async {
      final runner = CommandRunner<int>('boltforge', 'test runner')
        ..addCommand(CreateCommand(
          logger: _testLogger(),
          process: FakeProcessService(),
          workingDirectory: tempDir,
          templatesRoot: _realTemplatesRoot,
        ));
      await expectLater(
        runner.run(['create', 'my_app', '--auth=carrier_pigeon']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('GenerateCommand — argument and input validation', () {
    Future<int> runGenerate(
      List<String> args, {
      Directory? workingDirectory,
      ConflictAction Function(String)? conflictResolver,
    }) {
      final runner = CommandRunner<int>('boltforge', 'test runner')
        ..addCommand(GenerateCommand(
          logger: _testLogger(),
          workingDirectory: workingDirectory ?? tempDir,
          templatesRoot: _realTemplatesRoot,
          conflictResolver: conflictResolver,
        ));
      return runner.run(['generate', ...args]).then((code) => code ?? 0);
    }

    /// Writes a bare pubspec.yaml + lib/ so `ProjectDetector` accepts the
    /// directory as a Flutter project. Optionally also writes a
    /// service_locator.dart with boltforge's marker comments, matching
    /// what `create` would really have produced, so DI-registration
    /// behavior can be exercised end-to-end through the command layer.
    File writeMinimalFlutterProject({bool withServiceLocator = true}) {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');
      Directory(p.join(tempDir.path, 'lib')).createSync();
      final serviceLocatorFile = File(
        p.join(tempDir.path, 'lib', 'core', 'di', 'service_locator.dart'),
      );
      if (withServiceLocator) {
        serviceLocatorFile.createSync(recursive: true);
        serviceLocatorFile.writeAsStringSync('''
import 'package:get_it/get_it.dart';

import '../../features/auth/repository/auth_repository.dart';
// boltforge:imports

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  // boltforge:registrations
}
''');
      }
      return serviceLocatorFile;
    }

    test('returns exit code 64 when the feature name is missing', () async {
      final code = await runGenerate([]);
      expect(code, 64);
    });

    test('returns exit code 64 for an invalid feature name', () async {
      final code = await runGenerate(['Invalid-Name']);
      expect(code, 64);
    });

    test('returns exit code 65 when run outside a Flutter project', () async {
      // tempDir has no pubspec.yaml at all.
      final code = await runGenerate(['offer']);
      expect(code, 65);
    });

    test(
        'returns exit code 65 for a plain Dart package (no flutter dependency)',
        () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_package
dependencies:
  path: ^1.9.0
''');
      Directory(p.join(tempDir.path, 'lib')).createSync();

      final code = await runGenerate(['offer']);
      expect(code, 65);
    });

    test('never touches the filesystem when the feature name is invalid',
        () async {
      writeMinimalFlutterProject();

      await runGenerate(['Not Valid']);

      // lib/ should contain nothing beyond what we created ourselves
      // (core/di/service_locator.dart from the helper).
      final featuresDir = Directory(p.join(tempDir.path, 'lib', 'features'));
      expect(featuresDir.existsSync(), isFalse);
    });

    test(
        'end-to-end: valid project + valid feature name generates real files '
        'and registers DI automatically', () async {
      final serviceLocatorFile = writeMinimalFlutterProject();

      final runner = CommandRunner<int>('boltforge', 'test runner')
        ..addCommand(GenerateCommand(
          logger: _testLogger(),
          workingDirectory: tempDir,
          templatesRoot: _realTemplatesRoot,
        ));
      final code = await runner.run(['generate', 'offer']).then((c) => c ?? 0);

      expect(code, 0);
      expect(
        File(p.join(tempDir.path, 'lib', 'features', 'offer', 'model',
                'offer_model.dart'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'lib', 'features', 'offer', 'cubit',
                'offer_cubit.dart'))
            .readAsStringSync(),
        contains('class OfferCubit'),
      );

      // The whole point of this feature: no manual DI edit required.
      final diContent = serviceLocatorFile.readAsStringSync();
      expect(
        diContent,
        contains(
            "import '../../features/offer/repository/offer_repository.dart';"),
      );
      expect(
        diContent,
        contains(
            'sl.registerLazySingleton<OfferRepository>(() => OfferRepository());'),
      );
    });

    test(
        'returns exit code 0 (with a warning) when service_locator.dart is missing entirely',
        () async {
      writeMinimalFlutterProject(withServiceLocator: false);

      final code = await runGenerate(['offer']);

      // A missing DI file is reported, but does not fail the generation —
      // the feature files themselves are still correct and usable.
      expect(code, 0);
      expect(
        File(p.join(tempDir.path, 'lib', 'features', 'offer', 'model',
                'offer_model.dart'))
            .existsSync(),
        isTrue,
      );
    });

    test('duplicate generation invokes the conflict resolver exactly once',
        () async {
      writeMinimalFlutterProject();

      // First generation: no conflict possible yet.
      final firstRunner = CommandRunner<int>('boltforge', 'r1')
        ..addCommand(GenerateCommand(
          logger: _testLogger(),
          workingDirectory: tempDir,
          templatesRoot: _realTemplatesRoot,
          conflictResolver: (_) => throw StateError('must not be called'),
        ));
      await firstRunner.run(['generate', 'offer']);

      var resolverCalls = 0;
      final code = await runGenerate(
        ['offer'],
        conflictResolver: (name) {
          resolverCalls++;
          expect(name, 'offer');
          return ConflictAction.cancel;
        },
      );

      expect(code, 0); // cancel is not an error — exit 0, nothing changed.
      expect(resolverCalls, 1);
    });
  });
}
