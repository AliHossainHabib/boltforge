import 'dart:io';
import 'package:args/command_runner.dart';

import '../core/package_paths.dart';
import '../generators/feature_generator.dart';
import '../services/di_registrar.dart';
import '../services/feature_validator.dart';
import '../services/file_service.dart';
import '../services/project_detector.dart';
import '../utils/logger.dart';
import '../validators/name_validator.dart';

class GenerateCommand extends Command<int> {
  @override
  final name = 'generate';
  @override
  final description = 'Generate a fully-wired feature '
      '(cubit, repository, model, screen, widgets) inside the current '
      'Flutter project, and register its repository in the DI container.';
  @override
  final aliases = ['g', 'feature'];

  final Logger logger;

  /// Directory `generate` treats as "the current Flutter project".
  /// Defaults to the real process cwd; tests inject a temp directory.
  final Directory workingDirectory;

  /// Templates root passed through to [FeatureGenerator]. Null means
  /// "resolve it for real" via [PackagePaths.resolveTemplatesRoot] when
  /// `run()` executes; tests inject a known directory directly instead.
  final Directory? templatesRoot;

  /// Injectable so tests can supply a canned conflict resolution instead
  /// of blocking on real stdin.
  final ConflictAction Function(String featureName)? conflictResolver;

  GenerateCommand({
    Logger? logger,
    Directory? workingDirectory,
    this.templatesRoot,
    this.conflictResolver,
  })  : logger = logger ?? Logger(),
        workingDirectory = workingDirectory ?? Directory.current;

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      logger.error('Missing feature name. Usage: boltforge generate <name>');
      return 64;
    }
    final featureName = rest.first;

    final validation = NameValidator.validate(featureName, kind: 'feature');
    if (!validation.isValid) {
      logger.error(validation.reason!);
      return 64;
    }

    final detection = ProjectDetector().detect(workingDirectory);
    if (!detection.isFlutterProject) {
      logger.error('This command must be run inside a Flutter project.');
      logger.info(detection.reason ?? '');
      return 65;
    }

    final resolvedTemplatesRoot =
        templatesRoot ?? await PackagePaths.resolveTemplatesRoot();
    if (resolvedTemplatesRoot == null) {
      logger.error(
        'Could not locate boltforge\'s bundled templates/ directory. '
        'This usually means the package installation is corrupted or '
        'incomplete — try reactivating it '
        '(`dart pub global activate boltforge`) and run `boltforge doctor`.',
      );
      return 70;
    }

    logger.title('boltforge — generating feature "$featureName"');

    final generator = FeatureGenerator(
      onExistingFeature: conflictResolver ?? _promptConflict,
      templatesRoot: resolvedTemplatesRoot,
    );

    final result = generator.generate(
      projectRoot: workingDirectory,
      featureName: featureName,
      packageName: detection.packageName!,
    );

    if (result.wasCancelled) {
      logger.warn('Cancelled — no files were changed.');
      return 0;
    }

    for (final file in result.writtenFiles) {
      logger.success('Wrote $file');
    }
    for (final file in result.skippedExistingFiles) {
      logger.warn('Kept existing file (not overwritten): $file');
    }

    logger.blank();
    _reportDiResult(result.diResult);
    _reportValidation(result.validationIssues);

    logger.blank();
    if (result.isValid) {
      logger.title('Feature "$featureName" generated.');
    } else {
      logger.title(
          'Feature "$featureName" generated with problems — see errors above.');
    }
    logger.info(
      'Run `flutter analyze` to confirm imports resolve, then wire the '
      'screen into your router.',
    );
    return result.isValid ? 0 : 1;
  }

  void _reportDiResult(DiRegistrationResult? diResult) {
    if (diResult == null) return;
    switch (diResult.status) {
      case DiRegistrationStatus.registered:
        if (diResult.alreadyPresent) {
          logger.info(
              'DI: repository was already registered in service_locator.dart — left untouched.');
        } else {
          logger.success(
              'DI: registered the repository in lib/core/di/service_locator.dart automatically.');
        }
        break;
      case DiRegistrationStatus.fileMissing:
        logger.warn(
          'DI: lib/core/di/service_locator.dart was not found — register '
          'the repository there yourself.',
        );
        break;
      case DiRegistrationStatus.markersMissing:
        logger.warn(
          'DI: service_locator.dart is missing the `// boltforge:imports` / '
          '`// boltforge:registrations` marker comments (was it hand-edited?) '
          '— boltforge left it untouched. Register the repository manually.',
        );
        break;
    }
  }

  void _reportValidation(List<ValidationIssue> issues) {
    for (final issue in issues) {
      if (issue.severity == ValidationSeverity.error) {
        logger.error(issue.message);
      } else {
        logger.warn(issue.message);
      }
    }
  }

  ConflictAction _promptConflict(String featureName) {
    logger.blank();
    logger.warn('Feature "$featureName" already exists.');
    logger.info('  [1] Cancel');
    logger.info('  [2] Overwrite existing files');
    logger.info('  [3] Merge — only write files that do not exist yet');
    while (true) {
      stdout.write('> ');
      final input = stdin.readLineSync()?.trim();
      switch (input) {
        case '1':
          return ConflictAction.cancel;
        case '2':
          return ConflictAction.overwrite;
        case '3':
          return ConflictAction.merge;
        default:
          logger.warn('Please enter 1, 2, or 3.');
      }
    }
  }
}
