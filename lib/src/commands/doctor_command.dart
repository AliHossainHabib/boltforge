import 'package:args/command_runner.dart';

import '../../boltforge.dart' show boltforgeVersion;
// Note: relative to lib/src/commands/, lib/boltforge.dart is '../../boltforge.dart'.
import '../services/process_service.dart';
import '../utils/logger.dart';

class DoctorCommand extends Command<int> {
  @override
  final name = 'doctor';
  @override
  final description =
      'Check that Flutter, Dart, and boltforge are set up correctly.';

  final Logger logger;
  final ProcessService process;

  DoctorCommand({Logger? logger, ProcessService? process})
      : logger = logger ?? Logger(),
        process = process ?? ProcessService();

  @override
  Future<int> run() async {
    logger.title('boltforge doctor');

    var allOk = true;

    logger.info('boltforge $boltforgeVersion');

    final dartOutcome = await process.run('dart', ['--version']);
    if (dartOutcome.succeeded || dartOutcome.stderr.contains('Dart SDK')) {
      logger.success(
          'Dart SDK found: ${(dartOutcome.stdout + dartOutcome.stderr).trim()}');
    } else {
      allOk = false;
      logger.error('Dart SDK not found on PATH.');
    }

    final flutterOutcome = await process.run('flutter', ['--version']);
    if (flutterOutcome.succeeded) {
      final firstLine = flutterOutcome.stdout.split('\n').first.trim();
      logger.success('Flutter found: $firstLine');
    } else {
      allOk = false;
      logger.error(
        'Flutter not found on PATH. `boltforge create` requires Flutter.',
      );
    }

    logger.blank();
    if (allOk) {
      logger.title(
          'Everything is set up. You are ready to run `boltforge create`.');
      return 0;
    } else {
      logger.title(
          'Some checks failed — fix the issues above and re-run `boltforge doctor`.');
      return 1;
    }
  }
}
