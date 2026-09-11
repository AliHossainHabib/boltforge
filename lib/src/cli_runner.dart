import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../boltforge.dart' show boltforgeVersion;
import 'commands/create_command.dart';
import 'commands/doctor_command.dart';
import 'commands/generate_command.dart';

class BoltforgeRunner extends CommandRunner<int> {
  BoltforgeRunner()
      : super(
          'boltforge',
          'Scaffold production-ready Flutter projects and generate '
              'features with a consistent Cubit + Repository architecture.',
        ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the boltforge version.',
    );
    addCommand(CreateCommand());
    addCommand(GenerateCommand());
    addCommand(DoctorCommand());
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      print('boltforge $boltforgeVersion');
      return 0;
    }
    return super.runCommand(topLevelResults);
  }
}
