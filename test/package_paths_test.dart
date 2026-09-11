import 'dart:io';

import 'package:boltforge/src/core/package_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PackagePaths.resolveTemplatesRoot', () {
    test('resolves to a real, existing templates/ directory', () async {
      final resolved = await PackagePaths.resolveTemplatesRoot();

      expect(resolved, isNotNull,
          reason: 'Could not resolve templates/ at all — this is exactly '
              'the class of bug that broke `boltforge create` when run as '
              'a globally-activated executable outside the repository.');
      expect(resolved!.existsSync(), isTrue);
    });

    test('the resolved directory actually contains base/, auth/, and feature/',
        () async {
      final resolved = await PackagePaths.resolveTemplatesRoot();

      expect(resolved, isNotNull);
      expect(Directory(p.join(resolved!.path, 'base')).existsSync(), isTrue);
      expect(
        Directory(p.join(resolved.path, 'auth', 'password')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(resolved.path, 'auth', 'otp')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(resolved.path, 'feature')).existsSync(), isTrue);
    });

    test(
        'resolves to the same real templates/ directory tests rely on '
        'via Directory.current', () async {
      // This is the actual regression check for the bug: the resolved
      // path must be the true package root's templates/, not some
      // nested cache path like `.dart_tool/pub/bin/templates`. Since
      // `dart test` is required to run from the package root,
      // Directory.current is an independent, trustworthy reference here.
      final resolved = await PackagePaths.resolveTemplatesRoot();
      final expected = Directory(p.join(Directory.current.path, 'templates'));

      expect(resolved, isNotNull);
      expect(p.equals(resolved!.path, expected.path), isTrue,
          reason: 'resolved "${resolved.path}" but expected '
              '"${expected.path}"');
    });

    test('is safe to call repeatedly (idempotent, no caching bugs)', () async {
      final first = await PackagePaths.resolveTemplatesRoot();
      final second = await PackagePaths.resolveTemplatesRoot();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(p.equals(first!.path, second!.path), isTrue);
    });
  });
}
