import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/package_paths.dart';
import '../generators/project_generator.dart';
import '../services/process_service.dart';
import '../utils/logger.dart';
import '../validators/name_validator.dart';

class CreateCommand extends Command<int> {
  @override
  final name = 'create';
  @override
  final description = 'Create a new Flutter project with a Cubit + '
      'Repository + GetIt architecture and a wired authentication flow.';

  final Logger logger;
  final ProcessService process;

  /// Directory `create` operates relative to. Defaults to the real
  /// process cwd; tests inject a temp directory so nothing here ever
  /// touches the real filesystem outside a controlled sandbox.
  final Directory workingDirectory;

  /// Templates root passed through to [ProjectGenerator]. Null means
  /// "resolve it for real" via [PackagePaths.resolveTemplatesRoot] when
  /// `run()` executes; tests inject a known directory directly instead.
  final Directory? templatesRoot;

  /// Injectable so tests can supply canned answers instead of blocking
  /// on real stdin.
  final String Function() promptAuthChoice;

  CreateCommand({
    Logger? logger,
    ProcessService? process,
    Directory? workingDirectory,
    this.templatesRoot,
    String Function()? promptAuthChoice,
  })  : logger = logger ?? Logger(),
        process = process ?? ProcessService(),
        workingDirectory = workingDirectory ?? Directory.current,
        promptAuthChoice = promptAuthChoice ?? _defaultPromptAuthChoice {
    argParser
      ..addOption(
        'auth',
        allowed: ['password', 'otp'],
        help: 'Authentication style. "password" adds login/register/forgot-'
            'password screens. "otp" adds an email-or-phone verification '
            'flow with no password field.',
      )
      ..addOption(
        'org',
        defaultsTo: 'com.example',
        help: 'Reverse-domain org identifier passed to `flutter create`.',
      )
      ..addFlag(
        'skip-validation',
        negatable: false,
        help: 'Skip `flutter analyze` / `flutter test` after generation.',
      );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    final rest = args.rest;

    if (rest.isEmpty) {
      logger.error('Missing project name. Usage: boltforge create <name>');
      return 64;
    }
    final projectName = rest.first;

    final validation = NameValidator.validate(projectName, kind: 'project');
    if (!validation.isValid) {
      logger.error(validation.reason!);
      return 64;
    }

    final targetDir = Directory(p.join(workingDirectory.path, projectName));
    if (targetDir.existsSync()) {
      logger.error(
        'A directory named "$projectName" already exists in '
        '${workingDirectory.path}. Choose a different name or remove '
        'it first — boltforge will not overwrite an existing directory.',
      );
      return 65;
    }

    if (!await process.isAvailable('flutter')) {
      logger.error(
        'Flutter was not found on PATH. Install Flutter and make sure '
        '`flutter --version` works before running `boltforge create`.',
      );
      return 69;
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

    String? authChoice = args['auth'] as String?;
    if (authChoice == null) {
      authChoice = promptAuthChoice();
    }
    final usesPassword = authChoice == 'password';

    logger.title('boltforge — creating "$projectName"');

    final generator = ProjectGenerator(
      process: process,
      logger: logger,
      templatesRoot: resolvedTemplatesRoot,
    );
    final steps = await generator.generate(
      projectName: projectName,
      orgIdentifier: args['org'] as String,
      usesPassword: usesPassword,
      parentDirectory: workingDirectory,
      runAnalyzeAndTest: !(args['skip-validation'] as bool),
    );

    final failed = steps.where((s) => !s.succeeded).toList();
    logger.blank();
    if (failed.isEmpty) {
      logger.title('Project created successfully!');
      logger.info('cd $projectName && flutter run');
      return 0;
    } else {
      logger.title('Project creation stopped — one step failed.');
      for (final f in failed) {
        logger.error('${f.label} failed.');
        if (f.detail != null && f.detail!.trim().isNotEmpty) {
          logger.info(f.detail!.trim());
        }
      }
      return 1;
    }
  }

  static String _defaultPromptAuthChoice() {
    stdout.write(
      '\nDoes authentication use a password?\n'
      '  [1] Yes — email/phone + password, with forgot-password\n'
      '  [2] No  — email/phone verification only (OTP-style)\n',
    );
    while (true) {
      stdout.write('> ');
      final input = stdin.readLineSync()?.trim();
      if (input == '1') return 'password';
      if (input == '2') return 'otp';
      stdout.write('Please enter 1 or 2.\n');
    }
  }
}
