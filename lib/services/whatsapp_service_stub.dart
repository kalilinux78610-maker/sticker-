/// Web stub for WhatsApp service — native intents not available on web.
class WhatsAppServiceImpl {
  static Future<void> installStickerPack({
    required String identifier,
    required String title,
    required String trayImagePath,
    required List<String> stickers,
    required bool animated,
  }) async {
    // Not supported on web — do nothing
    throw UnsupportedError(
        'WhatsApp sticker injection is not supported on web. Please use the Android or iOS app.');
  }
}
