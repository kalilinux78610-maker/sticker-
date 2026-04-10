import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

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
  // Prefilled token as requested by user
  final TextEditingController _tokenController = TextEditingController(text: '8717331871:AAF0NaxPA4kbFFaLES92ziRQM77YTVmt_1s');
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both Token and Pack Name')));
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

      _updateStatus('Found ${stickersData.length} stickers. Downloading...', 0.2);

      final tempDir = await getTemporaryDirectory();
      
      // WhatsApp allows max 30 stickers per pack. We will process up to 30.
      final limit = stickersData.length > 30 ? 30 : stickersData.length;
      
      List<String> whatsappStickers = [];
      String? trayImagePath;

      for (int i = 0; i < limit; i++) {
        final st = stickersData[i];
        final fileId = st['file_id'];

        if (!mounted) return;
        _updateStatus('Processing sticker ${i + 1}/$limit...', 0.2 + (0.7 * (i / limit)));

        final bytes = await telegram.downloadFile(fileId);
        
        String? finalWebpPath;
        if (isVideo) {
          finalWebpPath = await StickerProcessor.processVideoSticker(bytes, 'st_$i');
        } else if (isAnimated) {
          finalWebpPath = await StickerProcessor.processTgsSticker(bytes, 'st_$i');
        } else {
          finalWebpPath = await StickerProcessor.processStaticWebp(bytes, 'st_$i');
        }

        if (finalWebpPath != null) {
          whatsappStickers.add(finalWebpPath);
          
          if (trayImagePath == null && !isAnimated && !isVideo) {
            final imgObj = img.decodeImage(File(finalWebpPath).readAsBytesSync());
            if (imgObj != null) {
               final trayImg = img.copyResize(imgObj, width: 96, height: 96, maintainAspect: true);
               trayImagePath = '${tempDir.path}/tray.png';
               await File(trayImagePath).writeAsBytes(img.encodePng(trayImg));
            }
          }
        }
      }

      if (whatsappStickers.isEmpty) {
         throw Exception("No stickers could be processed successfully.");
      }

      if (!mounted) return;
      _updateStatus('Adding to WhatsApp...', 0.95);
      
      if (trayImagePath == null) {
         final trayImg = img.Image(width: 96, height: 96, numChannels: 4);
         img.fillRect(trayImg, x1: 0, y1: 0, x2: 96, y2: 96, color: img.ColorRgba8(0,0,0,0));
         trayImagePath = '${tempDir.path}/tray.png';
         await File(trayImagePath).writeAsBytes(img.encodePng(trayImg));
      }

      try {
        await WhatsAppService.installStickerPack(
          identifier: packName,
          title: title,
          trayImagePath: trayImagePath,
          stickers: whatsappStickers,
          animated: isAnimated || isVideo,
        );
        _updateStatus('Done! Pack added to WhatsApp.', 1.0);
      } catch (e) {
        if (e.toString().contains('MissingPluginException')) {
           _updateStatus('Downloads Complete! (WhatsApp injection is not supported on Windows/Web. Test on an Android device to finish the pipeline!)', 1.0);
        } else {
           rethrow;
        }
      }
    } catch (e) {
      _updateStatus('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
          )
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.compare_arrows, size: 60, color: Color(0xFF1EBEA5)),
                      const SizedBox(height: 16),
                      Text("StickerBridge", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Text("Telegram to WhatsApp", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 32),
                      
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
                          labelText: 'Telegram Pack Name',
                          hintText: 'e.g., AnimalsPack',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.catching_pokemon),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (_isLoading) ...[
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 8),
                        Text(_statusMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 24),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _processAndInstall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Download & Add to WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }
}
