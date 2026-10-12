import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sales/domain/entities/invoice.dart';
import '../../settings/domain/store_settings.dart';
import '../domain/cafe.dart';
import 'bluetooth_printer.dart';
import 'escpos.dart';
import 'receipt_layout.dart';

/// Mencetak struk kasir: ke printer thermal Bluetooth bila sudah dipilih,
/// selain itu lewat dialog cetak sistem dengan kertas gulungan 58/80 mm (web / desktop / printer USB).
class ReceiptPrinter {
  ReceiptPrinter([BluetoothPrinter? bluetooth]) : _bluetooth = bluetooth ?? BluetoothPrinter();

  final BluetoothPrinter _bluetooth;

  bool get bluetoothSupported => _bluetooth.supported;

  Future<List<PrinterDevice>> pairedDevices() => _bluetooth.pairedDevices();

  Future<void> print({
    required Invoice invoice,
    required StoreSettings store,
    required CafeSettings settings,
    bool reprint = false,
  }) async {
    final lines = ReceiptLayout.build(invoice: invoice, store: store, width: settings.charsPerLine, reprint: reprint);
    if (_bluetooth.supported && settings.hasBluetoothPrinter) {
      await _bluetooth.printBytes(settings.printerAddress, EscPos.encode(lines));
      return;
    }
    await Printing.layoutPdf(
      name: invoice.number,
      format: _format(settings.paperWidth),
      onLayout: (_) => buildPdf(lines, settings.paperWidth),
    );
  }

  /// Struk uji dari halaman pengaturan.
  Future<void> printTest({required StoreSettings store, required CafeSettings settings}) {
    final w = settings.charsPerLine;
    final lines = [
      ReceiptLine(store.storeName.isEmpty ? 'POS Kopi' : store.storeName, align: ReceiptAlign.center, bold: true),
      const ReceiptLine('Tes printer berhasil', align: ReceiptAlign.center),
      ReceiptLine.divider(w),
      ReceiptLine(ReceiptLayout.columns('Kertas', '${settings.paperWidth} mm', w)),
      ReceiptLine(ReceiptLayout.columns('Karakter/baris', '$w', w)),
      ReceiptLine('1234567890' * (w ~/ 10) + '1234567890'.substring(0, w % 10)),
    ];
    if (_bluetooth.supported && settings.hasBluetoothPrinter) {
      return _bluetooth.printBytes(settings.printerAddress, EscPos.encode(lines));
    }
    return Printing.layoutPdf(name: 'Tes printer', format: _format(settings.paperWidth), onLayout: (_) => buildPdf(lines, settings.paperWidth));
  }

  static PdfPageFormat _format(int paperWidth) => paperWidth >= 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

  /// PDF gulungan dengan huruf monospace, isi sama persis dengan cetakan Bluetooth.
  static Future<Uint8List> buildPdf(List<ReceiptLine> lines, int paperWidth) {
    final format = _format(paperWidth);
    final chars = paperWidth >= 80 ? 48 : 32;
    // Courier: lebar karakter 0,6 × ukuran huruf.
    final fontSize = (format.availableWidth - 8) / (chars * 0.6);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format.copyWith(marginLeft: 4, marginRight: 4, marginTop: 8, marginBottom: 8),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (final l in lines)
              pw.Text(
                l.text,
                textAlign: switch (l.align) {
                  ReceiptAlign.left => pw.TextAlign.left,
                  ReceiptAlign.center => pw.TextAlign.center,
                  ReceiptAlign.right => pw.TextAlign.right,
                },
                style: pw.TextStyle(
                  font: l.bold ? pw.Font.courierBold() : pw.Font.courier(),
                  fontSize: l.large ? fontSize * 2 : fontSize,
                ),
              ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
