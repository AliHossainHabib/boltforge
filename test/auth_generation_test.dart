import 'dart:io';

import 'package:boltforge/src/services/file_service.dart';
import 'package:boltforge/src/template_engine/template_context.dart';
import 'package:boltforge/src/template_engine/template_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// See feature_generator_test.dart for why `Directory.current` is a safe
/// stand-in for the package root under `dart test`.
Directory get _realTemplatesRoot =>
    Directory(p.join(Directory.current.path, 'templates'));

/// Renders the base architecture template, then the given auth variant,
/// into [projectDir] — exactly what `ProjectGenerator.generate` does,
/// minus the `flutter create` / `pub get` / `analyze` / `test` process
/// calls (which require an installed Flutter SDK this test environment
/// does not have). This exercises 100% of boltforge's own code (template
/// selection, variable/conditional rendering, file writing) without
/// depending on an external tool.
void applyArchitecture({
  required Directory projectDir,
  required bool usesPassword,
}) {
  final context = TemplateContext.forProject(
    projectName: 'my_app',
    orgIdentifier: 'com.example',
    usesPassword: usesPassword,
  );
  final engine = TemplateEngine(context);
  final fileService = FileService(engine);

  fileService.renderTree(
    templateRoot: Directory(p.join(_realTemplatesRoot.path, 'base')),
    destinationRoot: projectDir,
    onConflict: ConflictAction.overwrite,
  );

  final variant = usesPassword ? 'password' : 'otp';
  fileService.renderTree(
    templateRoot: Directory(p.join(_realTemplatesRoot.path, 'auth', variant)),
    destinationRoot: projectDir,
    onConflict: ConflictAction.overwrite,
  );
}

