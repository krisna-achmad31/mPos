import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../../products/data/product_xlsx.dart';
import '../../settings/domain/store_settings.dart';

import '../domain/sales_export.dart';

class SalesExportHeader {
  const SalesExportHeader({
    required this.settings,
    required this.distributorName,
    required this.period,
    required this.exportedAt,
    this.logoPng,
  });
  final StoreSettings settings;
  final String distributorName;
  final String period;
  final DateTime exportedAt;
  final Uint8List? logoPng;
  String get name => settings.storeName.trim().isEmpty ? distributorName : settings.storeName.trim();
  List<String> lines(int count) => [
    name,
    settings.address,
    [
      if (settings.phone.isNotEmpty) 'Telp/WA: ${settings.phone}',
      if (settings.email.isNotEmpty) settings.email,
    ].join(' | '),
    settings.bankInfo,
    'LAPORAN PENJUALAN',
    '$period | $count baris | Diekspor ${DateFormat('dd/MM/yyyy HH:mm').format(exportedAt)}',
    settings.invoiceFooter,
  ];
}

/// Menulis rekap transaksi ke .xlsx dengan format "rekap daftar transaksi.xlsx" dari distributor:
/// Header memakai warna teks data dan tanpa fill agar mengikuti mode terang/gelap aplikasi pembaca.
abstract final class SalesXlsx {
  static const headers = [
    'No. transaksi',
    'Tanggal transaksi',
    'Kasir',
    'Sales',
    'Nama pelanggan',
    'Metode bayar',
    'Nama produk',
    'Harga modal (Rp)',
    'Jenis harga jual',
    'Harga jual (Rp)',
    'Diskon item (Rp)',
    'Qty',
    'Satuan',
    'Jumlah (Rp)',
    'Kas masuk (Rp)',
    'Profit (Rp)',
  ];

  static const _widths = [18, 18, 16, 16, 24, 16, 40, 18, 22, 18, 18, 8, 12, 18, 18, 18];

