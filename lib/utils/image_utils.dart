import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<Uint8List> processSquareUnderBytes(
  Uint8List inputBytes, {
  int targetBytes = 500 * 1024,
  int maxSide = 1024,
}) async {
  final original = img.decodeImage(inputBytes);
  if (original == null) return inputBytes;

  final int side = original.width < original.height ? original.width : original.height;
  final int offsetX = (original.width - side) ~/ 2;
  final int offsetY = (original.height - side) ~/ 2;
  img.Image current = img.copyCrop(original, x: offsetX, y: offsetY, width: side, height: side);

  if (current.width > maxSide || current.height > maxSide) {
    current = img.copyResize(current, width: maxSide, height: maxSide);
  }

  int quality = 90;
  List<int> encoded = img.encodeJpg(current, quality: quality);
  while (encoded.length > targetBytes && quality > 30) {
    quality -= 10;
    encoded = img.encodeJpg(current, quality: quality);
  }

  int resizeSide = current.width;
  while (encoded.length > targetBytes && resizeSide > 400) {
    resizeSide = (resizeSide * 0.85).toInt();
    current = img.copyResize(current, width: resizeSide, height: resizeSide);
    quality = (quality - 5).clamp(30, 90);
    encoded = img.encodeJpg(current, quality: quality);
  }

  return Uint8List.fromList(encoded);
} 