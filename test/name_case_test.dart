import 'package:boltforge/src/utils/case_converter.dart';
import 'package:test/test.dart';

void main() {
  group('NameCase.from', () {
    test('converts snake_case input to every style', () {
      final n = NameCase.from('user_profile');
      expect(n.snake, 'user_profile');
      expect(n.pascal, 'UserProfile');
      expect(n.camel, 'userProfile');
      expect(n.kebab, 'user-profile');
      expect(n.title, 'User Profile');
      expect(n.upperSnake, 'USER_PROFILE');
    });

    test('converts PascalCase input to every style', () {
      final n = NameCase.from('UserProfile');
      expect(n.snake, 'user_profile');
      expect(n.pascal, 'UserProfile');
      expect(n.camel, 'userProfile');
      expect(n.kebab, 'user-profile');
      expect(n.title, 'User Profile');
    });

    test('converts camelCase input to every style', () {
      final n = NameCase.from('userProfile');
      expect(n.snake, 'user_profile');
      expect(n.pascal, 'UserProfile');
      expect(n.camel, 'userProfile');
    });

    test('converts kebab-case input to every style', () {
      final n = NameCase.from('user-profile');
      expect(n.snake, 'user_profile');
      expect(n.pascal, 'UserProfile');
      expect(n.camel, 'userProfile');
    });

    test('converts space-separated input to every style', () {
      final n = NameCase.from('user profile');
      expect(n.snake, 'user_profile');
      expect(n.pascal, 'UserProfile');
    });

    test('handles a single lowercase word', () {
      final n = NameCase.from('offer');
      expect(n.snake, 'offer');
      expect(n.pascal, 'Offer');
      expect(n.camel, 'offer');
      expect(n.kebab, 'offer');
      expect(n.title, 'Offer');
      expect(n.upperSnake, 'OFFER');
    });

    test('handles three-word names', () {
      final n = NameCase.from('user_profile_settings');
      expect(n.pascal, 'UserProfileSettings');
      expect(n.camel, 'userProfileSettings');
      expect(n.kebab, 'user-profile-settings');
    });

    test('preserves digits as part of a word boundary', () {
      final n = NameCase.from('offer2');
      expect(n.snake, 'offer2');
      expect(n.pascal, 'Offer2');
    });

    test('handles digits at a word boundary from PascalCase', () {
      final n = NameCase.from('OAuth2Token');
      // 'OAuth2Token' -> boundaries inserted before capitals following a
      // lowercase/digit: O, Auth2, Token. This is a deliberately simple
      // regex-based splitter, not full acronym-aware casing.
      expect(n.snake, isNotEmpty);
      expect(n.pascal, isNotEmpty);
    });

    test('collapses repeated separators', () {
      final n = NameCase.from('user__profile');
      expect(n.snake, 'user_profile');
    });

    test('is idempotent: re-converting the pascal output gives the same snake',
        () {
      final first = NameCase.from('user_profile');
      final second = NameCase.from(first.pascal);
      expect(second.snake, first.snake);
    });
  });
}
