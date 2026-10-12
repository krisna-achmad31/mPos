import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/terbilang.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../settings/domain/store_settings.dart';
import '../domain/entities/invoice.dart';

/// Semua data yang dibutuhkan template invoice A4.
class InvoicePrintData {
  const InvoicePrintData({
    required this.invoice,
    required this.distributorName,
    required this.settings,
    this.logoPng,
    this.customer,
    this.paymentLabel = '',
  });

  final Invoice invoice;

  /// Nama di kop invoice: nama toko di Pengaturan, atau nama distributor bila kosong.
  final String distributorName;
  final StoreSettings settings;

  /// Logo PNG distributor; null = kop hanya menampilkan nama.
  final Uint8List? logoPng;

  /// Data kontak pelanggan (alamat, HP, email) bila tersedia.
  final AppUser? customer;

  /// Metode bayar untuk kolom "Pembayaran"; kosong = dari [Invoice.paymentMethod] / status bayar.
  final String paymentLabel;
}

const _grey = PdfColor.fromInt(0xFF808080);
const _defaultNotes = 'Terima kasih atas kepercayaan Anda.\nMohon simpan dokumen ini sebagai bukti transaksi.';

/// Paket pdf belum mendukung `spacing` di Row/Column.
List<pw.Widget> _spaced(double gap, List<pw.Widget> children) => [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) pw.SizedBox(height: gap, width: gap), children[i]],
    ];

String _num(int v) => v == 0 ? '-' : formatNumber(v);

/// Satu baris tabel produk. Baris dengan kemasan dipecah per kemasan, mis. "5 Karton" + "3 Pcs".
class _Row {
  const _Row(this.name, this.qty, this.unit, this.price, this.discount, this.amount);

  final String name;
  final int qty;
  final String unit;
  final int price;
  final int discount;
  final int amount;
}

List<_Row> _rows(Invoice invoice) => [
      for (final l in invoice.lines) ...() {
        final parts = <_Row>[
          for (final p in l.packs) _Row(l.name, p.count, p.name, p.price, 0, p.total),
          if (l.looseQty > 0 || l.packs.isEmpty) _Row(l.name, l.looseQty, l.unit, l.unitPrice, 0, l.looseQty * l.unitPrice),
        ];
        // Diskon baris dicatat di baris terakhir supaya kolom Jumlah = nilai bersih.
        final last = parts.removeLast();
        return [
          ...parts,
          _Row(last.name, last.qty, last.unit, last.price, l.discountAmount, last.amount - l.discountAmount),
        ];
      }(),
    ];

/// Nama file default saat disimpan, mis. "INV-20261011-0003.pdf".
String invoicePdfFileName(Invoice invoice) {
  final safe = invoice.number.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
  return '${safe.isEmpty ? 'invoice' : safe}.pdf';
}

