import 'dart:io';

import 'package:boltforge/src/generators/project_generator.dart';
import 'package:boltforge/src/services/process_service.dart';
import 'package:boltforge/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fake_process_service.dart';

/// See feature_generator_test.dart for why `Directory.current` is a safe
/// stand-in for the package root under `dart test`.
Directory get _realTemplatesRoot =>
    Directory(p.join(Directory.current.path, 'templates'));

/// Logger with ANSI color codes disabled — real Logger just calls
/// `print`, which is fine to leave running during tests, but this keeps
/// test output free of escape codes.
Logger _testLogger() => Logger(colorEnabled: false);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('boltforge_project_gen_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('stops immediately and reports failure when `flutter create` fails',
      () async {
    final fake = FakeProcessService(
      onRun: (executable, args) {
        if (args.first == 'create') {
          return const ProcessOutcome(
            succeeded: false,
            exitCode: 1,
            stdout: '',
            stderr: 'flutter: command not found style failure',
          );
        }
        return const ProcessOutcome(
            succeeded: true, exitCode: 0, stdout: '', stderr: '');
      },
    );
    final generator = ProjectGenerator(
      process: fake,
      logger: _testLogger(),
      templatesRoot: _realTemplatesRoot,
    );

    final steps = await generator.generate(
      projectName: 'my_app',
      orgIdentifier: 'com.example',
      usesPassword: true,
      parentDirectory: tempDir,
      runAnalyzeAndTest: true,
    );

    expect(steps, hasLength(1));
    expect(steps.single.label, 'flutter create');
    expect(steps.single.succeeded, isFalse);
    // Nothing past `flutter create` should have run.
    expect(fake.calls, hasLength(1));
  });

  test(
      'stops after pub add if adding dependencies fails, before touching templates',
      () async {
    final fake = FakeProcessService(
      onRun: (executable, args) {
        if (args.contains('add')) {
          return const ProcessOutcome(
            succeeded: false,
            exitCode: 1,
            stdout: '',
            stderr: 'version solving failed',
          );
        }
        return const ProcessOutcome(
            succeeded: true, exitCode: 0, stdout: '', stderr: '');
      },
    );
    final generator = ProjectGenerator(
      process: fake,
      logger: _testLogger(),
      templatesRoot: _realTemplatesRoot,
    );

    final steps = await generator.generate(
      projectName: 'my_app',
      orgIdentifier: 'com.example',
      usesPassword: true,
      parentDirectory: tempDir,
      runAnalyzeAndTest: true,
    );

    expect(steps.map((s) => s.label), ['flutter create', contains('pub add')]);
    expect(steps.last.succeeded, isFalse);
    // The architecture must not have been applied — no lib/ directory.
    expect(
        Directory(p.join(tempDir.path, 'my_app', 'lib')).existsSync(), isFalse);
  });

  test(
      'runs the full pipeline in order and writes real files when every step succeeds',
      () async {
    final fake = FakeProcessService();
    final generator = ProjectGenerator(
      process: fake,
      logger: _testLogger(),
      templatesRoot: _realTemplatesRoot,
    );

    final steps = await generator.generate(
      projectName: 'my_app',
      orgIdentifier: 'com.example',
      usesPassword: true,
      parentDirectory: tempDir,
      runAnalyzeAndTest: true,
    );

    expect(steps.every((s) => s.succeeded), isTrue);
    expect(steps.map((s) => s.label), [
      'flutter create',
      contains('pub add'),
      'Apply base architecture',
      contains('Configure authentication'),
      'flutter pub get',
      'flutter analyze',
      'flutter test',
    ]);

    // Process call order matters: create -> pub add -> pub get -> analyze -> test.
    // (Applying the base/auth templates uses FileService directly, not a
    // process call, so it doesn't appear in this list.)
    expect(
        fake.calls
            .map((c) => '${c.executable} ${c.args.take(2).join(' ')}')
            .toList(),
        [
          'flutter create --org',
          'flutter pub add',
          'flutter pub get',
          'flutter analyze',
          'flutter test',
        ]);

    // Real files from the base + auth templates must actually exist —
    // ProjectGenerator doesn't shell out for this part, it uses
    // boltforge's own FileService, so this is a real assertion.
    final projectDir = Directory(p.join(tempDir.path, 'my_app'));
    expect(
        File(p.join(projectDir.path, 'lib', 'main.dart')).existsSync(), isTrue);
    expect(
      File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'screen',
        'login_screen.dart',
      )).existsSync(),
      isTrue,
    );
  });

  test('stops before analyze/test when runAnalyzeAndTest is false', () async {
    final fake = FakeProcessService();
    final generator = ProjectGenerator(
      process: fake,
      logger: _testLogger(),
      templatesRoot: _realTemplatesRoot,
    );

    final steps = await generator.generate(
      projectName: 'my_app',
      orgIdentifier: 'com.example',
      usesPassword: false,
      parentDirectory: tempDir,
      runAnalyzeAndTest: false,
    );

    expect(steps.map((s) => s.label), [
      'flutter create',
      contains('pub add'),
      'Apply base architecture',
      contains('Configure authentication'),
      'flutter pub get',
    ]);
    expect(steps.any((s) => s.label == 'flutter analyze'), isFalse);
    expect(steps.any((s) => s.label == 'flutter test'), isFalse);
  });

  test(
      'stops and reports failure when flutter analyze finds problems, never runs test',
      () async {
    final fake = FakeProcessService(
      onRun: (executable, args) {
        if (args.isNotEmpty && args.first == 'analyze') {
          return const ProcessOutcome(
            succeeded: false,
            exitCode: 1,
            stdout: "lib/main.dart:1:1: error: undefined_identifier",
            stderr: '',
          );
        }
        return const ProcessOutcome(
            succeeded: true, exitCode: 0, stdout: '', stderr: '');
      },
    );
    final generator = ProjectGenerator(
      process: fake,
      logger: _testLogger(),
      templatesRoot: _realTemplatesRoot,
    );

    final steps = await generator.generate(
      projectName: 'my_app',
      orgIdentifier: 'com.example',
      usesPassword: true,
      parentDirectory: tempDir,
      runAnalyzeAndTest: true,
    );

    final analyzeStep = steps.firstWhere((s) => s.label == 'flutter analyze');
    expect(analyzeStep.succeeded, isFalse);
    expect(analyzeStep.detail, contains('undefined_identifier'));
    expect(steps.any((s) => s.label == 'flutter test'), isFalse);
  });
}
