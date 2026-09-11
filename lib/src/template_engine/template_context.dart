import '../utils/case_converter.dart';

/// All values a template file (or file/directory name) can reference.
///
/// Populated once per generation run (project creation or feature
/// generation) and passed down through the whole render pipeline.
class TemplateContext {
  final Map<String, String> variables;
  final Map<String, bool> flags;

  const TemplateContext({
    this.variables = const {},
    this.flags = const {},
  });

  /// Builds the standard variable set for a *project*-level generation
  /// (`boltforge create my_app`).
  factory TemplateContext.forProject({
    required String projectName,
    required String orgIdentifier,
    required bool usesPassword,
  }) {
    final n = NameCase.from(projectName);
    return TemplateContext(
      variables: {
        'projectName': n.snake,
        'projectNamePascal': n.pascal,
        'projectNameCamel': n.camel,
        'projectNameKebab': n.kebab,
        'projectNameTitle': n.title,
        'orgIdentifier': orgIdentifier,
      },
      flags: {
        'authPassword': usesPassword,
        'authOtp': !usesPassword,
      },
    );
  }

  /// Builds the standard variable set for a *feature*-level generation
  /// (`boltforge generate offer`), merged on top of the parent project's
  /// package name so generated files can `import 'package:<project>/...'`.
  factory TemplateContext.forFeature({
    required String featureName,
    required String packageName,
  }) {
    final n = NameCase.from(featureName);
    return TemplateContext(
      variables: {
        'featureName': n.snake,
        'featureNamePascal': n.pascal,
        'featureNameCamel': n.camel,
        'featureNameKebab': n.kebab,
        'featureNameTitle': n.title,
        'packageName': packageName,
      },
    );
  }

  String? operator [](String key) => variables[key];
}
