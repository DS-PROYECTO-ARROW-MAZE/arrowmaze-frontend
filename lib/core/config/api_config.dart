import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend API configuration.
///
/// Single source of truth for the API base URL and endpoint paths so the
/// HTTP data sources never hard-code URL strings.
abstract final class ApiConfig {
  /// Base URL of the ArrowMaze NestJS backend.
  ///
  /// Resolution order:
  /// 1. An explicit `--dart-define=API_BASE_URL=...` value always wins, so a
  ///    physical device (host LAN IP) or any other target can be pointed
  ///    anywhere at build/run time.
  /// 2. Otherwise the platform is auto-detected: web builds (Chrome) talk to
  ///    the host's `localhost` directly, while Android uses `10.0.2.2`, the
  ///    emulator alias that maps to the host machine's `localhost`.
  ///
  /// All branches are compile-time constants (`kIsWeb` and `bool.hasEnvironment`
  /// are `const`), so `baseUrl` stays a `const`.
  static const String baseUrl = bool.hasEnvironment('API_BASE_URL')
      ? String.fromEnvironment('API_BASE_URL')
      : (kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000');

  /// Register endpoint — `POST /auth/register` (public).
  static const String registerPath = '/auth/register';

  /// Login endpoint — `POST /auth/login` (public).
  static const String loginPath = '/auth/login';

  /// Profile endpoint — `GET /auth/me` (protected).
  static const String mePath = '/auth/me';

  /// Level creation endpoint — `POST /levels` (protected).
  static const String levelsPath = '/levels';

  /// Progress read endpoint — `GET /progress` (protected, Ticket 24).
  static const String progressPath = '/progress';

  /// Progress batch-sync endpoint — `POST /progress/sync` (protected).
  static const String syncPath = '/progress/sync';

  /// Leaderboard read endpoint — `GET /leaderboard` (protected).
  static const String leaderboardPath = '/leaderboard';

  /// Level catalog endpoint — `GET /levels` (public).
  static const String catalogPath = '/levels';
}
