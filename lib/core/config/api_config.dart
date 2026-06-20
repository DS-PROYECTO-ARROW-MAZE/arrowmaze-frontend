/// Backend API configuration.
///
/// Single source of truth for the API base URL and endpoint paths so the
/// HTTP data source never hard-codes URL strings.
abstract final class ApiConfig {
  /// Base URL of the ArrowMaze backend.
  static const String baseUrl = 'http://localhost:8080/api';

  /// Register endpoint.
  static const String registerPath = '/auth/register';

  /// Login endpoint.
  static const String loginPath = '/auth/login';
}
