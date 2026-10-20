import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProcessedImageResult {
  final Uint8List bytes;
  final int sizeInBytes;
  final String photoKey;
  final String publicUrl;

  ProcessedImageResult({
    required this.bytes,
    required this.sizeInBytes,
    required this.photoKey,
    required this.publicUrl,
  });
}

class ImageCompressor {
  static Future<ProcessedImageResult> processAndUploadItemPhoto({
    required XFile pickedFile,
    required int familyId,
    required bool shouldCompress,
    String itemId = 'new',
    int photoIndex = 0,
  }) async {
    final Uint8List rawBytes = await pickedFile.readAsBytes();
    Uint8List finalBytes;

    if (shouldCompress) {
      final img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        int targetWidth, targetHeight;
        if (decoded.width >= decoded.height) {
          targetWidth = 450;
          targetHeight = (decoded.height * (450 / decoded.width)).round();
        } else {
          targetHeight = 450;
          targetWidth = (decoded.width * (450 / decoded.height)).round();
        }

        final img.Image resized = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );

        finalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 18));
      } else {
        finalBytes = rawBytes;
      }
    } else {
      finalBytes = rawBytes;
    }

    final uploadRes = await apiService.uploadItemPhoto(
      finalBytes,
      familyId,
      itemId: itemId,
      photoIndex: photoIndex,
    );

    return ProcessedImageResult(
      bytes: finalBytes,
      sizeInBytes: finalBytes.length,
      photoKey: uploadRes['photo_key'],
      publicUrl: uploadRes['url'],
    );
  }

  static Future<ProcessedImageResult> processAndUploadLocationPhoto({
    required XFile pickedFile,
    required int familyId,
    required bool shouldCompress,
    String locationId = 'new',
    int photoIndex = 0,
  }) async {
    final Uint8List rawBytes = await pickedFile.readAsBytes();
    Uint8List finalBytes;

    if (shouldCompress) {
      final img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        int targetWidth, targetHeight;
        if (decoded.width >= decoded.height) {
          targetWidth = 450;
          targetHeight = (decoded.height * (450 / decoded.width)).round();
        } else {
          targetHeight = 450;
          targetWidth = (decoded.width * (450 / decoded.height)).round();
        }

        final img.Image resized = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );

        finalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 18));
      } else {
        finalBytes = rawBytes;
      }
    } else {
      finalBytes = rawBytes;
    }

    final uploadRes = await apiService.uploadLocationPhoto(
      finalBytes,
      familyId,
      locationId: locationId,
      photoIndex: photoIndex,
    );

    return ProcessedImageResult(
      bytes: finalBytes,
      sizeInBytes: finalBytes.length,
      photoKey: uploadRes['photo_key'],
      publicUrl: uploadRes['url'],
    );
  }
}
