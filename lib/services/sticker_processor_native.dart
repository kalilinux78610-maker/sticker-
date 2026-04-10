import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Native (mobile/desktop) implementation of sticker processing.
class StickerProcessorImpl {
  static Future<String?> processStaticWebp(
      Uint8List inputBytes, String filenamePrefix) async {
    final tempDir = await getTemporaryDirectory();
    final inputPath = '${tempDir.path}/${filenamePrefix}_static_input';
    final outputPath = '${tempDir.path}/$filenamePrefix.webp';

    final inputFile = File(inputPath);
    await inputFile.writeAsBytes(inputBytes);

    try {
      final command =
          '-y -i "$inputPath" -vcodec libwebp -filter:v "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=white@0.0" "$outputPath"';
      final session = await FFmpegKit.execute(command);

      if (await inputFile.exists()) await inputFile.delete();

      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        return outputPath;
      }
    } catch (e) {
      // Fallback for Desktop platforms where FFmpeg isn't natively bound
    }

    // Pure Dart Fallback
    final image = img.decodeImage(inputBytes);
    if (image == null) return null;

    final resized =
        img.copyResize(image, width: 512, height: 512, maintainAspect: true);
    final padded = img.Image(width: 512, height: 512, numChannels: 4);

    img.fillRect(padded,
        x1: 0, y1: 0, x2: 512, y2: 512, color: img.ColorRgba8(255, 255, 255, 0));

    final dx = (512 - resized.width) ~/ 2;
    final dy = (512 - resized.height) ~/ 2;
    img.compositeImage(padded, resized, dstX: dx, dstY: dy);

    final finalBytes = img.encodePng(padded);
    final outFile = File(outputPath);
    await outFile.writeAsBytes(finalBytes);

    if (await inputFile.exists()) await inputFile.delete();
    return outputPath;
  }

  static Future<String?> processVideoSticker(
      Uint8List inputBytes, String filenamePrefix) async {
    final tempDir = await getTemporaryDirectory();
    final inputPath = '${tempDir.path}/${filenamePrefix}_input.webm';
    final outputPath = '${tempDir.path}/${filenamePrefix}_output.webp';

    final inputFile = File(inputPath);
    await inputFile.writeAsBytes(inputBytes);

    final command =
        '-y -i "$inputPath" -vcodec libwebp -filter:v "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=white@0.0" -lossless 0 -compression_level 4 -q:v 50 -loop 0 -preset default -an -vsync 0 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (await inputFile.exists()) {
      await inputFile.delete();
    }

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }

    throw Exception('FFmpeg processing failed');
  }

  static Future<String?> processTgsSticker(
      Uint8List inputBytes, String filenamePrefix) async {
    return null;
  }
}
