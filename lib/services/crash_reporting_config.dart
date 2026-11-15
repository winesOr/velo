/// A downstream build must explicitly supply its own reporting destination.
abstract final class CrashReportingConfig {
  // TODO(VELO-SENTRY-001): Configure a Velo-owned reporting destination before enabling delivery.
  static const String dsn = String.fromEnvironment('SENTRY_DSN');

  static const bool enabled = bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false) && dsn != '';
}
