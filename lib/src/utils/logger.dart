import 'dart:io';

/// Minimal ANSI-aware logger. No external dependency — this is the whole
/// UX surface of the tool, so it stays simple and dependency-free.
class Logger {
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _cyan = '\x1B[36m';
  static const _bold = '\x1B[1m';
  static const _reset = '\x1B[0m';

  final bool _colorEnabled;

  Logger({bool? colorEnabled})
      : _colorEnabled = colorEnabled ?? stdout.supportsAnsiEscapes;

  String _c(String code, String text) =>
      _colorEnabled ? '$code$text$_reset' : text;

  void title(String text) => print('\n${_c(_bold, text)}\n');

  void step(String text) => print('  ${_c(_cyan, '→')} $text');

  void success(String text) => print('  ${_c(_green, '✔')} $text');

  void warn(String text) => print('  ${_c(_yellow, '⚠')} $text');

  void error(String text) => print('  ${_c(_red, '✖')} $text');

  void info(String text) => print('  $text');

  void blank() => print('');
}