  static Uint8List build(List<SalesExportRow> rows, {SalesExportHeader? header}) {
    final archive = Archive();
    void add(String name, String content) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));
    final headerRow = header == null ? 1 : 8;
    final hasLogo = header?.logoPng != null;
    add(
      '[Content_Types].xml',
      hasLogo
          ? _contentTypes.replaceFirst(
              '</Types>',
              '<Default Extension="png" ContentType="image/png"/>'
                  '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>',
            )
          : _contentTypes,
    );
    add('_rels/.rels', _rootRels);
    add(
      'xl/workbook.xml',
      _workbook.replaceAll('_HEADER_', '$headerRow').replaceAll('_LAST_', '${rows.length + headerRow}'),
    );
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', _sheet(rows, header));
    if (hasLogo) ProductXlsx.addLogo(archive, header!.logoPng!);
    return ZipEncoder().encodeBytes(archive);
  }

  /// Excel menyimpan tanggal sebagai jumlah hari sejak 30 Des 1899 (waktu lokal).
  static double excelDate(DateTime d) {
    final local = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
    return local.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
  }

  static String _sheet(List<SalesExportRow> rows, SalesExportHeader? header) {
    final headingRow = header == null ? 1 : 8;
    final last = rows.length + headingRow;
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="$_ns" xmlns:r="$_nsR">')
      ..write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:P$last"/>')
      ..write('<sheetViews><sheetView tabSelected="1" workbookViewId="0">')
      ..write('<pane ySplit="$headingRow" topLeftCell="A${headingRow + 1}" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="14.4"/><cols>');
    for (var i = 0; i < _widths.length; i++) {
      b.write('<col min="${i + 1}" max="${i + 1}" width="${_widths[i]}" customWidth="1"/>');
    }
    b.write('</cols><sheetData>');
    if (header != null) {
      final lines = header.lines(rows.length);
      for (var i = 0; i < lines.length; i++) {
        final n = i + 1;
        final height = i == 0 || i == 4 ? 32 : (lines[i].split('\n').length * 15 + 10).clamp(28, 409);
        b.write(
          '<row r="$n" ht="$height" customHeight="1">${_str('${i < 4 ? 'C' : 'A'}$n', lines[i], i == 0 || i == 4 ? 9 : 8)}</row>',
        );
      }
    }
    b.write('<row r="$headingRow" ht="36" customHeight="1">');
    for (var i = 0; i < headers.length; i++) {
      b.write(_str('${_col(i)}$headingRow', headers[i], 1));
    }
    b.write('</row>');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final n = i + headingRow + 1;
      b
        ..write('<row r="$n">')
        ..write(int.tryParse(r.number) == null ? _str('A$n', r.number, 3) : _num('A$n', r.number, 3))
        ..write(_num('B$n', excelDate(r.date).toStringAsFixed(6), 4))
        ..write(_str('C$n', r.cashier, 5))
        ..write(_str('D$n', r.sales, 5))
        ..write(_str('E$n', r.customer, 5))
        ..write(_str('F$n', r.method, 6))
        ..write(_str('G$n', r.product, 6))
        ..write(_num('H$n', '${r.unitCost}', 7))
        ..write(_str('I$n', r.priceType, 6))
        ..write(_num('J$n', '${r.unitPrice}', 7))
        ..write(_num('K$n', '${r.discount}', 7))
        ..write(_num('L$n', '${r.qty}', 6))
        ..write(_str('M$n', r.unit, 6))
        ..write(_num('N$n', '${r.amount}', 7))
        ..write(_num('O$n', '${r.cashIn}', 7))
        ..write('<c r="P$n" s="7"><f>IF(F$n="DP",0,O$n-(H$n*L$n))</f><v>${r.profit}</v></c>')
        ..write('</row>');
    }
    b.write('</sheetData>');
    if (rows.isNotEmpty) {
      b.write('<autoFilter ref="A$headingRow:P$last"/>');
    }
    if (header != null) {
      b.write('<mergeCells count="7">');
      for (var n = 1; n <= 7; n++) {
        b.write('<mergeCell ref="${n <= 4 ? 'C' : 'A'}$n:P$n"/>');
      }
      b.write('</mergeCells>');
    }
    if (rows.isNotEmpty) {
      b.write(
        '<conditionalFormatting sqref="A${headingRow + 1}:P$last">'
        '<cfRule type="expression" dxfId="0" priority="1"><formula>\$B${headingRow + 1}&lt;&gt;""</formula></cfRule>'
        '</conditionalFormatting>',
      );
    }
    b.write(
      '<pageMargins left="0.3" right="0.3" top="0.4" bottom="0.4" header="0.2" footer="0.2"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>',
    );
    if (header?.logoPng != null) b.write('<drawing r:id="rIdLogo"/>');
    b.write('</worksheet>');
    return b.toString();
  }

  static String _col(int i) => String.fromCharCode(65 + i);

  static String _str(String ref, String v, int style) =>
      '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_esc(v)}</t></is></c>';

  static String _num(String ref, String v, int style) => '<c r="$ref" s="$style"><v>$v</v></c>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _nsR = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_ns" xmlns:r="$_nsR"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">Sheet1!\$A\$_HEADER_:\$P\$_LAST_</definedName>'
      '<definedName name="_xlnm.Print_Titles" localSheetId="0">Sheet1!\$1:\$_HEADER_</definedName></definedNames>'
      '<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// Disalin dari template; warna tema diganti RGB agar sama tanpa file tema.
  /// cellXfs: 1/2 header, 3 tengah, 4 tanggal, 5 teks, 6 umum, 7 angka akuntansi.
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_ns">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mmm/yyyy"/>'
      '<numFmt numFmtId="166" formatCode="_(* #,##0_);_(* \\(#,##0\\);_(* &quot;-&quot;??_);_(@_)"/></numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>'
      '<font><sz val="8"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="18"/><color rgb="FF173F52"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF173F52"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FFFFFFFF"/></left><right style="thin"><color rgb="FFFFFFFF"/></right>'
      '<top style="thin"><color indexed="64"/></top><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="10">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="49" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="164" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="49" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="166" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '<dxfs count="1"><dxf><border><left style="thin"><color auto="1"/></left><right style="thin"><color auto="1"/></right>'
      '<top style="thin"><color auto="1"/></top><bottom style="thin"><color auto="1"/></bottom></border></dxf></dxfs>'
      '</styleSheet>';
}
