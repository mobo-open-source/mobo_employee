/// Centralized application exceptions for consistent error handling.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  AppException(this.message, {this.code, this.cause});
  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? code, Object? cause})
    : super(message, code: code, cause: cause);
}

class ServerException extends AppException {
  ServerException(String message, {String? code, Object? cause})
    : super(message, code: code, cause: cause);
}

class AuthException extends AppException {
  AuthException(String message, {String? code, Object? cause})
    : super(message, code: code, cause: cause);
}

/// Sign-in refused because the Odoo database's subscription has expired.
/// Raised before any session is saved, so nothing of the account is kept.
class DatabaseExpiredException extends AuthException {
  /// When the subscription ended (UTC), if the server said.
  final DateTime? expirationDate;

  /// Odoo's `expiration_reason` ("trial", "renewal", ...), if sent.
  final String? reason;

  DatabaseExpiredException(
    super.message, {
    this.expirationDate,
    this.reason,
  }) : super(code: 'database_expired');
}

/// Sign-in refused because the Odoo database lacks a module the app needs
/// (Employees, Attendance or Time Off). Raised before any session is saved,
/// so nothing of the account is kept.
class RequiredModulesMissingException extends AuthException {
  /// Technical names (`hr_holidays`, ...) of the modules that aren't installed.
  final List<String> missingModules;

  RequiredModulesMissingException(
    super.message, {
    required this.missingModules,
  }) : super(code: 'modules_missing');
}

class ValidationException extends AppException {
  ValidationException(String message, {String? code, Object? cause})
    : super(message, code: code, cause: cause);
}

class UnknownException extends AppException {
  UnknownException(String message, {String? code, Object? cause})
    : super(message, code: code, cause: cause);
}
