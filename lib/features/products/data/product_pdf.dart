import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';

import '../domain/product_export.dart';

Future<Uint8List> buildProductPdf(ProductExportData data) {
  final doc = pw.Document(title: 'Daftar Produk - ${data.name}', author: data.name);
  final logo = data.logoPng == null ? null : pw.MemoryImage(data.logoPng!);
  final accent = PdfColor.fromHex('#173F52');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(26),
      maxPages: 10000,
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 62,
                height: 54,
                margin: const pw.EdgeInsets.only(right: 14),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.name,
                    style: pw.TextStyle(fontSize: 17, color: accent, fontWeight: pw.FontWeight.bold),
                  ),
                  if (data.settings.address.trim().isNotEmpty)
                    pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                  if (data.contact.isNotEmpty) pw.Text(data.contact, style: const pw.TextStyle(fontSize: 9)),
                  if (data.settings.bankInfo.trim().isNotEmpty)
                    pw.Text(data.settings.bankInfo, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.Text('DAFTAR PRODUK', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Daftar produk | ${data.products.length} produk',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text('${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
      build: (_) => [
        pw.Text(data.summary, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ProductExportData.headers,
          data: [
            for (var i = 0; i < data.products.length; i++)
              [for (final cell in data.row(i)) cell is int ? formatNumber(cell) : cell],
          ],
          headerStyle: pw.TextStyle(fontSize: 7, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: accent),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FlexColumnWidth(1.1),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(.7),
            5: pw.FlexColumnWidth(1),
            6: pw.FlexColumnWidth(1),
            7: pw.FlexColumnWidth(.65),
            8: pw.FlexColumnWidth(2.1),
            9: pw.FlexColumnWidth(.65),
            10: pw.FlexColumnWidth(.8),
          },
          cellAlignments: const {
            0: pw.Alignment.center,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerRight,
            9: pw.Alignment.centerRight,
          },
        ),
        if (data.products.isEmpty) pw.Text('Tidak ada produk pada filter ini.'),
        if (data.settings.invoiceFooter.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(data.settings.invoiceFooter, style: const pw.TextStyle(fontSize: 8)),
        ],
      ],
    ),
  );
  return doc.save();
}
