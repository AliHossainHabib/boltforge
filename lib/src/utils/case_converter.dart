/// Converts a free-form feature/project name into every casing style the
/// template engine needs. All conversions first normalize the input into
/// a list of lowercase "words" so that `user_profile`, `UserProfile`,
/// `user-profile` and `user profile` all produce identical output.
class NameCase {
  final String snake; // user_profile
  final String pascal; // UserProfile
  final String camel; // userProfile
  final String kebab; // user-profile
  final String title; // User Profile
  final String upperSnake; // USER_PROFILE

  const NameCase._({
    required this.snake,
    required this.pascal,
    required this.camel,
    required this.kebab,
    required this.title,
    required this.upperSnake,
  });

  factory NameCase.from(String input) {
    final words = _splitWords(input);
    final snake = words.join('_');
    final pascal = words.map(_capitalize).join();
    final camel = words.isEmpty
        ? ''
        : _lowerFirst(words.first) + words.skip(1).map(_capitalize).join();
    final kebab = words.join('-');
    final title = words.map(_capitalize).join(' ');
    final upperSnake = words.map((w) => w.toUpperCase()).join('_');

    return NameCase._(
      snake: snake,
      pascal: pascal,
      camel: camel,
      kebab: kebab,
      title: title,
      upperSnake: upperSnake,
    );
  }

  static List<String> _splitWords(String input) {
    // Insert boundaries before capital letters (camel/Pascal -> words),
    // then split on any non-alphanumeric separator.
    final withBoundaries = input.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}_${m[2]}',
    );
    return withBoundaries
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toList();
  }

  static String _capitalize(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

  static String _lowerFirst(String w) =>
      w.isEmpty ? w : w[0].toLowerCase() + w.substring(1);
}
