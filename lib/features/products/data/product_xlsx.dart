import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../domain/product_export.dart';

/// XLSX asli: angka tetap numerik, logo tertanam, header dan filter bisa dipakai di Excel.
abstract final class ProductXlsx {
  static const headers = [...ProductExportData.headers, 'Harga modal (Rp)', 'Nilai stok (Rp)'];
  static const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _pkg = 'http://schemas.openxmlformats.org/package/2006/relationships';

  static Uint8List build(ProductExportData data) {
    final archive = Archive();
    void add(String path, String xml) => archive.addFile(ArchiveFile.bytes(path, utf8.encode(xml)));
    final hasLogo = data.logoPng != null;
    add(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Default Extension="png" ContentType="image/png"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '${hasLogo ? '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>' : ''}'
          '</Types>',
    );
    add(
      '_rels/.rels',
      '<Relationships xmlns="$_pkg"><Relationship Id="rId1" Type="$_rel/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    final last = data.products.length + 9;
    add(
      'xl/workbook.xml',
      '<workbook xmlns="$_ns" xmlns:r="$_rel">'
          '<sheets><sheet name="Produk" sheetId="1" r:id="rId1"/></sheets>'
          '<definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">Produk!\$1:\$8</definedName>'
          '<definedName name="_xlnm.Print_Area" localSheetId="0">Produk!\$A\$1:\$M\$$last</definedName></definedNames>'
          '<calcPr fullCalcOnLoad="1"/></workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '<Relationships xmlns="$_pkg">'
          '<Relationship Id="rId1" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="$_rel/styles" Target="styles.xml"/></Relationships>',
    );
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', _sheet(data, hasLogo));
    if (hasLogo) {
      addLogo(archive, data.logoPng!);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Logo yang sama dipakai pada ekspor katalog dan laporan penjualan.
  static void addLogo(Archive archive, Uint8List png) {
    void add(String path, String xml) => archive.addFile(ArchiveFile.bytes(path, utf8.encode(xml)));
    archive.addFile(ArchiveFile.bytes('xl/media/logo.png', png));
    add(
      'xl/worksheets/_rels/sheet1.xml.rels',
      '<Relationships xmlns="$_pkg">'
          '<Relationship Id="rIdLogo" Type="$_rel/drawing" Target="../drawings/drawing1.xml"/></Relationships>',
    );
    add(
      'xl/drawings/_rels/drawing1.xml.rels',
      '<Relationships xmlns="$_pkg">'
          '<Relationship Id="rId1" Type="$_rel/image" Target="../media/logo.png"/></Relationships>',
    );
    final logo = img.decodePng(png);
    if (logo == null) throw const FormatException('Logo distributor bukan PNG yang valid.');
    final ratio = logo.width / logo.height;
    final width = ratio >= 1300000 / 1100000 ? 1300000 : (1100000 * ratio).round();
    final height = ratio >= 1300000 / 1100000 ? (1300000 / ratio).round() : 1100000;
    add('xl/drawings/drawing1.xml', _drawing.replaceAll('1300000', '$width').replaceAll('1100000', '$height'));
  }

  static String _sheet(ProductExportData data, bool hasLogo) {
    final last = data.products.length + 8;
    final totalRow = last + 1;
    const widths = [6, 23, 36, 18, 12, 19, 19, 12, 42, 12, 14, 20, 24];
    final b = StringBuffer(
      '<worksheet xmlns="$_ns" xmlns:r="$_rel">'
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:M$totalRow"/>'
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="8" topLeftCell="A9" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="20"/><cols>',
    );
    for (var i = 0; i < widths.length; i++) {
      b.write('<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>');
    }
    b.write('</cols><sheetData>');
    final header = [
      data.name,
      data.settings.address,
      data.contact,
      data.settings.bankInfo,
      'DAFTAR PRODUK',
      data.summary,
      [
        data.settings.invoiceFooter,
        'Modal = HPP rata-rata (atau harga beli bila HPP belum ada). Nilai stok tidak menghitung bundle dan barang tanpa stok.',
        if (data.hasMissingCosts)
          'PERHATIAN: ada produk yang harga modalnya belum tersedia; total nilai stok belum lengkap.',
      ].where((s) => s.isNotEmpty).join('\n'),
    ];
    for (var i = 0; i < header.length; i++) {
      final row = i + 1;
      final column = i < 4 ? 'C' : 'A';
      final lines = header[i].split('\n').fold<int>(0, (n, line) => n + (line.length / 150).ceil().clamp(1, 100));
      final height = i == 0 || i == 4 ? 30 : (lines * 14 + 8).clamp(28, 409);
      b.write(
        '<row r="$row" ht="$height" customHeight="1">'
        '${_text('$column$row', header[i], i == 0 || i == 4 ? 1 : 0)}</row>',
      );
    }
    b.write('<row r="8" ht="30" customHeight="1">');
    for (var i = 0; i < headers.length; i++) {
      b.write(_text('${_col(i)}8', headers[i], 2));
    }
    b.write('</row>');
    for (var i = 0; i < data.products.length; i++) {
      final row = i + 9;
      final cells = data.row(i);
      final lineCount = (cells[8].toString().length / 40).ceil().clamp(1, 12);
      final height = (lineCount * 16 + 12).clamp(36, 210);
      b.write('<row r="$row" ht="$height" customHeight="1">');
      for (var j = 0; j < cells.length; j++) {
        final cell = '${_col(j)}$row';
        final value = cells[j];
        b.write(value is num ? '<c r="$cell" s="3"><v>$value</v></c>' : _text(cell, '$value', 0));
      }
      final product = data.products[i];
      final cost = data.unitCost(product);
      b.write(cost == null || product.isBundle ? _text('L$row', '-', 0) : '<c r="L$row" s="3"><v>$cost</v></c>');
      if (!product.trackStock || product.isBundle) {
        b.write('<c r="M$row" s="3"><v>0</v></c>');
      } else if (cost == null) {
        b.write(_text('M$row', '-', 0));
      } else {
        final value = product.stock > 0 ? product.stock * cost : 0;
        b.write('<c r="M$row" s="3"><f>MAX(J$row,0)*L$row</f><v>$value</v></c>');
      }
      b.write('</row>');
    }
    final totalFormula = data.products.isEmpty ? '0' : 'SUM(M9:M$last)';
    b.write(
      '<row r="$totalRow" ht="30" customHeight="1">'
      '${_text('A$totalRow', data.hasMissingCosts ? 'Total nilai stok (modal belum lengkap)' : 'Total nilai stok', 2)}'
      '<c r="M$totalRow" s="3"><f>$totalFormula</f><v>${data.totalStockValue}</v></c></row>',
    );
    b.write('</sheetData><autoFilter ref="A8:M$last"/><mergeCells count="8">');
    for (var row = 1; row <= 7; row++) {
      b.write('<mergeCell ref="${row <= 4 ? 'C' : 'A'}$row:M$row"/>');
    }
    b.write('<mergeCell ref="A$totalRow:L$totalRow"/>');
    b.write(
      '</mergeCells><pageMargins left="0.3" right="0.3" top="0.4" bottom="0.4" header="0.2" footer="0.2"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>'
      '<headerFooter><oddFooter>&amp;RHalaman &amp;P / &amp;N</oddFooter></headerFooter>',
    );
    if (hasLogo) b.write('<drawing r:id="rIdLogo"/>');
    return '${b.toString()}</worksheet>';
  }

  static String _col(int i) => String.fromCharCode(65 + i);
  static String _text(String cell, String value, int style) =>
      '<c r="$cell" s="$style" t="inlineStr"><is><t xml:space="preserve">${_escape(value)}</t></is></c>';
  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static const _styles =
      '<styleSheet xmlns="$_ns">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0"/></numFmts>'
      '<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="18"/><color rgb="FF173F52"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF173F52"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="4">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment vertical="center" horizontal="right"/></xf>'
      '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';

  static const _drawing =
      '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$_rel">'
      '<xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>76200</xdr:colOff>'
      '<xdr:row>0</xdr:row><xdr:rowOff>76200</xdr:rowOff></xdr:from><xdr:ext cx="1300000" cy="1100000"/>'
      '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="1" name="Logo distributor"/><xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
      '<xdr:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
      '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1300000" cy="1100000"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>';
}
