/// What the sign-in shows when a request fails: a one-line [SignInFailure.title]
/// for the banner, and behind a button a sentence on what went wrong and what
/// to do plus a details line (kind of error, host, HTTP status, Cloudflare Ray
/// ID, time) that makes a copied report enough to find the cause. A `detail`
/// from the backend is shown as it is, without more.
library;

import 'dart:io';

import 'package:backlog_manager/api/api_error.dart';
import 'package:dio/dio.dart';

const _refused = {111, 61, 10061};
const _unreachable = {101, 51, 10051};
const _timedOut = {110, 60, 10060};

/// A failed sign-in request as the sign-in page shows it.
class SignInFailure {
  const SignInFailure(this.title, {this.explanation, this.details});

  final String title;
  final String? explanation;
  final String? details;

  /// Whether there is more to show than the title.
  bool get hasMore => explanation != null || details != null;

  /// Every line, for copying into a message.
  String get report => [title, ?explanation, ?details].join('\n');
}

/// The failure for an error of a sign-in, two-factor or session request;
/// [fallback] titles errors that did not come from a request.
SignInFailure describeSignInFailure(
  Object error, {
  required String fallback,
  required DateTime now,
}) {
  final time = _clock(now);
  if (error is ApiException) return SignInFailure(error.message);
  if (error is TypeError || error is FormatException) {
    return SignInFailure(
      'Not a Backlog Manager server',
      explanation:
          'The server answered, but it is not a Backlog Manager server. '
          'Check the server address.',
      details: 'unexpected answer · $time',
    );
  }
  if (error is! DioException) {
    return SignInFailure(
      fallback,
      details: 'unexpected error (${error.runtimeType}) · $time',
    );
  }
  final host = _host(error.requestOptions.uri);
  SignInFailure failed(
    String title,
    String explanation,
    String kind, {
    String? ray,
  }) => SignInFailure(
    title,
    explanation: explanation,
    details: [kind, host, ?ray, time].join(' · '),
  );
  const notReachable = 'Server not reachable';
  const notBacklogManager = 'Not a Backlog Manager server';
  final notBacklogManagerExplanation =
      '$host answered, but it is not a Backlog Manager server. '
      'Check the server address.';

  final response = error.response;
  if (response != null) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    final detail = body is Map ? body['detail'] : null;
    final ray = response.headers.value('cf-ray');
    final cloudflareRay = ray == null ? null : 'Cloudflare Ray $ray';
    final fromBackend = body is Map;
    if (status == 429) {
      return failed(
        'Too many sign-in attempts',
        'Wait a minute and try again.',
        'HTTP 429',
      );
    }
    if (detail is String && detail.isNotEmpty) return SignInFailure(detail);
    if (status >= 500 && !fromBackend) {
      return failed(
        'Server does not answer',
        '$host is reachable, but the Backlog Manager behind it does not '
            'answer. Try again later.',
        'HTTP $status',
        ray: cloudflareRay,
      );
    }
    if (status >= 500) {
      return failed(
        'Server error',
        'The server had a problem. Try again later.',
        'HTTP $status',
      );
    }
    if (status == 403 && cloudflareRay != null && !fromBackend) {
      return failed(
        'Blocked by a firewall',
        '$host blocked the sign-in at its firewall.',
        'HTTP 403',
        ray: cloudflareRay,
      );
    }
    if (status == 404 || status == 405 || !fromBackend) {
      return failed(
        notBacklogManager,
        notBacklogManagerExplanation,
        'HTTP $status',
        ray: cloudflareRay,
      );
    }
    return failed(
      'Sign-in refused',
      'The server refused the sign-in.',
      'HTTP $status',
    );
  }

  final notAnswered =
      '$host did not answer in time. Check your internet connection.';
  const secure = 'Secure connection failed';
  final insecure = 'The secure connection to $host failed.';
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return failed(notReachable, notAnswered, 'connect timeout');
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      final kind = switch (error.type) {
        DioExceptionType.sendTimeout => 'send timeout',
        DioExceptionType.transformTimeout => 'transform timeout',
        _ => 'receive timeout',
      };
      return failed(
        'Server too slow',
        '$host took too long to answer. Try again later.',
        kind,
      );
    case DioExceptionType.badCertificate:
      return failed(secure, insecure, 'certificate not trusted');
    case DioExceptionType.cancel:
      return SignInFailure(fallback);
    case DioExceptionType.badResponse:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      break;
  }
  final cause = error.error;
  if (cause is TypeError) {
    return failed(
      notBacklogManager,
      notBacklogManagerExplanation,
      'unexpected answer',
    );
  }
  if (cause is TlsException) return failed(secure, insecure, 'TLS');
  final couldNotReach =
      'Could not reach $host. Check your internet connection.';
  if (cause is SocketException) {
    final code = cause.osError?.errorCode;
    if (cause.message.contains('Failed host lookup')) {
      return failed(
        'Server not found',
        'Could not find $host. Check the server address and your internet '
            'connection.',
        'DNS lookup failed',
      );
    }
    if (_refused.contains(code)) {
      return failed(
        notReachable,
        '$host refused the connection. The server may be down.',
        'connection refused',
      );
    }
    if (_unreachable.contains(code)) {
      return failed(
        'No internet connection',
        'This device has no network connection. Check your internet '
            'connection.',
        'network unreachable',
      );
    }
    if (_timedOut.contains(code)) {
      return failed(notReachable, notAnswered, 'connect timeout');
    }
    final reason = cause.osError?.message ?? cause.message;
    return failed(notReachable, couldNotReach, 'connection error ($reason)');
  }
  return failed(notReachable, couldNotReach, 'connection error');
}

String _host(Uri uri) => uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

String _clock(DateTime time) => [
  time.hour,
  time.minute,
  time.second,
].map((part) => part.toString().padLeft(2, '0')).join(':');
