/// Backend API configuration.
///
/// Single source of truth for the API base URL and endpoint paths so the
/// HTTP data sources never hard-code URL strings.
abstract final class ApiConfig {
  /// Base URL of the ArrowMaze NestJS backend.
  ///
  /// Configurable at build/run time via `--dart-define=API_BASE_URL=...`,
  /// falling back to the local backend (`http://localhost:3000`). Keeping it in
  /// an environment value means no environment-specific URL is ever hard-coded.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

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
