import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fetches an installer to a file and reports the bytes received.
abstract interface class UpdateDownloader {
  Future<void> download(
    Uri url,
    File target, {
    required void Function(int received, int total) onProgress,
  });
}

class DioUpdateDownloader implements UpdateDownloader {
  DioUpdateDownloader([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 2),
            ),
          );

  final Dio _dio;

  @override
  Future<void> download(
    Uri url,
    File target, {
    required void Function(int received, int total) onProgress,
  }) async {
    await _dio.downloadUri(url, target.path, onReceiveProgress: onProgress);
  }
}

final updateDownloaderProvider = Provider<UpdateDownloader>(
  (ref) => DioUpdateDownloader(),
);
