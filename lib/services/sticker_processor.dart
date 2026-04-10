import 'dart:typed_data';

// Conditional import: use native implementation on mobile/desktop, stub on web
import 'sticker_processor_stub.dart'
    if (dart.library.io) 'sticker_processor_native.dart';

class StickerProcessor {
  static Future<String?> processStaticWebp(
      Uint8List inputBytes, String filenamePrefix) {
    return StickerProcessorImpl.processStaticWebp(inputBytes, filenamePrefix);
  }

  static Future<String?> processVideoSticker(
      Uint8List inputBytes, String filenamePrefix) {
    return StickerProcessorImpl.processVideoSticker(inputBytes, filenamePrefix);
  }

  static Future<String?> processTgsSticker(
      Uint8List inputBytes, String filenamePrefix) {
    return StickerProcessorImpl.processTgsSticker(inputBytes, filenamePrefix);
  }
}
