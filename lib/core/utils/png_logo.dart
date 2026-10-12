import 'dart:typed_data';

import '../error/app_exception.dart';

/// Batas ukuran logo. Logo disimpan sebagai base64 di dokumen Firestore (maks 1 MB per dokumen).
const maxLogoBytes = 500 * 1024;

const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// true bila [bytes] diawali tanda tangan file PNG.
bool isPng(Uint8List bytes) {
  if (bytes.length < _signature.length) return false;
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) return false;
  }
  return true;
}

/// true bila PNG punya kanal transparansi (color type RGBA / gray+alpha, atau chunk tRNS).
bool pngHasTransparency(Uint8List bytes) {
  if (!isPng(bytes) || bytes.length < 26) return false;
  final colorType = bytes[25]; // IHDR: 8 signature + 4 length + 4 'IHDR' + 13 data, color type di offset 25.
  if (colorType == 4 || colorType == 6) return true;
  final data = ByteData.sublistView(bytes);
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (type == 'tRNS') return true;
    if (type == 'IDAT' || type == 'IEND') return false; // tRNS selalu sebelum IDAT.
    offset += 12 + length;
  }
  return false;
}

/// Memastikan logo berformat PNG dan tidak terlalu besar. Melempar [AppException] bila tidak valid.
void validateLogoPng(Uint8List bytes) {
  if (!isPng(bytes)) throw const AppException('Logo harus berformat PNG.');
  if (bytes.length > maxLogoBytes) {
    throw AppException('Ukuran logo maksimal ${maxLogoBytes ~/ 1024} KB (file ini ${bytes.length ~/ 1024} KB).');
  }
}
