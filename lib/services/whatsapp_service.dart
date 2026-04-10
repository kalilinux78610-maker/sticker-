// Conditional import: use native impl on mobile/desktop, stub on web
import 'whatsapp_service_stub.dart'
    if (dart.library.io) 'whatsapp_service_native.dart';

class WhatsAppService {
  static Future<void> installStickerPack({
    required String identifier,
    required String title,
    required String trayImagePath,
    required List<String> stickers,
    required bool animated,
  }) {
    return WhatsAppServiceImpl.installStickerPack(
      identifier: identifier,
      title: title,
      trayImagePath: trayImagePath,
      stickers: stickers,
      animated: animated,
    );
  }
}
