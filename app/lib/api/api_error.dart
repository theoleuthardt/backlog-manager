import 'package:dio/dio.dart';

/// A failed backend call with the message to show the user.
///
/// Every route handler answers errors with Litestar's default
/// `{status_code, detail, ...}` body; `detail` is what belongs in toasts and
/// inline form errors, anything else (network failures, unexpected bodies)
/// uses the caller's fallback text.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  factory ApiException.from(Object error, String fallback) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final body = error.response?.data;
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      return ApiException(
        detail is String && detail.isNotEmpty ? detail : fallback,
        statusCode: error.response?.statusCode,
      );
    }
    return ApiException(fallback);
  }

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
