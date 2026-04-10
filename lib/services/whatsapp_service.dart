import 'package:whatsapp_stickers_handler/whatsapp_stickers_handler.dart';
import 'package:whatsapp_stickers_handler/model/sticker_pack.dart';

class WhatsAppService {
  /// Installs a sticker pack to WhatsApp. 
  /// The [stickers] array should contain file paths
  static Future<void> installStickerPack({
    required String identifier,
    required String title,
    required String trayImagePath,
    required List<String> stickers,
    required bool animated,
  }) async {
    try {
      final pack = StickerPack(
        identifier: identifier,
        name: title,
        publisher: "StickerBridge",
        trayImage: trayImagePath,
        publisherEmail: "",
        publisherWebsite: "",
        privacyPolicyWebsite: "",
        licenseAgreementWebsite: "",
        androidPlayStoreLink: "StickerBridge",
        iosAppStoreLink: "StickerBridge",
        stickers: stickers,
        animatedStickerPack: animated,
      );
      final handler = WhatsappStickersHandler();
      await handler.addStickerPack(pack);
    } catch (e) {
      throw Exception('Failed to send pack to WhatsApp: $e');
    }
  }
}
