import 'package:boltforge/src/template_engine/template_context.dart';
import 'package:boltforge/src/template_engine/template_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateEngine.render — variables', () {
    test('substitutes a single variable', () {
      final engine = TemplateEngine(
        const TemplateContext(variables: {'projectName': 'my_app'}),
      );
      expect(engine.render('name: {{projectName}}'), 'name: my_app');
    });

    test('substitutes the same variable multiple times', () {
      final engine = TemplateEngine(
        const TemplateContext(variables: {'featureName': 'offer'}),
      );
      expect(
        engine.render('{{featureName}}_cubit and {{featureName}}_state'),
        'offer_cubit and offer_state',
      );
    });

    test('substitutes multiple distinct variables', () {
      final engine = TemplateEngine(
        const TemplateContext(
          variables: {'featureName': 'offer', 'featureNamePascal': 'Offer'},
        ),
      );
      expect(
        engine.render('class {{featureNamePascal}}Model // {{featureName}}'),
        'class OfferModel // offer',
      );
    });

    test('tolerates surrounding whitespace inside the braces', () {
      final engine = TemplateEngine(
        const TemplateContext(variables: {'projectName': 'my_app'}),
      );
      expect(engine.render('{{ projectName }}'), 'my_app');
    });

    test('throws TemplateVariableError for an unknown variable', () {
      final engine = TemplateEngine(const TemplateContext());
      expect(
        () => engine.render('{{unknownVar}}'),
        throwsA(isA<TemplateVariableError>()),
      );
    });

    test('leaves plain text with no placeholders untouched', () {
      final engine = TemplateEngine(const TemplateContext());
      expect(engine.render('import "package:flutter/material.dart";'),
          'import "package:flutter/material.dart";');
    });
  });

  group('TemplateEngine.render — conditionals', () {
    test('keeps an #if block when the flag is true', () {
      final engine = TemplateEngine(
        const TemplateContext(flags: {'authPassword': true}),
      );
      final result = engine.render(
        'before{{#if authPassword}}MIDDLE{{/if}}after',
      );
      expect(result, 'beforeMIDDLEafter');
    });

    test('removes an #if block when the flag is false', () {
      final engine = TemplateEngine(
        const TemplateContext(flags: {'authPassword': false}),
      );
      final result = engine.render(
        'before{{#if authPassword}}MIDDLE{{/if}}after',
      );
      expect(result, 'beforeafter');
    });

    test('keeps an #unless block when the flag is false', () {
      final engine = TemplateEngine(
        const TemplateContext(flags: {'authOtp': false}),
      );
      final result = engine.render(
        'before{{#unless authOtp}}MIDDLE{{/unless}}after',
      );
      expect(result, 'beforeMIDDLEafter');
    });

    test('removes an #unless block when the flag is true', () {
      final engine = TemplateEngine(
        const TemplateContext(flags: {'authOtp': true}),
      );
      final result = engine.render(
        'before{{#unless authOtp}}MIDDLE{{/unless}}after',
      );
      expect(result, 'beforeafter');
    });

    test('does not evaluate variables that only exist inside a removed block',
        () {
      final engine = TemplateEngine(
        const TemplateContext(
          variables: {}, // otpOnlyVar deliberately absent
          flags: {'authOtp': false},
        ),
      );
      // {{otpOnlyVar}} lives inside a block that is stripped because the
      // flag is false — it must never reach variable substitution, or
      // this would throw even though the value was never needed.
      final result = engine.render(
        'x{{#if authOtp}}{{otpOnlyVar}}{{/if}}y',
      );
      expect(result, 'xy');
    });

    test('throws for an #if block referencing an unknown flag', () {
      final engine = TemplateEngine(const TemplateContext());
      expect(
        () => engine.render('{{#if unknownFlag}}x{{/if}}'),
        throwsA(isA<TemplateVariableError>()),
      );
    });

    test('handles multiple independent conditional blocks in one template', () {
      final engine = TemplateEngine(
        const TemplateContext(
          flags: {'authPassword': true, 'authOtp': false},
        ),
      );
      final result = engine.render(
        '{{#if authPassword}}A{{/if}}{{#if authOtp}}B{{/if}}',
      );
      expect(result, 'A');
    });

    test('renders variables and conditionals together', () {
      final engine = TemplateEngine(
        const TemplateContext(
          variables: {'featureNamePascal': 'Offer'},
          flags: {'authPassword': true},
        ),
      );
      final result = engine.render(
        'class {{featureNamePascal}}Cubit {{#if authPassword}}extends Auth{{/if}} {}',
      );
      expect(result, 'class OfferCubit extends Auth {}');
    });
  });

  group('TemplateEngine.renderPathSegment', () {
    test('renders a variable in a file name and strips .tmpl', () {
      final engine = TemplateEngine(
        const TemplateContext(variables: {'featureName': 'offer'}),
      );
      expect(
        engine.renderPathSegment('{{featureName}}_cubit.dart.tmpl'),
        'offer_cubit.dart',
      );
    });

    test('renders a variable in a directory name with no .tmpl suffix', () {
      final engine = TemplateEngine(
        const TemplateContext(variables: {'featureName': 'offer'}),
      );
      expect(engine.renderPathSegment('{{featureName}}'), 'offer');
    });

    test('leaves a plain segment with no placeholder and no .tmpl untouched',
        () {
      final engine = TemplateEngine(const TemplateContext());
      expect(engine.renderPathSegment('cubit'), 'cubit');
    });

    test('strips .tmpl from a segment with no placeholders', () {
      final engine = TemplateEngine(const TemplateContext());
      expect(engine.renderPathSegment('routes.dart.tmpl'), 'routes.dart');
    });
  });

  group('TemplateContext.forProject', () {
    test('derives every project name casing and the correct auth flags', () {
      final context = TemplateContext.forProject(
        projectName: 'my_cool_app',
        orgIdentifier: 'com.example',
        usesPassword: true,
      );
      expect(context.variables['projectName'], 'my_cool_app');
      expect(context.variables['projectNamePascal'], 'MyCoolApp');
      expect(context.variables['projectNameCamel'], 'myCoolApp');
      expect(context.variables['projectNameKebab'], 'my-cool-app');
      expect(context.variables['projectNameTitle'], 'My Cool App');
      expect(context.variables['orgIdentifier'], 'com.example');
      expect(context.flags['authPassword'], isTrue);
      expect(context.flags['authOtp'], isFalse);
    });

    test('flips the auth flags for the OTP variant', () {
      final context = TemplateContext.forProject(
        projectName: 'my_app',
        orgIdentifier: 'com.example',
        usesPassword: false,
      );
      expect(context.flags['authPassword'], isFalse);
      expect(context.flags['authOtp'], isTrue);
    });
  });

  group('TemplateContext.forFeature', () {
    test('derives every feature name casing and carries the package name', () {
      final context = TemplateContext.forFeature(
        featureName: 'user_profile',
        packageName: 'my_app',
      );
      expect(context.variables['featureName'], 'user_profile');
      expect(context.variables['featureNamePascal'], 'UserProfile');
      expect(context.variables['featureNameCamel'], 'userProfile');
      expect(context.variables['featureNameKebab'], 'user-profile');
      expect(context.variables['featureNameTitle'], 'User Profile');
      expect(context.variables['packageName'], 'my_app');
    });
  });
}
