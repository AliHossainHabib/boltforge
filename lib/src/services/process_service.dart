import 'dart:io';

/// Result of running an external command. Kept separate from raw
/// [ProcessResult] so callers depend on a small, stable contract instead of
/// `dart:io` process internals.
class ProcessOutcome {
  final bool succeeded;
  final int exitCode;
  final String stdout;
  final String stderr;

  const ProcessOutcome({
    required this.succeeded,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

/// Thin wrapper around [Process.run] for shelling out to `flutter` and
/// `dart`. Centralized so every command in the CLI reports failures the
/// same way — never "Project created successfully!" after a step actually
/// failed.
class ProcessService {
  /// Returns true if [executable] is on PATH and runs without error.
  Future<bool> isAvailable(String executable,
      {List<String> args = const ['--version']}) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<ProcessOutcome> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      return ProcessOutcome(
        succeeded: result.exitCode == 0,
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      return ProcessOutcome(
        succeeded: false,
        exitCode: -1,
        stdout: '',
        stderr: 'Failed to start "$executable": ${e.message}',
      );
    }
  }
}