Future<Uint8List> buildInvoicePdf(InvoicePrintData data) {
  final inv = data.invoice;
  final s = data.settings;
  final t = inv.totals;
  final name = data.distributorName.toUpperCase();
  final logo = data.logoPng == null ? null : pw.MemoryImage(data.logoPng!);
  final notes = s.invoiceFooter.isNotEmpty ? s.invoiceFooter : _defaultNotes;
  final signer = s.signatureName.isNotEmpty ? s.signatureName : data.distributorName;
  final customer = data.customer;

  const base = pw.TextStyle(fontSize: 10);
  final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

  pw.Widget meta(String label, String value) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label : ', style: const pw.TextStyle(fontSize: 12)),
          pw.Container(
            constraints: const pw.BoxConstraints(minWidth: 105),
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.6, style: pw.BorderStyle.dashed)),
            ),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      );

  pw.Widget total(String label, String value, {bool strong = false, bool line = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('$label :', style: strong ? bold.copyWith(fontSize: 11) : const pw.TextStyle(fontSize: 11)),
            pw.Container(
              width: 105,
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(left: 4),
              decoration: line ? const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))) : null,
              child: pw.Text(value, style: strong ? bold.copyWith(fontSize: 11) : const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );

  final header = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null)
        pw.Container(
          width: 80,
          height: 60,
          margin: const pw.EdgeInsets.only(right: 14, top: 16),
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: _spaced(3, [
            pw.Text(name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Alamat : ${s.address}', style: base),
            pw.Text('Telepon/HP : ${s.phone}', style: base),
            pw.Text('Email : ${s.email}', style: base),
          ]),
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: _spaced(2, [
          pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          meta('No. Invoice', inv.number),
          meta('Tanggal', DateFormat('dd/MMM/yyyy', 'id_ID').format(inv.createdAt)),
          meta(
            'Pembayaran',
            data.paymentLabel.isNotEmpty ? data.paymentLabel : inv.paymentMethod?.label ?? inv.paymentStatus.label,
          ),
        ]),
      ),
    ],
  );

  final billTo = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: _spaced(3, [
            pw.Text('Kepada Yth.', style: const pw.TextStyle(fontSize: 11)),
            pw.Text(inv.customerName, style: bold.copyWith(fontSize: 11)),
            pw.Text('Alamat: ${customer?.address ?? ''}', style: base),
            pw.Text('No. HP / WA: ${customer?.phone ?? ''}', style: base),
            pw.Text('Email: ${customer?.email ?? ''}', style: base),
          ]),
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('JUMLAH YANG HARUS DIBAYAR', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Text(formatRupiah(inv.remaining > 0 ? inv.remaining : t.total),
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
          if (inv.voided)
            pw.Text('DIBATALKAN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
        ],
      ),
    ],
  );

  final headerStyle = const pw.TextStyle(fontSize: 10, color: PdfColors.white);
  pw.Widget cell(String text, {pw.Alignment align = pw.Alignment.centerLeft, pw.TextStyle? style}) => pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 9)),
      );

  final table = pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(4.4),
      1: pw.FlexColumnWidth(0.6),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1.25),
      4: pw.FlexColumnWidth(1.25),
      5: pw.FlexColumnWidth(1.25),
    },
    border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.8)),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _grey),
        children: [
          for (final h in ['Nama Produk', 'Qty', 'Satuan', 'Harga', 'Diskon', 'Jumlah'])
            cell(h, align: pw.Alignment.center, style: headerStyle),
        ],
      ),
      for (final r in _rows(inv))
        pw.TableRow(children: [
          cell(r.name.toUpperCase()),
          cell('${r.qty}', align: pw.Alignment.centerRight),
          cell(r.unit),
          cell(_num(r.price), align: pw.Alignment.centerRight),
          cell(_num(r.discount), align: pw.Alignment.centerRight),
          cell(_num(r.amount), align: pw.Alignment.centerRight),
        ]),
    ],
  );

  // Diskon item sudah masuk kolom Jumlah; ringkasan memakai subtotal bersih + diskon nota.
  final subtotal = t.subtotal - t.itemDiscount;
  final taxLabel = 'Pajak ${t.taxPercent.toStringAsFixed(t.taxPercent % 1 == 0 ? 0 : 1)}%';

  final summary = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Terbilang: ${terbilangRupiah(t.total)}', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 18),
            pw.Text('Keterangan:', style: bold.copyWith(fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text(notes, style: base.copyWith(lineSpacing: 4)),
          ],
        ),
      ),
      pw.SizedBox(width: 20),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          total('Subtotal', _num(subtotal)),
          total('Diskon', _num(t.orderDiscount)),
          total('Total Sblm Pajak', _num(subtotal - t.orderDiscount)),
          total(taxLabel, _num(t.tax), line: true),
          total('Total', _num(t.total), strong: true),
          if (inv.paid > 0 && inv.remaining > 0) ...[
            total('Dibayar', _num(inv.paid)),
            total('Sisa Tagihan', _num(inv.remaining), strong: true),
          ],
        ],
      ),
    ],
  );

  pw.Widget signature(String title, String signedBy) => pw.SizedBox(
        width: 150,
        child: pw.Column(
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 48),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('(', style: const pw.TextStyle(fontSize: 11)),
                pw.Text(signedBy, style: const pw.TextStyle(fontSize: 11)),
                pw.Text(')', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      );

  final footer = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: s.bankInfo.isEmpty
            ? pw.SizedBox()
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Metode Pembayaran:', style: bold.copyWith(fontSize: 11)),
                  pw.SizedBox(height: 6),
                  pw.Text(s.bankInfo, style: base.copyWith(lineSpacing: 4)),
                ],
              ),
      ),
      signature('Hormat Kami,', signer),
      pw.SizedBox(width: 20),
      signature('Diterima Oleh,', ''),
    ],
  );

  // Chrome memakai judul PDF sebagai nama file default di "Simpan sebagai PDF" saat mencetak.
  final doc = pw.Document(title: inv.number, author: data.distributorName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(22, 24, 22, 24),
    build: (_) => [
      header,
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1, height: 1),
      pw.SizedBox(height: 14),
      billTo,
      pw.SizedBox(height: 16),
      table,
      pw.SizedBox(height: 4),
      summary,
      pw.SizedBox(height: 24),
      footer,
    ],
  ));
  return doc.save();
}
