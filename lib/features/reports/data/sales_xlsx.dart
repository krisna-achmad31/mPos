import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/sales_export.dart';

/// Menulis rekap transaksi ke .xlsx dengan format "rekap daftar transaksi.xlsx" dari distributor:
/// header biru gradasi, font 8, tanggal dd/mmm/yyyy, angka format akuntansi, rumus Profit.
abstract final class SalesXlsx {
  static const headers = [
    'No.\nTransaksi', 'Tgl.\nTransaksi', 'Kasir', 'Sales', 'Pelanggan', 'Metode\nBayar', 'Nama Produk',
    'Harga\nModal', 'Type\nHarga Jual', 'Harga\nJual', 'Diskon\nItem', 'Qty', 'Satuan', 'Jumlah', 'Kas\nMasuk', 'Profit',
  ];

  static const _widths = [16, 11, 12, 12, 18, 10, 38, 11, 16, 11, 10, 6, 9, 12, 12, 11];

  static Uint8List build(List<SalesExportRow> rows) {
    final archive = Archive();
    void add(String name, String content) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));
    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook);
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', _sheet(rows));
    return ZipEncoder().encodeBytes(archive);
  }

  /// Excel menyimpan tanggal sebagai jumlah hari sejak 30 Des 1899 (waktu lokal).
  static double excelDate(DateTime d) {
    final local = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
    return local.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
  }

  static String _sheet(List<SalesExportRow> rows) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="$_ns" xmlns:r="$_nsR">')
      ..write('<dimension ref="A1:P${rows.length + 1}"/>')
      ..write('<sheetViews><sheetView tabSelected="1" workbookViewId="0">')
      ..write('<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="14.4"/><cols>');
    for (var i = 0; i < _widths.length; i++) {
      b.write('<col min="${i + 1}" max="${i + 1}" width="${_widths[i]}" customWidth="1"/>');
    }
    b.write('</cols><sheetData><row r="1" ht="20.4" customHeight="1">');
    for (var i = 0; i < headers.length; i++) {
      b.write(_str('${_col(i)}1', headers[i], i == 3 ? 2 : 1));
    }
    b.write('</row>');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final n = i + 2;
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
      b.write('<autoFilter ref="A1:P${rows.length + 1}"/>');
      b.write('<conditionalFormatting sqref="A2:P${rows.length + 1}">'
          '<cfRule type="expression" dxfId="0" priority="1"><formula>\$B2&lt;&gt;""</formula></cfRule>'
          '</conditionalFormatting>');
    }
    b.write('<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>');
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

  static const _contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_ns" xmlns:r="$_nsR"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">Sheet1!\$A\$1:\$P\$1</definedName></definedNames>'
      '<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>';

  static const _workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// Disalin dari template; warna tema diganti RGB agar sama tanpa file tema.
  /// cellXfs: 1/2 header, 3 tengah, 4 tanggal, 5 teks, 6 umum, 7 angka akuntansi.
  static const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_ns">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mmm/yyyy"/>'
      '<numFmt numFmtId="166" formatCode="_(* #,##0_);_(* \\(#,##0\\);_(* &quot;-&quot;??_);_(@_)"/></numFmts>'
      '<fonts count="3">'
      '<font><sz val="11"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>'
      '<font><sz val="8"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>'
      '<font><sz val="8"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>'
      '</fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><gradientFill degree="90"><stop position="0"><color rgb="FF002060"/></stop>'
      '<stop position="1"><color rgb="FF0070C0"/></stop></gradientFill></fill></fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FFFFFFFF"/></left><right style="thin"><color rgb="FFFFFFFF"/></right>'
      '<top style="thin"><color indexed="64"/></top><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="8">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="49" fontId="1" fillId="2" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="164" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="49" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="166" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '<dxfs count="1"><dxf><border><left style="thin"><color auto="1"/></left><right style="thin"><color auto="1"/></right>'
      '<top style="thin"><color auto="1"/></top><bottom style="thin"><color auto="1"/></bottom></border></dxf></dxfs>'
      '</styleSheet>';
}
