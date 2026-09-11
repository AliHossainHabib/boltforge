import 'package:boltforge/src/services/process_service.dart';

class RecordedCall {
  final String executable;
  final List<String> args;
  final String? workingDirectory;
  const RecordedCall(this.executable, this.args, this.workingDirectory);

  @override
  String toString() => '$executable ${args.join(' ')} (cwd: $workingDirectory)';
}

/// A [ProcessService] test double: never spawns a real process. Callers
/// configure per-executable availability and per-command outcomes; every
/// call is recorded so tests can assert on call order (e.g. "flutter
/// create ran before flutter pub get").
class FakeProcessService implements ProcessService {
  final List<RecordedCall> calls = [];
  final Map<String, bool> _availability;
  final ProcessOutcome Function(String executable, List<String> args)? _onRun;
  final ProcessOutcome _defaultOutcome;

  FakeProcessService({
    Map<String, bool> availability = const {},
    ProcessOutcome Function(String executable, List<String> args)? onRun,
    ProcessOutcome? defaultOutcome,
  })  : _availability = availability,
        _onRun = onRun,
        _defaultOutcome = defaultOutcome ??
            const ProcessOutcome(
                succeeded: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<bool> isAvailable(String executable,
      {List<String> args = const ['--version']}) async {
    return _availability[executable] ?? true;
  }

  @override
  Future<ProcessOutcome> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    calls.add(RecordedCall(executable, args, workingDirectory));
    final onRun = _onRun;
    if (onRun != null) {
      return onRun(executable, args);
    }
    return _defaultOutcome;
  }
}
