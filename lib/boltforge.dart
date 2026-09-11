/// Public entry point for the boltforge package. Kept intentionally tiny:
/// boltforge is consumed as a CLI (see bin/boltforge.dart), not as a
/// library, so this file only exposes the version constant used by
/// `boltforge --version` and `boltforge doctor`.
const String boltforgeVersion = '0.1.0';
