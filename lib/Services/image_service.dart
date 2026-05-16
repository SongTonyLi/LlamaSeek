import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:llamaseek/Constants/constants.dart';

/// Handles all image storage and compression operations.
/// Uses the pure-Dart `image` package for cross-platform compression,
/// avoiding native plugins with deprecated iOS APIs.
class ImageService {
  Future<Directory> getImagesDirectory() async {
    final documentsDirectory = PathManager.instance.documentsDirectory;
    final imagesPath = path.join(documentsDirectory.path, 'images');
    return await Directory(imagesPath).create(recursive: true);
  }

  Future<File?> compressAndSave(String sourcePath, {int quality = 10}) async {
    try {
      final imagesDir = await getImagesDirectory();
      final targetPath = path.join(
        imagesDir.path,
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      return await _compressImage(sourcePath, targetPath, quality: quality);
    } catch (e) {
      return null;
    }
  }

  /// Compress using the pure-Dart image package (works on all platforms).
  Future<File?> _compressImage(
    String sourcePath,
    String targetPath, {
    int quality = 10,
  }) async {
    final sourceBytes = await File(sourcePath).readAsBytes();

    // Decode and re-encode in an isolate to avoid blocking the UI thread
    final compressed = await compute(
      _compressInIsolate,
      _CompressArgs(sourceBytes, quality),
    );

    if (compressed == null) return null;
    return await File(targetPath).writeAsBytes(compressed);
  }

  Future<void> deleteImage(File imageFile) async {
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  Future<void> deleteImages(List<File> imageFiles) async {
    await Future.wait(imageFiles.map((file) => deleteImage(file)));
  }
}

class _CompressArgs {
  final Uint8List bytes;
  final int quality;
  _CompressArgs(this.bytes, this.quality);
}

Uint8List? _compressInIsolate(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;
  return img.encodeJpg(decoded, quality: args.quality);
}
