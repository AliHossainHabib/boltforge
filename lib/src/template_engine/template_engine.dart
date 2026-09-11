import 'template_context.dart';

/// Renders template *content* (file bodies) and template *paths*
/// (file/directory names) against a [TemplateContext].
///
/// Syntax supported (intentionally small — this is a code generator, not
/// a general-purpose templating language):
///
///   {{variableName}}                 -> substituted with context value
///   {{#if flagName}} ... {{/if}}     -> block kept only if flag is true
///   {{#unless flagName}} ... {{/unless}} -> block kept only if flag is false
///
/// Unknown `{{variable}}` references throw [TemplateVariableError] rather
/// than silently emitting an empty string or the literal token — a typo'd
/// placeholder in a generated Dart file is a bug, not acceptable output.
class TemplateEngine {
  static final _variablePattern = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');
  static final _ifBlockPattern = RegExp(
    r'\{\{#if\s+([a-zA-Z0-9_]+)\}\}(.*?)\{\{/if\}\}',
    dotAll: true,
  );
  static final _unlessBlockPattern = RegExp(
    r'\{\{#unless\s+([a-zA-Z0-9_]+)\}\}(.*?)\{\{/unless\}\}',
    dotAll: true,
  );

  final TemplateContext context;

  const TemplateEngine(this.context);

  /// Renders a template string (file content or a path segment).
  String render(String template) {
    var result = template;

    result = result.replaceAllMapped(_ifBlockPattern, (m) {
      final flag = m.group(1)!;
      final body = m.group(2)!;
      final isSet = context.flags[flag];
      if (isSet == null) {
        throw TemplateVariableError(
          'Unknown conditional flag "{{#if $flag}}" — '
          'no such flag was provided to the template engine.',
        );
      }
      return isSet ? body : '';
    });

    result = result.replaceAllMapped(_unlessBlockPattern, (m) {
      final flag = m.group(1)!;
      final body = m.group(2)!;
      final isSet = context.flags[flag];
      if (isSet == null) {
        throw TemplateVariableError(
          'Unknown conditional flag "{{#unless $flag}}" — '
          'no such flag was provided to the template engine.',
        );
      }
      return !isSet ? body : '';
    });

    result = result.replaceAllMapped(_variablePattern, (m) {
      final name = m.group(1)!;
      final value = context[name];
      if (value == null) {
        throw TemplateVariableError(
          'Unknown template variable "{{$name}}" — '
          'no such variable was provided to the template engine.',
        );
      }
      return value;
    });

    return result;
  }

  /// Renders a file/directory name and strips a trailing `.tmpl` extension
  /// (the convention this project's `templates/` tree uses to mark files
  /// that should be rendered rather than copied verbatim).
  String renderPathSegment(String segment) {
    final rendered = render(segment);
    return rendered.endsWith('.tmpl')
        ? rendered.substring(0, rendered.length - '.tmpl'.length)
        : rendered;
  }
}

class TemplateVariableError implements Exception {
  final String message;
  const TemplateVariableError(this.message);
  @override
  String toString() => 'TemplateVariableError: $message';
}
