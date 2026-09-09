enum ApiExceptionKind { http, invalidJson, network }

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  const ApiException.http({
    required int statusCode,
    required String? code,
    required String message,
  }) : this(
         kind: ApiExceptionKind.http,
         statusCode: statusCode,
         code: code,
         message: message,
       );

  const ApiException.invalidJson({Object? cause})
    : this(
        kind: ApiExceptionKind.invalidJson,
        message: 'Invalid API response.',
        cause: cause,
      );

  const ApiException.network({Object? cause})
    : this(
        kind: ApiExceptionKind.network,
        message: 'Network request failed.',
        cause: cause,
      );

  final ApiExceptionKind kind;
  final int? statusCode;
  final String? code;
  final String message;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' statusCode=$statusCode';
    final errorCode = code == null ? '' : ' code=$code';
    return 'ApiException($kind$status$errorCode): $message';
  }
}
