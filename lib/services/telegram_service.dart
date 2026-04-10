import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TelegramService {
  final String botToken;
  final String baseUrl = 'https://api.telegram.org';

  TelegramService({required this.botToken});

  /// Fetches the details of a sticker set including all stickers.
  Future<Map<String, dynamic>> getStickerSet(String name) async {
    final url = Uri.parse('$baseUrl/bot$botToken/getStickerSet?name=$name');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return data['result'];
      } else {
        throw Exception(data['description']);
      }
    } else {
      throw Exception('Failed to fetch sticker set. Status: ${response.statusCode}');
    }
  }

  /// Downloads a file from Telegram using its file_id.
  Future<Uint8List> downloadFile(String fileId) async {
    // 1. Get file path
    final pathUrl = Uri.parse('$baseUrl/bot$botToken/getFile?file_id=$fileId');
    final pathResponse = await http.get(pathUrl);

    if (pathResponse.statusCode != 200) {
      throw Exception('Failed to get file path');
    }

    final pathData = jsonDecode(pathResponse.body);
    if (pathData['ok'] != true) {
      throw Exception('Telegram API error: ${pathData['description']}');
    }

    final filePath = pathData['result']['file_path'];

    // 2. Download actual file
    final downloadUrl = Uri.parse('https://api.telegram.org/file/bot$botToken/$filePath');
    final downloadResponse = await http.get(downloadUrl);

    if (downloadResponse.statusCode == 200) {
      return downloadResponse.bodyBytes;
    } else {
      throw Exception('Failed to download file data. Status: ${downloadResponse.statusCode}');
    }
  }
}
