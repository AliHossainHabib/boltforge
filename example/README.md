# boltforge example

boltforge is a command-line tool, not an importable library, so this
example is a terminal walkthrough rather than a `.dart` file — every
command and output below reflects the tool's actual, tested behavior.

## 1. Install

```bash
dart pub global activate boltforge
```

## 2. Check your environment

```bash
boltforge doctor
```

```text
boltforge doctor

boltforge 0.1.0
  ✔ Dart SDK found: Dart SDK version: 3.x.x ...
  ✔ Flutter found: Flutter 3.x.x • channel stable • ...

Everything is set up. You are ready to run `boltforge create`.
```

## 3. Create a project with password authentication

```bash
boltforge create shop_app --auth=password
```

This runs `flutter create`, adds `flutter_bloc`, `dio`, `get_it`, and
`shared_preferences`, applies the base `lib/core/` architecture, generates
a login / register / forgot-password flow, then runs `flutter pub get`,
`flutter analyze`, and `flutter test` — stopping and reporting clearly if
any step fails.

Prefer an OTP (email/phone verification, no password) flow instead?

```bash
boltforge create shop_app --auth=otp
```

## 4. Generate a feature inside the new project

```bash
cd shop_app
boltforge generate offer
```

```text
boltforge — generating feature "offer"

  ✔ Wrote lib/features/offer/model/offer_model.dart
  ✔ Wrote lib/features/offer/repository/offer_repository.dart
  ✔ Wrote lib/features/offer/cubit/offer_state.dart
  ✔ Wrote lib/features/offer/cubit/offer_cubit.dart
  ✔ Wrote lib/features/offer/presentation/screen/offer_screen.dart
  ✔ Wrote lib/features/offer/presentation/widgets/offer_list_item.dart

  ✔ DI: registered the repository in lib/core/di/service_locator.dart automatically.

Feature "offer" generated.
Run `flutter analyze` to confirm imports resolve, then wire the screen into your router.
```

`OfferRepository` is registered in `lib/core/di/service_locator.dart`
automatically — no manual edit needed. Running `generate offer` again
will not create a duplicate registration; if the feature already exists,
you'll be prompted to cancel, overwrite, or merge.

## 5. Point it at your backend

Everything above works against any REST backend. Fill in one file:

```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://api.example.com'; // was empty
  // ...
}
```

## Further reading

The full documentation (in Arabic; code and commands stay in English) is
under [`docs/`](../doc/index.html) in the repository, including a
complete walkthrough of everything the feature generator does and how to
extend it.
