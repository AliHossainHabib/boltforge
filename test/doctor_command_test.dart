import 'package:boltforge/src/services/process_service.dart';
import 'package:boltforge/src/commands/doctor_command.dart';
import 'package:boltforge/src/utils/logger.dart';
import 'package:test/test.dart';

import 'support/fake_process_service.dart';

void main() {
  test('returns 0 when both dart and flutter are available', () async {
    final command = DoctorCommand(
      logger: Logger(colorEnabled: false),
      process: FakeProcessService(),
    );
    final code = await command.run();
    expect(code, 0);
  });

  test('returns 1 when flutter --version fails', () async {
    final command = DoctorCommand(
      logger: Logger(colorEnabled: false),
      process: FakeProcessService(
        onRun: (executable, args) {
          if (executable == 'flutter') {
            return const ProcessOutcome(
              succeeded: false,
              exitCode: 127,
              stdout: '',
              stderr: 'command not found',
            );
          }
          return const ProcessOutcome(
              succeeded: true, exitCode: 0, stdout: '', stderr: '');
        },
      ),
    );
    final code = await command.run();
    expect(code, 1);
  });

  test('returns 1 when dart --version fails', () async {
    final command = DoctorCommand(
      logger: Logger(colorEnabled: false),
      process: FakeProcessService(
        onRun: (executable, args) {
          if (executable == 'dart') {
            return const ProcessOutcome(
              succeeded: false,
              exitCode: 127,
              stdout: '',
              stderr: 'command not found',
            );
          }
          return const ProcessOutcome(
              succeeded: true, exitCode: 0, stdout: '', stderr: '');
        },
      ),
    );
    final code = await command.run();
    expect(code, 1);
  });
}
