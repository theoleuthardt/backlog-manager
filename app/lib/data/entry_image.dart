import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// The cover art of an entry through the image proxy of the server, or null
/// while the server address is not known or the entry has no image.
ImageProvider? entryImage(String? serverUrl, String imageLink) {
  if (serverUrl == null) return null;
  final url = proxiedImageUrl(serverUrl, imageLink);
  return url == null ? null : CachedNetworkImageProvider(url);
}
