/// Dart/Flutter package identifiers must be a lower_snake_case identifier:
/// start with a letter or underscore, contain only [a-z0-9_], and not
/// collide with a reserved word. This mirrors the rule `flutter create`
/// itself enforces on `--project-name`.
class NameValidationResult {
  final bool isValid;
  final String? reason;
  const NameValidationResult.valid()
      : isValid = true,
        reason = null;
  const NameValidationResult.invalid(this.reason) : isValid = false;
}

class NameValidator {
  static const _dartReservedWords = {
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
  };

  static final _validIdentifier = RegExp(r'^[a-z_][a-z0-9_]*$');

  /// Used for both project names (`boltforge create <name>`) and feature
  /// names (`boltforge generate <name>`) — both become Dart identifiers.
  static NameValidationResult validate(String rawName, {required String kind}) {
    if (rawName.trim().isEmpty) {
      return NameValidationResult.invalid('$kind name cannot be empty.');
    }

    final name = rawName.trim();

    if (!_validIdentifier.hasMatch(name)) {
      return NameValidationResult.invalid(
        '"$name" is not a valid $kind name. Use lower_snake_case: '
        'start with a letter or underscore, then letters, digits, or '
        'underscores only (e.g. "user_profile", not "123abc" or "user-profile").',
      );
    }

    if (_dartReservedWords.contains(name)) {
      return NameValidationResult.invalid(
        '"$name" is a reserved Dart keyword and cannot be used as a $kind name.',
      );
    }

    if (name.length > 64) {
      return NameValidationResult.invalid(
        '"$name" is too long for a $kind name (max 64 characters).',
      );
    }

    return const NameValidationResult.valid();
  }
}
