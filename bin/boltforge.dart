import 'dart:io';
import 'package:args/command_runner.dart';

import 'package:boltforge/src/cli_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = BoltforgeRunner();
  try {
    final exitCode = await runner.run(arguments);
    exit(exitCode ?? 0);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(64);
  }
}