void expectNoUnrenderedPlaceholders(Directory root) {
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    final content = file.readAsStringSync();
    expect(content, isNot(contains('{{')),
        reason: '${file.path} still contains an unrendered placeholder');
    expect(file.path, isNot(endsWith('.tmpl')),
        reason: '${file.path} leaked a .tmpl suffix onto disk');
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('boltforge_auth_gen_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('sanity: real base and auth template directories exist', () {
    expect(Directory(p.join(_realTemplatesRoot.path, 'base')).existsSync(),
        isTrue);
    expect(
        Directory(p.join(_realTemplatesRoot.path, 'auth', 'password'))
            .existsSync(),
        isTrue);
    expect(
        Directory(p.join(_realTemplatesRoot.path, 'auth', 'otp')).existsSync(),
        isTrue);
  });

  group('Password authentication generation', () {
    late Directory projectDir;

    setUp(() {
      projectDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      applyArchitecture(projectDir: projectDir, usesPassword: true);
    });

    test('leaves no unrendered placeholders or .tmpl files anywhere', () {
      expectNoUnrenderedPlaceholders(projectDir);
    });

    test('generates all three password-flow screens and no OTP screens', () {
      final screenDir = Directory(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'screen',
      ));
      expect(File(p.join(screenDir.path, 'login_screen.dart')).existsSync(),
          isTrue);
      expect(File(p.join(screenDir.path, 'register_screen.dart')).existsSync(),
          isTrue);
      expect(
          File(p.join(screenDir.path, 'forgot_password_screen.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(screenDir.path, 'verification_screen.dart')).existsSync(),
          isFalse);
      expect(
          File(p.join(screenDir.path, 'create_account_screen.dart'))
              .existsSync(),
          isFalse);
    });

    test('generates the expected class names in each screen', () {
      final screenDir = Directory(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'screen',
      ));
      expect(
          File(p.join(screenDir.path, 'login_screen.dart')).readAsStringSync(),
          contains('class LoginScreen extends StatelessWidget'));
      expect(
          File(p.join(screenDir.path, 'register_screen.dart'))
              .readAsStringSync(),
          contains('class RegisterScreen extends StatelessWidget'));
      expect(
          File(p.join(screenDir.path, 'forgot_password_screen.dart'))
              .readAsStringSync(),
          contains('class ForgotPasswordScreen extends StatelessWidget'));
    });

    test('AuthCubit exposes login/register/forgotPassword and no OTP methods',
        () {
      final cubit = File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'cubit',
        'auth_cubit.dart',
      )).readAsStringSync();
      expect(cubit, contains('class AuthCubit extends Cubit<AuthState>'));
      expect(cubit, contains('Future<void> login({'));
      expect(cubit, contains('Future<void> register({'));
      expect(cubit, contains('Future<void> forgotPassword({'));
      expect(cubit, isNot(contains('requestOtp')));
      expect(cubit, isNot(contains('verifyOtp')));
    });

    test('AuthRepository posts to the password-flow endpoints', () {
      final repository = File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'repository',
        'auth_repository.dart',
      )).readAsStringSync();
      expect(repository, contains('class AuthRepository'));
      expect(repository, contains('ApiConstants.login'));
      expect(repository, contains('ApiConstants.register'));
      expect(repository, contains('ApiConstants.forgotPassword'));
    });

    test('routes.dart declares password routes and not OTP routes', () {
      final routes = File(p.join(
        projectDir.path,
        'lib',
        'core',
        'router',
        'routes.dart',
      )).readAsStringSync();
      expect(routes, contains("static const String login = '/login';"));
      expect(routes, contains("static const String register = '/register';"));
      expect(routes,
          contains("static const String forgotPassword = '/forgot-password';"));
      expect(routes, isNot(contains('verify')));
      expect(routes, isNot(contains('createAccount')));
    });

    test(
        'app_router.dart imports and routes to LoginScreen, not VerificationScreen',
        () {
      final router = File(p.join(
        projectDir.path,
        'lib',
        'core',
        'router',
        'app_router.dart',
      )).readAsStringSync();
      expect(
          router,
          contains(
              "import '../../features/auth/presentation/screen/login_screen.dart';"));
      expect(router, contains('case Routes.login:'));
      expect(router, isNot(contains('verification_screen.dart')));
      expect(router, isNot(contains('Routes.verify')));
    });

    test('splash_screen.dart redirects to the login route when unauthenticated',
        () {
      final splash = File(p.join(
        projectDir.path,
        'lib',
        'app',
        'splash_screen.dart',
      )).readAsStringSync();
      expect(splash, contains(': Routes.login;'));
      expect(splash, isNot(contains('Routes.verify')));
    });

    test(
        'the generated test/widget_test.dart imports the real project package name',
        () {
      final widgetTest =
          File(p.join(projectDir.path, 'test', 'widget_test.dart'))
              .readAsStringSync();
      expect(widgetTest,
          contains("import 'package:my_app/app/splash_screen.dart';"));
    });
  });

  group('OTP authentication generation', () {
    late Directory projectDir;

    setUp(() {
      projectDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      applyArchitecture(projectDir: projectDir, usesPassword: false);
    });

    test('leaves no unrendered placeholders or .tmpl files anywhere', () {
      expectNoUnrenderedPlaceholders(projectDir);
    });

    test('generates the OTP-flow screens and no password screens', () {
      final screenDir = Directory(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'screen',
      ));
      expect(
          File(p.join(screenDir.path, 'verification_screen.dart')).existsSync(),
          isTrue);
      expect(
          File(p.join(screenDir.path, 'create_account_screen.dart'))
              .existsSync(),
          isTrue);
      expect(File(p.join(screenDir.path, 'login_screen.dart')).existsSync(),
          isFalse);
      expect(File(p.join(screenDir.path, 'register_screen.dart')).existsSync(),
          isFalse);
      expect(
          File(p.join(screenDir.path, 'forgot_password_screen.dart'))
              .existsSync(),
          isFalse);
    });

    test('generates the expected class names in each screen', () {
      final screenDir = Directory(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'screen',
      ));
      expect(
          File(p.join(screenDir.path, 'verification_screen.dart'))
              .readAsStringSync(),
          contains('class VerificationScreen extends StatelessWidget'));
      expect(
          File(p.join(screenDir.path, 'create_account_screen.dart'))
              .readAsStringSync(),
          contains('class CreateAccountScreen extends StatelessWidget'));
    });

    test(
        'AuthCubit exposes requestOtp/verifyOtp/completeProfile and no password methods',
        () {
      final cubit = File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'cubit',
        'auth_cubit.dart',
      )).readAsStringSync();
      expect(cubit, contains('class AuthCubit extends Cubit<AuthState>'));
      expect(cubit, contains('Future<void> requestOtp({'));
      expect(cubit, contains('Future<void> verifyOtp({'));
      expect(cubit, contains('Future<void> completeProfile({'));
      expect(cubit, isNot(contains('Future<void> login(')));
      expect(cubit, isNot(contains('Future<void> register(')));
    });

    test('AuthState includes OtpSent and VerifiedNeedsProfile', () {
      final state = File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'cubit',
        'auth_state.dart',
      )).readAsStringSync();
      expect(state, contains('class OtpSent extends AuthState'));
      expect(state, contains('class VerifiedNeedsProfile extends AuthState'));
    });

    test('AuthRepository posts to the OTP-flow endpoints', () {
      final repository = File(p.join(
        projectDir.path,
        'lib',
        'features',
        'auth',
        'repository',
        'auth_repository.dart',
      )).readAsStringSync();
      expect(repository, contains('ApiConstants.requestOtp'));
      expect(repository, contains('ApiConstants.verifyOtp'));
    });

    test('routes.dart declares OTP routes and not password routes', () {
      final routes = File(p.join(
        projectDir.path,
        'lib',
        'core',
        'router',
        'routes.dart',
      )).readAsStringSync();
      expect(routes, contains("static const String verify = '/verify';"));
      expect(routes,
          contains("static const String createAccount = '/create-account';"));
      expect(routes, isNot(contains('String login')));
      expect(routes, isNot(contains('String register')));
    });

    test(
        'app_router.dart imports and routes to VerificationScreen, not LoginScreen',
        () {
      final router = File(p.join(
        projectDir.path,
        'lib',
        'core',
        'router',
        'app_router.dart',
      )).readAsStringSync();
      expect(
        router,
        contains(
            "import '../../features/auth/presentation/screen/verification_screen.dart';"),
      );
      expect(router, contains('case Routes.verify:'));
      expect(router, isNot(contains('login_screen.dart')));
    });

    test(
        'splash_screen.dart redirects to the verify route when unauthenticated',
        () {
      final splash = File(p.join(
        projectDir.path,
        'lib',
        'app',
        'splash_screen.dart',
      )).readAsStringSync();
      expect(splash, contains(': Routes.verify;'));
      expect(splash, isNot(contains('Routes.login')));
    });
  });

  group('Shared base architecture (applies regardless of auth mode)', () {
    test('service_locator.dart registers AuthRepository as a lazy singleton',
        () {
      final projectDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      applyArchitecture(projectDir: projectDir, usesPassword: true);

      final di = File(p.join(
        projectDir.path,
        'lib',
        'core',
        'di',
        'service_locator.dart',
      )).readAsStringSync();
      expect(di, contains('sl.registerLazySingleton<AuthRepository>'));
    });

    test('app.dart renders the project title into the MaterialApp', () {
      final projectDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      applyArchitecture(projectDir: projectDir, usesPassword: true);

      final app = File(p.join(projectDir.path, 'lib', 'app', 'app.dart'))
          .readAsStringSync();
      expect(app, contains("title: 'My App'"));
    });

    test(
        're-applying the architecture re-renders identical content (idempotent)',
        () {
      final projectDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      applyArchitecture(projectDir: projectDir, usesPassword: true);
      final routesFile =
          File(p.join(projectDir.path, 'lib', 'core', 'router', 'routes.dart'));
      final firstContent = routesFile.readAsStringSync();

      applyArchitecture(projectDir: projectDir, usesPassword: true);
      expect(routesFile.readAsStringSync(), firstContent);
    });
  });
}
