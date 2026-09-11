import 'package:boltforge/src/validators/name_validator.dart';
import 'package:test/test.dart';

void main() {
  group('NameValidator.validate', () {
    test('accepts a simple lower_snake_case name', () {
      final result = NameValidator.validate('offer', kind: 'feature');
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('accepts a multi-word snake_case name', () {
      final result = NameValidator.validate('user_profile', kind: 'feature');
      expect(result.isValid, isTrue);
    });

    test('accepts a name starting with an underscore', () {
      final result =
          NameValidator.validate('_private_feature', kind: 'feature');
      expect(result.isValid, isTrue);
    });

    test('accepts a name with digits not in the leading position', () {
      final result = NameValidator.validate('offer2', kind: 'feature');
      expect(result.isValid, isTrue);
    });

    test('rejects an empty name', () {
      final result = NameValidator.validate('', kind: 'project');
      expect(result.isValid, isFalse);
      expect(result.reason, contains('empty'));
    });

    test('rejects a name that is only whitespace', () {
      final result = NameValidator.validate('   ', kind: 'project');
      expect(result.isValid, isFalse);
      expect(result.reason, contains('empty'));
    });

    test('rejects a name starting with a digit', () {
      final result = NameValidator.validate('123abc', kind: 'project');
      expect(result.isValid, isFalse);
      expect(result.reason, contains('123abc'));
    });

    test('rejects a name containing hyphens', () {
      final result = NameValidator.validate('user-profile', kind: 'feature');
      expect(result.isValid, isFalse);
    });

    test('rejects a name containing spaces', () {
      final result = NameValidator.validate('user profile', kind: 'feature');
      expect(result.isValid, isFalse);
    });

    test('rejects a name containing uppercase letters', () {
      final result = NameValidator.validate('UserProfile', kind: 'feature');
      expect(result.isValid, isFalse);
    });

    test('rejects a name containing special characters', () {
      final result = NameValidator.validate('user@profile', kind: 'feature');
      expect(result.isValid, isFalse);
    });

    test('rejects a bare Dart reserved word', () {
      final result = NameValidator.validate('class', kind: 'feature');
      expect(result.isValid, isFalse);
      expect(result.reason, contains('reserved'));
    });

    test('accepts a reserved word as a substring of a longer identifier', () {
      // "class" is reserved but "class_room" is a fine identifier.
      final result = NameValidator.validate('class_room', kind: 'feature');
      expect(result.isValid, isTrue);
    });

    test('rejects a name over 64 characters', () {
      final tooLong = 'a' * 65;
      final result = NameValidator.validate(tooLong, kind: 'project');
      expect(result.isValid, isFalse);
      expect(result.reason, contains('too long'));
    });

    test('accepts a name exactly 64 characters long', () {
      final maxLength = 'a' * 64;
      final result = NameValidator.validate(maxLength, kind: 'project');
      expect(result.isValid, isTrue);
    });

    test('includes the requested "kind" label in the error message', () {
      final result = NameValidator.validate('123', kind: 'project');
      expect(result.reason, contains('project name'));
    });
  });
}
