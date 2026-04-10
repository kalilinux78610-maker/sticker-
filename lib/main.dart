import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'services/telegram_service.dart';
import 'services/sticker_processor.dart';
import 'services/whatsapp_service.dart';

void main() {
  runApp(const StickerBridgeApp());
}

class StickerBridgeApp extends StatelessWidget {
  const StickerBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StickerBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _tokenController = TextEditingController(
      text: '8717331871:AAF0NaxPA4kbFFaLES92ziRQM77YTVmt_1s');
  final TextEditingController _packNameController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0;

  void _updateStatus(String message, [double? progress]) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      if (progress != null) _progress = progress;
    });
  }

  Future<void> _processAndInstall() async {
    final botToken = _tokenController.text.trim();
    String packName = _packNameController.text.trim();

    // Auto-extract pack name if the user pastes a full URL
    if (packName.contains('addstickers/')) {
      packName = packName.split('addstickers/').last.split('?').first.trim();
    } else if (packName.contains('/')) {
      packName = packName.split('/').last.trim();
    }

    if (botToken.isEmpty || packName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter both Token and Pack Name')));
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0;
    });

    try {
      final telegram = TelegramService(botToken: botToken);
      _updateStatus('Fetching pack details...', 0.1);
      final packData = await telegram.getStickerSet(packName);
      final title = packData['title'] ?? 'Telegram Pack';
      final isAnimated = packData['is_animated'] ?? false;
      final isVideo = packData['is_video'] ?? false;

      final stickersData = packData['stickers'] as List<dynamic>;
      if (stickersData.isEmpty) throw Exception('Pack is empty');

      _updateStatus(
          'Found ${stickersData.length} stickers. Downloading...', 0.2);

      // WhatsApp allows max 30 stickers per pack
      final limit = stickersData.length > 30 ? 30 : stickersData.length;

      List<String> whatsappStickers = [];
      String? trayImagePath;

      for (int i = 0; i < limit; i++) {
        final st = stickersData[i];
        final fileId = st['file_id'];

        if (!mounted) return;
        _updateStatus(
            'Processing sticker ${i + 1}/$limit...', 0.2 + (0.7 * (i / limit)));

        final bytes = await telegram.downloadFile(fileId);

        String? finalWebpPath;
        if (isVideo) {
          finalWebpPath =
              await StickerProcessor.processVideoSticker(bytes, 'st_$i');
        } else if (isAnimated) {
          finalWebpPath =
              await StickerProcessor.processTgsSticker(bytes, 'st_$i');
        } else {
          finalWebpPath =
              await StickerProcessor.processStaticWebp(bytes, 'st_$i');
        }

        if (finalWebpPath != null) {
          whatsappStickers.add(finalWebpPath);
        }
      }

      if (whatsappStickers.isEmpty) {
        if (kIsWeb) {
          _updateStatus(
              '✅ Pack fetched! (${stickersData.length} stickers found)\n\n'
              'ℹ️ Full sticker processing & WhatsApp injection requires the mobile app.\n'
              'Download the Android APK or iOS IPA from the releases page.',
              1.0);
          return;
        }
        throw Exception('No stickers could be processed successfully.');
      }

      if (!mounted) return;
      _updateStatus('Adding to WhatsApp...', 0.95);

      try {
        await WhatsAppService.installStickerPack(
          identifier: packName,
          title: title,
          trayImagePath: trayImagePath ?? '',
          stickers: whatsappStickers,
          animated: isAnimated || isVideo,
        );
        _updateStatus('✅ Done! Pack added to WhatsApp.', 1.0);
      } catch (e) {
        final err = e.toString();
        if (err.contains('MissingPluginException') ||
            err.contains('UnsupportedError') ||
            err.contains('not supported on web')) {
          _updateStatus(
              '✅ Downloads Complete!\n\n'
              'ℹ️ WhatsApp injection is only available on Android/iOS.\n'
              'Use the mobile app to complete the transfer.',
              1.0);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1EBEA5), Color(0xFF00E676)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compare_arrows,
                            size: 64, color: Color(0xFF1EBEA5)),
                        const SizedBox(height: 16),
                        Text(
                          'StickerBridge',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text('Telegram → WhatsApp',
                            style: TextStyle(color: Colors.grey)),
                        if (kIsWeb) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              border: Border.all(color: Colors.amber.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Web preview — for full functionality, install the Android/iOS app.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            labelText: 'Bot Token',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _packNameController,
                          decoration: const InputDecoration(
                            labelText: 'Telegram Pack Name or URL',
                            hintText: 'e.g., AnimalsPack or t.me/addstickers/...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.catching_pokemon),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading) ...[
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 10),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                        ] else if (_statusMessage.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _statusMessage.startsWith('❌')
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _statusMessage.startsWith('❌')
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Text(
                              _statusMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: _statusMessage.startsWith('❌')
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _processAndInstall,
                            icon: const Icon(Icons.send),
                            label: const Text(
                              'Download & Add to WhatsApp',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
