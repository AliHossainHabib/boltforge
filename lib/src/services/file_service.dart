import 'dart:io';
import 'package:path/path.dart' as p;

import '../template_engine/template_engine.dart';

enum ConflictAction { cancel, overwrite, merge }

/// Copies a template directory tree onto disk, rendering both file
/// contents and file/directory *names* through [TemplateEngine].
///
/// "Merge" means: write files that don't yet exist, skip files that do.
/// This is deliberately conservative — silently overwriting a developer's
/// hand-edited feature file is worse than leaving a stale copy in place.
class FileService {
  final TemplateEngine engine;

  const FileService(this.engine);

  /// Returns the list of *relative* output paths that would be written,
  /// without touching disk. Used to detect conflicts before generation.
  List<String> planOutputPaths(Directory templateRoot) {
    final paths = <String>[];
    for (final entity in templateRoot.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: templateRoot.path);
      final renderedParts =
          p.split(relative).map(engine.renderPathSegment).toList();
      paths.add(p.joinAll(renderedParts));
    }
    return paths;
  }

  /// Renders every file under [templateRoot] into [destinationRoot].
  ///
  /// Returns the list of files actually written (for reporting /
  /// import-validation afterwards).
  List<String> renderTree({
    required Directory templateRoot,
    required Directory destinationRoot,
    required ConflictAction onConflict,
  }) {
    // Cancel means "touch nothing at all" — not merely "don't overwrite
    // existing files". Bail out before writing anything, including files
    // that don't exist yet, so a cancelled generation is a true no-op.
    if (onConflict == ConflictAction.cancel) {
      return const [];
    }

    final written = <String>[];

    for (final entity in templateRoot.listSync(recursive: true)) {
      if (entity is! File) continue;

      final relative = p.relative(entity.path, from: templateRoot.path);
      final renderedParts =
          p.split(relative).map(engine.renderPathSegment).toList();
      final outputPath = p.joinAll([destinationRoot.path, ...renderedParts]);
      final outputFile = File(outputPath);

      if (outputFile.existsSync() && onConflict == ConflictAction.merge) {
        continue; // Existing file wins; do not touch it.
      }

      final content = entity.readAsStringSync();
      final rendered = engine.render(content);

      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(rendered);
      written.add(outputPath);
    }

    return written;
  }
}
