import 'receipt_layout.dart';

/// Perintah ESC/POS dasar yang didukung hampir semua printer thermal 58/80 mm.
abstract final class EscPos {
  static const _esc = 0x1B;
  static const _gs = 0x1D;

  /// Mengubah baris struk menjadi byte siap kirim ke printer.
  static List<int> encode(List<ReceiptLine> lines, {int feedLines = 3, bool cut = true}) {
    final bytes = <int>[_esc, 0x40]; // reset
    for (final line in lines) {
      bytes
        ..addAll([_esc, 0x61, line.align.index]) // perataan: 0 kiri, 1 tengah, 2 kanan
        ..addAll([_esc, 0x45, line.bold ? 1 : 0])
        ..addAll([_gs, 0x21, line.large ? 0x11 : 0x00]) // lebar & tinggi ganda
        ..addAll(text(line.text))
        ..add(0x0A);
    }
    bytes
      ..addAll([_gs, 0x21, 0x00, _esc, 0x45, 0, _esc, 0x61, 0])
      ..addAll([_esc, 0x64, feedLines]);
    if (cut) bytes.addAll([_gs, 0x56, 0x42, 0x00]); // potong sebagian (diabaikan printer tanpa cutter)
    return bytes;
  }

  /// Teks ASCII; huruf di luar ASCII diganti padanan sederhana atau '?' agar tidak jadi karakter aneh.
  static List<int> text(String value) {
    final out = <int>[];
    for (final rune in value.runes) {
      if (rune >= 0x20 && rune < 0x7F) {
        out.add(rune);
      } else {
        out.addAll((_fallback[rune] ?? '?').codeUnits);
      }
    }
    return out;
  }

  static const _fallback = {
    0x00A0: ' ', // spasi tak terputus (format rupiah)
    0x202F: ' ',
    0x2013: '-',
    0x2014: '-',
    0x2018: "'",
    0x2019: "'",
    0x201C: '"',
    0x201D: '"',
    0x2022: '*',
    0x00D7: 'x',
    0x00E9: 'e',
    0x00E8: 'e',
    0x00E0: 'a',
  };
}
