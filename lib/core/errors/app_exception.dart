class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(String message) : super(message, statusCode: 0);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException()
    : super('Session expired. Please sign in again.', statusCode: 401);
}

class ServerException extends AppException {
  const ServerException(String message) : super(message, statusCode: 500);
}
