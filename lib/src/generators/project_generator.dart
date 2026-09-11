import 'dart:io';
import 'package:path/path.dart' as p;

import '../services/file_service.dart';
import '../services/process_service.dart';
import '../template_engine/template_context.dart';
import '../template_engine/template_engine.dart';
import '../utils/logger.dart';

class ProjectGenerationStepResult {
  final String label;
  final bool succeeded;
  final String? detail;
  const ProjectGenerationStepResult(this.label, this.succeeded, [this.detail]);
}

/// Orchestrates the full `boltforge create <name>` pipeline:
/// flutter create -> apply base architecture -> apply auth template ->
/// pub get -> analyze -> test -> report.
///
/// Every stage returns a [ProjectGenerationStepResult] rather than throwing,
/// so the caller can print a step-by-step report and stop at the first
/// real failure instead of claiming success over a broken project.
class ProjectGenerator {
  final ProcessService process;
  final Logger logger;

  /// The `templates/` directory to read `base/` and `auth/*` from.
  /// Required (not resolved internally with a default) because locating
  /// it is inherently asynchronous — see `PackagePaths.resolveTemplatesRoot`
  /// — so the caller (a command's `run()`, which is already `async`)
  /// resolves it once and passes it in. Tests pass a known directory
  /// directly, exercising the exact same constructor path production
  /// code uses.
  final Directory templatesRoot;

  ProjectGenerator({
    required this.process,
    required this.logger,
    required this.templatesRoot,
  });

  Future<List<ProjectGenerationStepResult>> generate({
    required String projectName,
    required String orgIdentifier,
    required bool usesPassword,
    required Directory parentDirectory,
    required bool runAnalyzeAndTest,
  }) async {
    final results = <ProjectGenerationStepResult>[];
    final projectDir = Directory(p.join(parentDirectory.path, projectName));

    // 1. flutter create
    logger.step('Creating Flutter project "$projectName"');
    final createOutcome = await process.run(
      'flutter',
      [
        'create',
        '--org',
        orgIdentifier,
        '--project-name',
        projectName,
        projectName,
      ],
      workingDirectory: parentDirectory.path,
    );
    results.add(ProjectGenerationStepResult(
      'flutter create',
      createOutcome.succeeded,
      createOutcome.succeeded ? null : createOutcome.stderr,
    ));
    if (!createOutcome.succeeded) return results;
    logger.success('Flutter project scaffolded');

    // 2. Add the packages the base architecture + auth templates depend on.
    // Done via `flutter pub add` (not hand-edited YAML) so version
    // resolution is Flutter's own — never a hardcoded version this tool
    // could drift out of date with.
    logger.step('Adding required dependencies');
    const requiredPackages = [
      'flutter_bloc',
      'bloc',
      'dio',
      'get_it',
      'shared_preferences',
    ];
    final addOutcome = await process.run(
      'flutter',
      ['pub', 'add', ...requiredPackages],
      workingDirectory: projectDir.path,
    );
    results.add(ProjectGenerationStepResult(
      'flutter pub add ${requiredPackages.join(' ')}',
      addOutcome.succeeded,
      addOutcome.succeeded ? null : addOutcome.stderr,
    ));
    if (!addOutcome.succeeded) return results;
    logger.success('Dependencies added to pubspec.yaml');

    // 3. Apply base architecture (core/ layer: network, DI, routing, ui).
    logger.step('Applying base architecture');
    final context = TemplateContext.forProject(
      projectName: projectName,
      orgIdentifier: orgIdentifier,
      usesPassword: usesPassword,
    );
    final engine = TemplateEngine(context);
    final fileService = FileService(engine);

    try {
      fileService.renderTree(
        templateRoot: Directory(p.join(templatesRoot.path, 'base')),
        destinationRoot: projectDir,
        onConflict: ConflictAction.overwrite,
      );
      results.add(
          const ProjectGenerationStepResult('Apply base architecture', true));
      logger.success('Base architecture applied (core/ layer)');
    } catch (e) {
      results.add(
          ProjectGenerationStepResult('Apply base architecture', false, '$e'));
      return results;
    }

    // 4. Apply the chosen authentication template.
    final authVariant = usesPassword ? 'password' : 'otp';
    logger.step('Configuring authentication ($authVariant)');
    try {
      fileService.renderTree(
        templateRoot:
            Directory(p.join(templatesRoot.path, 'auth', authVariant)),
        destinationRoot: projectDir,
        onConflict: ConflictAction.overwrite,
      );
      results.add(ProjectGenerationStepResult(
          'Configure authentication ($authVariant)', true));
      logger.success('Authentication flow generated ($authVariant)');
    } catch (e) {
      results.add(
          ProjectGenerationStepResult('Configure authentication', false, '$e'));
      return results;
    }

    // 5. flutter pub get
    logger.step('Installing dependencies');
    final pubGet = await process.run('flutter', ['pub', 'get'],
        workingDirectory: projectDir.path);
    results.add(ProjectGenerationStepResult('flutter pub get', pubGet.succeeded,
        pubGet.succeeded ? null : pubGet.stderr));
    if (!pubGet.succeeded) return results;
    logger.success('Dependencies installed');

    if (!runAnalyzeAndTest) return results;

    // 6. flutter analyze — this is the import-validation gate.
    logger.step('Validating generated code (flutter analyze)');
    final analyze = await process.run('flutter', ['analyze'],
        workingDirectory: projectDir.path);
    results.add(ProjectGenerationStepResult(
        'flutter analyze',
        analyze.succeeded,
        analyze.succeeded ? null : analyze.stdout + analyze.stderr));
    if (!analyze.succeeded) {
      logger.error('flutter analyze reported problems — see details above.');
      return results;
    }
    logger.success('No analysis issues found');

    // 7. flutter test — the generated project's default smoke test.
    logger.step('Running tests');
    final test = await process.run('flutter', ['test'],
        workingDirectory: projectDir.path);
    results.add(ProjectGenerationStepResult('flutter test', test.succeeded,
        test.succeeded ? null : test.stdout + test.stderr));
    if (test.succeeded) {
      logger.success('Tests passed');
    } else {
      logger.warn('Some tests failed — review before shipping.');
    }

    return results;
  }
}
