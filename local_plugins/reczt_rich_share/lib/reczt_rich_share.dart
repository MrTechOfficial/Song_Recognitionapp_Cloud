import 'package:flutter/services.dart';

/// Small app-local Flutter plugin that exposes Reczt's native iOS rich-link
/// share sheet to Dart. The native plugin is auto-registered by Flutter when
/// this package is listed in the app's pubspec.yaml dependencies.
class RecztRichShare {
  RecztRichShare._();

  static const MethodChannel _channel = MethodChannel('reczt/rich_share');

  static Future<void> shareRichLink({
    required String title,
    required String message,
    required String url,
    String? previewImagePath,
  }) async {
    await _channel.invokeMethod<void>('shareRichLink', <String, Object?>{
      'title': title,
      'message': message,
      'url': url,
      'previewImagePath': previewImagePath,
    });
  }
}
