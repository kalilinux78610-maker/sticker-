import 'dart:typed_data';

/// Web stub — no FFmpeg or dart:io available on web platform.
class StickerProcessorImpl {
  static Future<String?> processStaticWebp(
      Uint8List inputBytes, String filenamePrefix) async {
    // Not supported on web — return null gracefully
    return null;
  }

  static Future<String?> processVideoSticker(
      Uint8List inputBytes, String filenamePrefix) async {
    return null;
  }

  static Future<String?> processTgsSticker(
      Uint8List inputBytes, String filenamePrefix) async {
    return null;
  }
}
