import 'dart:io';

import 'package:boltforge/src/services/process_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final service = ProcessService();

  group('ProcessService.run', () {
    test('reports success and captures stdout for a real command', () async {
      final outcome = await service.run('echo', ['hello from boltforge']);

      expect(outcome.succeeded, isTrue);
      expect(outcome.exitCode, 0);
      expect(outcome.stdout, contains('hello from boltforge'));
    });

    test('reports failure for a command that exits non-zero', () async {
      // `sh -c "exit 7"` via a shell built-in is a portable way to force
      // a specific non-zero exit code without depending on any one binary.
      final outcome = await service.run('sh', ['-c', 'exit 7']);

      expect(outcome.succeeded, isFalse);
      expect(outcome.exitCode, 7);
    });

    test(
        'reports failure (not a thrown exception) for a nonexistent executable',
        () async {
      final outcome = await service.run(
        'definitely_not_a_real_executable_xyz123',
        ['--version'],
      );

      expect(outcome.succeeded, isFalse);
    });

    test('runs in the given working directory', () async {
      // Root cause of the original flaky/failing version of this test:
      // it hardcoded the POSIX path '/tmp' and shelled out to `pwd`. On
      // native Windows, `/tmp` is not a resolvable working directory at
      // all (there is no single-rooted filesystem), so `Process.run`
      // fails to even start the process — `outcome.succeeded` comes back
      // false before the stdout comparison is ever reached. `pwd` is also
      // not a real Windows command; it only "worked" by accident when a
      // Unix-like toolchain (e.g. Git Bash) happened to be on PATH.
      //
      // Fixed by using two things guaranteed to be correct on every
      // platform this test can possibly run on:
      //   - `Directory.systemTemp`, which already returns a valid,
      //     platform-native absolute path (POSIX on Linux/macOS,
      //     `C:\Users\...\Temp\...`-style on Windows) instead of a
      //     hardcoded Unix path.
      //   - `dart` itself as the "reporter" of the process's working
      //     directory, since `dart test` cannot run at all without a
      //     `dart` executable on PATH — unlike `pwd`, it is never a
      //     shell built-in and behaves identically on every OS.
      final tempDir = Directory.systemTemp
          .createTempSync('boltforge_process_service_test_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final script = File(p.join(tempDir.path, '_print_cwd.dart'))
        ..writeAsStringSync(
          "import 'dart:io';\nvoid main() => print(Directory.current.path);\n",
        );

      final outcome = await service.run(
        'dart',
        [script.path],
        workingDirectory: tempDir.path,
      );

      expect(outcome.succeeded, isTrue, reason: outcome.stderr);
      // Compare via package:path so platform-specific separators/case
      // sensitivity don't cause a false mismatch — the check still
      // proves the child process's actual cwd was the directory we asked
      // for, byte-for-byte in intent.
      expect(
        p.equals(outcome.stdout.trim(), tempDir.path),
        isTrue,
        reason: 'expected the process\'s working directory to be '
            '"${tempDir.path}" but the process reported '
            '"${outcome.stdout.trim()}"',
      );
    });
  });

  group('ProcessService.isAvailable', () {
    test('returns true for a command that exists and succeeds', () async {
      final available = await service.isAvailable('ls', args: ['--version']);
      expect(available, isTrue);
    });

    test('returns false for a command that does not exist', () async {
      final available =
          await service.isAvailable('definitely_not_a_real_executable_xyz123');
      expect(available, isFalse);
    });
  });
}
