import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Makes photos small enough for weak mobile connections.
abstract interface class ImageCompressor {
  /// Compressed JPEG bytes of the image at [path].
  Future<Uint8List> compressToJpeg(String path);
}

/// [ImageCompressor] with flutter_image_compress (Android and iOS): the
/// longest side becomes at most [maxSide] pixels, JPEG quality [quality].
class NativeImageCompressor implements ImageCompressor {
  const NativeImageCompressor({this.maxSide = 1920, this.quality = 80});

  final int maxSide;
  final int quality;

  @override
  Future<Uint8List> compressToJpeg(String path) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: maxSide,
      minHeight: maxSide,
      quality: quality,
    );
    // Should never happen for a photo; keep the original rather than lose it.
    return compressed ?? await File(path).readAsBytes();
  }
}
