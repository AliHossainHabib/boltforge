import 'dart:io';

import 'package:boltforge/src/services/di_registrar.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _baseContent() => '''
import 'package:get_it/get_it.dart';

import '../../features/auth/repository/auth_repository.dart';
// boltforge:imports

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  // boltforge:registrations
}
''';

void main() {
  late Directory tempDir;
  late File serviceLocatorFile;
  const registrar = DiRegistrar();

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('boltforge_di_registrar_test_');
    serviceLocatorFile = File(p.join(tempDir.path, 'service_locator.dart'))
      ..writeAsStringSync(_baseContent());
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('DiRegistrar.registerRepository — happy path', () {
    test('adds both the import and the registration', () {
      final result = registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(result.status, DiRegistrationStatus.registered);
      expect(result.importAdded, isTrue);
      expect(result.registrationAdded, isTrue);
      expect(result.alreadyPresent, isFalse);

      final content = serviceLocatorFile.readAsStringSync();
      expect(
        content,
        contains(
            "import '../../features/offer/repository/offer_repository.dart';"),
      );
      expect(
        content,
        contains(
            'sl.registerLazySingleton<OfferRepository>(() => OfferRepository());'),
      );
    });

    test('preserves the pre-existing AuthRepository line exactly', () {
      registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      final content = serviceLocatorFile.readAsStringSync();
      expect(
        content,
        contains(
            "import '../../features/auth/repository/auth_repository.dart';"),
      );
      expect(
        content,
        contains(
            'sl.registerLazySingleton<AuthRepository>(() => AuthRepository());'),
      );
    });

    test(
        'new registration is indented with exactly two spaces, matching existing style',
        () {
      registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      final content = serviceLocatorFile.readAsStringSync();
      expect(
        content,
        contains(
            '\n  sl.registerLazySingleton<OfferRepository>(() => OfferRepository());\n'),
      );
    });

    test(
        'both marker comments are still present afterwards (repeatable insertion point)',
        () {
      registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      final content = serviceLocatorFile.readAsStringSync();
      expect(content, contains(DiRegistrar.importMarker));
      expect(content, contains(DiRegistrar.registrationMarker));
      // Exactly one of each — insertion must not duplicate the marker itself.
      expect(DiRegistrar.importMarker.allMatches(content).length, 1);
      expect(DiRegistrar.registrationMarker.allMatches(content).length, 1);
    });

    test(
        'registering three repositories in sequence appends all three correctly',
        () {
      for (final name in ['Offer', 'Payment', 'Wallet']) {
        registrar.registerRepository(
          serviceLocatorFile: serviceLocatorFile,
          repositoryClassName: '${name}Repository',
          importPath:
              '../../features/${name.toLowerCase()}/repository/${name.toLowerCase()}_repository.dart',
        );
      }

      final content = serviceLocatorFile.readAsStringSync();
      for (final name in ['Auth', 'Offer', 'Payment', 'Wallet']) {
        expect(
            'registerLazySingleton<${name}Repository>'
                .allMatches(content)
                .length,
            1,
            reason: '$name should be registered exactly once');
      }
    });
  });

  group('DiRegistrar.registerRepository — idempotency / no duplicates', () {
    test('calling twice for the same repository only registers it once', () {
      registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );
      final second = registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(second.status, DiRegistrationStatus.registered);
      expect(second.alreadyPresent, isTrue);
      expect(second.importAdded, isFalse);
      expect(second.registrationAdded, isFalse);

      final content = serviceLocatorFile.readAsStringSync();
      expect(
          'registerLazySingleton<OfferRepository>'.allMatches(content).length,
          1);
      expect(
        "import '../../features/offer/repository/offer_repository.dart';"
            .allMatches(content)
            .length,
        1,
      );
    });

    test(
        'if only the import is somehow already present, only the registration is added',
        () {
      // Simulate a partially-applied prior edit.
      var content = serviceLocatorFile.readAsStringSync();
      content = content.replaceFirst(
        DiRegistrar.importMarker,
        "import '../../features/offer/repository/offer_repository.dart';\n${DiRegistrar.importMarker}",
      );
      serviceLocatorFile.writeAsStringSync(content);

      final result = registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(result.importAdded, isFalse);
      expect(result.registrationAdded, isTrue);
      final finalContent = serviceLocatorFile.readAsStringSync();
      expect(
        "import '../../features/offer/repository/offer_repository.dart';"
            .allMatches(finalContent)
            .length,
        1,
      );
    });
  });

  group('DiRegistrar.registerRepository — safe failure modes', () {
    test('reports fileMissing without throwing when the file does not exist',
        () {
      final missingFile = File(p.join(tempDir.path, 'does_not_exist.dart'));
      final result = registrar.registerRepository(
        serviceLocatorFile: missingFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(result.status, DiRegistrationStatus.fileMissing);
      expect(missingFile.existsSync(), isFalse,
          reason: 'must never create the file itself');
    });

    test(
        'reports markersMissing and leaves the file completely untouched when markers are absent',
        () {
      const handEdited = '''
import 'package:get_it/get_it.dart';
final GetIt sl = GetIt.instance;
void configureDependencies() {}
''';
      serviceLocatorFile.writeAsStringSync(handEdited);

      final result = registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(result.status, DiRegistrationStatus.markersMissing);
      expect(serviceLocatorFile.readAsStringSync(), handEdited);
    });

    test('reports markersMissing when only one of the two markers is present',
        () {
      final content = _baseContent().replaceFirst(
        '  // boltforge:registrations\n',
        '',
      );
      serviceLocatorFile.writeAsStringSync(content);

      final result = registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      expect(result.status, DiRegistrationStatus.markersMissing);
      expect(serviceLocatorFile.readAsStringSync(), content);
    });

    test('does not touch unrelated content elsewhere in the file', () {
      final content = _baseContent().replaceFirst(
        'final GetIt sl = GetIt.instance;',
        'final GetIt sl = GetIt.instance;\n\n// A developer comment that must survive.\nconst someUnrelatedConstant = 42;',
      );
      serviceLocatorFile.writeAsStringSync(content);

      registrar.registerRepository(
        serviceLocatorFile: serviceLocatorFile,
        repositoryClassName: 'OfferRepository',
        importPath: '../../features/offer/repository/offer_repository.dart',
      );

      final result = serviceLocatorFile.readAsStringSync();
      expect(result, contains('// A developer comment that must survive.'));
      expect(result, contains('const someUnrelatedConstant = 42;'));
    });
  });
}
