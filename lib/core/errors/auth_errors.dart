/// Shared error codes for authentication.
///
/// Used by the data source to signal specific failures to the use case, which
/// maps them onto the user-facing sealed result types.
abstract final class AuthErrorCode {
  static const String emailDuplicado = 'EMAIL_DUPLICATE';
  static const String credencialesInvalidas = 'INVALID_CREDENTIALS';
  static const String servidorError = 'SERVER_ERROR';
}
