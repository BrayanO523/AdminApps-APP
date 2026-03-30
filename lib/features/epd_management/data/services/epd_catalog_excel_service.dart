import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:xml/xml.dart';
import 'epd_xlsx_picker_stub.dart'
    if (dart.library.html) 'epd_xlsx_picker_web.dart'
    as xlsx_picker;

class EpdCatalogExcelException implements Exception {
  final String message;
  const EpdCatalogExcelException(this.message);

  @override
  String toString() => message;
}

class EpdCatalogExcelPayload {
  final String templateVersion;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> products;

  const EpdCatalogExcelPayload({
    required this.templateVersion,
    required this.categories,
    required this.products,
  });

  Map<String, dynamic> toJson({required String empresaId}) {
    return {
      'templateVersion': templateVersion,
      'empresaId': empresaId,
      'categories': categories,
      'products': products,
    };
  }
}

class EpdCatalogExcelService {
  static const String templateVersion = 'EPD_CATALOG_V1';
  static const String categoriesSheetName = 'Categorias';
  static const String productsSheetName = 'Productos';
  static const String readmeSheetName = 'README';
  static const Map<String, String> _friendlyColorMap = {
    'azul': '0xFF3498DB',
    'azulclaro': '0xFF5DADE2',
    'azuloscuro': '0xFF1F618D',
    'celeste': '0xFF85C1E9',
    'turquesa': '0xFF1ABC9C',
    'verde': '0xFF27AE60',
    'verdeclaro': '0xFF58D68D',
    'verdeoscuro': '0xFF1E8449',
    'amarillo': '0xFFF1C40F',
    'naranja': '0xFFEB984E',
    'rojo': '0xFFE74C3C',
    'morado': '0xFF8E44AD',
    'rosa': '0xFFFF6FAE',
    'gris': '0xFF95A5A6',
    'negro': '0xFF2C3E50',
    'blanco': '0xFFFFFFFF',
  };

  static Future<void> downloadTemplate() async {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != readmeSheetName) {
      excel.rename(defaultSheet, readmeSheetName);
    }

    final readmeSheet = excel[readmeSheetName];
    _buildReadmeSheet(readmeSheet);

    final categoriesSheet = excel[categoriesSheetName];
    _buildCategoriesSheet(categoriesSheet);

    final productsSheet = excel[productsSheetName];
    _buildProductsSheet(productsSheet);

    final bytes = excel.encode();
    if (bytes == null) {
      throw const EpdCatalogExcelException(
        'No se pudo generar el archivo Excel de plantilla.',
      );
    }

    // Validacion basica del archivo antes de descargarlo.
    try {
      final roundTrip = Excel.decodeBytes(Uint8List.fromList(bytes));
      final hasCategories = _findSheetByName(roundTrip, categoriesSheetName);
      final hasProducts = _findSheetByName(roundTrip, productsSheetName);
      if (hasCategories == null || hasProducts == null) {
        throw const EpdCatalogExcelException(
          'La plantilla generada no contiene las hojas requeridas.',
        );
      }
    } on EpdCatalogExcelException {
      rethrow;
    } catch (_) {
      throw const EpdCatalogExcelException(
        'La plantilla generada no paso la validacion interna.',
      );
    }

    final fileName =
        'epd_catalog_template_${DateTime.now().millisecondsSinceEpoch}';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static CellStyle _titleStyle() {
    return CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blueGrey,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle _sectionStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.blueGrey,
      backgroundColorHex: ExcelColor.grey100,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle _bodyStyle() {
    return CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle _headerStyle({required bool requiredField}) {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: requiredField ? ExcelColor.orange : ExcelColor.blue,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle _sampleRowStyle() {
    return CellStyle(
      backgroundColorHex: ExcelColor.grey100,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static void _setCellStyle({
    required Sheet sheet,
    required int rowIndex,
    required int columnIndex,
    required CellStyle style,
  }) {
    sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: columnIndex,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle =
        style;
  }

  static void _setRowStyle({
    required Sheet sheet,
    required int rowIndex,
    required int columnsCount,
    required CellStyle style,
  }) {
    for (var columnIndex = 0; columnIndex < columnsCount; columnIndex++) {
      _setCellStyle(
        sheet: sheet,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        style: style,
      );
    }
  }

  static void _setAutoFitForColumns({
    required Sheet sheet,
    required int columnsCount,
  }) {
    for (var columnIndex = 0; columnIndex < columnsCount; columnIndex++) {
      sheet.setColumnAutoFit(columnIndex);
    }
  }

  static void _buildReadmeSheet(Sheet readmeSheet) {
    const rowValues = <List<String>>[
      ['Plantilla Catalogo EPD'],
      ['Template Version', templateVersion],
      ['Objetivo', 'Cargar categorias y productos con su relacion.'],
      ['Instrucciones'],
      ['1) Selecciona 1 empresa antes de importar.'],
      ['2) Llena Categorias y luego Productos.'],
      [
        '3) La referencia de categoria en Productos debe existir en Categorias.',
      ],
      ['4) No cambies los nombres de columnas.'],
      ['5) Modo de venta y Es promocion se calculan automaticamente.'],
      ['6) En Color puedes escribir nombre o codigo HEX.'],
      ['7) Esta plantilla no incluye carga de foto de producto.'],
      ['Resumen de campos obligatorios'],
      ['Hoja', 'Campos obligatorios', 'Notas'],
      [
        'Categorias',
        'Referencia categoria, Nombre categoria',
        'Color: Azul, Verde, Rojo, Amarillo, Naranja, Morado, Gris, Negro, Blanco.',
      ],
      [
        'Productos',
        'Referencia producto, Nombre producto, Referencia categoria',
        'La foto se gestiona despues en el sistema.',
      ],
    ];

    for (final row in rowValues) {
      readmeSheet.appendRow(row.map(TextCellValue.new).toList());
    }

    _setRowStyle(
      sheet: readmeSheet,
      rowIndex: 0,
      columnsCount: rowValues[0].length,
      style: _titleStyle(),
    );
    _setRowStyle(
      sheet: readmeSheet,
      rowIndex: 3,
      columnsCount: rowValues[3].length,
      style: _sectionStyle(),
    );
    _setRowStyle(
      sheet: readmeSheet,
      rowIndex: 11,
      columnsCount: rowValues[11].length,
      style: _sectionStyle(),
    );
    _setRowStyle(
      sheet: readmeSheet,
      rowIndex: 12,
      columnsCount: rowValues[12].length,
      style: _sectionStyle(),
    );

    final bodyStyle = _bodyStyle();
    for (var rowIndex = 1; rowIndex < rowValues.length; rowIndex++) {
      if (rowIndex == 3 || rowIndex == 11 || rowIndex == 12) continue;
      _setRowStyle(
        sheet: readmeSheet,
        rowIndex: rowIndex,
        columnsCount: rowValues[rowIndex].length,
        style: bodyStyle,
      );
    }

    _setAutoFitForColumns(sheet: readmeSheet, columnsCount: 3);
  }

  static void _buildCategoriesSheet(Sheet categoriesSheet) {
    const headers = [
      'Referencia categoria',
      'Nombre categoria',
      'Descripcion',
      'Color',
      'Activo (1/0)',
    ];

    categoriesSheet.appendRow(headers.map(TextCellValue.new).toList());
    categoriesSheet.appendRow([
      TextCellValue('cat_bebidas'),
      TextCellValue('Bebidas'),
      TextCellValue('Bebidas frias y calientes'),
      TextCellValue('Azul'),
      TextCellValue('1'),
    ]);

    const requiredColumns = <int>{0, 1};
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      _setCellStyle(
        sheet: categoriesSheet,
        rowIndex: 0,
        columnIndex: columnIndex,
        style: _headerStyle(
          requiredField: requiredColumns.contains(columnIndex),
        ),
      );
    }
    _setRowStyle(
      sheet: categoriesSheet,
      rowIndex: 1,
      columnsCount: headers.length,
      style: _sampleRowStyle(),
    );

    _setAutoFitForColumns(sheet: categoriesSheet, columnsCount: headers.length);
  }

  static void _buildProductsSheet(Sheet productsSheet) {
    const headers = [
      'Referencia producto',
      'Nombre producto',
      'Referencia categoria',
      'Descripcion',
      'Precio unidad',
      'Precio libra',
      'Precio promocion unidad',
      'Precio promocion libra',
      'Costo',
      'Activo (1/0)',
    ];

    productsSheet.appendRow(headers.map(TextCellValue.new).toList());
    productsSheet.appendRow([
      TextCellValue('prod_cafe_americano'),
      TextCellValue('Cafe Americano'),
      TextCellValue('cat_bebidas'),
      TextCellValue('Cafe negro'),
      TextCellValue('35'),
      TextCellValue('0'),
      TextCellValue('0'),
      TextCellValue('0'),
      TextCellValue('20'),
      TextCellValue('1'),
    ]);

    const requiredColumns = <int>{0, 1, 2};
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      _setCellStyle(
        sheet: productsSheet,
        rowIndex: 0,
        columnIndex: columnIndex,
        style: _headerStyle(
          requiredField: requiredColumns.contains(columnIndex),
        ),
      );
    }
    _setRowStyle(
      sheet: productsSheet,
      rowIndex: 1,
      columnsCount: headers.length,
      style: _sampleRowStyle(),
    );

    _setAutoFitForColumns(sheet: productsSheet, columnsCount: headers.length);
  }

  static Future<EpdCatalogExcelPayload?> pickAndParseImportFile() async {
    if (kIsWeb) {
      final webBytes = await xlsx_picker.pickXlsxBytesFromBrowser();
      if (webBytes == null || webBytes.isEmpty) {
        // Usuario cancelo o cerro el selector: no debe tratarse como error.
        return null;
      }
      return _safeParseBytes(webBytes);
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const EpdCatalogExcelException(
        'No se pudieron leer los bytes del archivo seleccionado.',
      );
    }

    return _safeParseBytes(bytes);
  }

  static EpdCatalogExcelPayload parseBytes(Uint8List bytes) {
    final safeBytes = Uint8List.fromList(bytes);
    late final Map<String, List<List<String>>> workbookRows;
    try {
      workbookRows = _readWorkbookRows(safeBytes);
    } catch (_) {
      throw const EpdCatalogExcelException(
        'No se pudo leer el Excel. Usa un archivo .xlsx valido y evita renombrar formatos.',
      );
    }

    final categoriesRows = workbookRows[categoriesSheetName];
    if (categoriesRows == null) {
      throw const EpdCatalogExcelException(
        'No se encontro la hoja "Categorias".',
      );
    }

    final productsRows = workbookRows[productsSheetName];
    if (productsRows == null) {
      throw const EpdCatalogExcelException(
        'No se encontro la hoja "Productos".',
      );
    }

    final categories = _parseCategoriesFromRows(categoriesRows);
    final products = _parseProductsFromRows(productsRows);

    return EpdCatalogExcelPayload(
      templateVersion: templateVersion,
      categories: categories,
      products: products,
    );
  }

  static EpdCatalogExcelPayload _safeParseBytes(Uint8List bytes) {
    try {
      return parseBytes(bytes);
    } on EpdCatalogExcelException {
      rethrow;
    } catch (e) {
      throw EpdCatalogExcelException(
        'No se pudo procesar el Excel seleccionado. Detalle tecnico: $e',
      );
    }
  }

  static const String _officeDocRelsNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Map<String, List<List<String>>> _readWorkbookRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final workbookXml = _readArchiveFileAsString(archive, 'xl/workbook.xml');
    final workbookRelsXml = _readArchiveFileAsString(
      archive,
      'xl/_rels/workbook.xml.rels',
    );
    final sharedStringsXml = _readArchiveFileAsString(
      archive,
      'xl/sharedStrings.xml',
      required: false,
    );

    final sharedStrings = _parseSharedStrings(sharedStringsXml);
    final relsMap = _parseWorkbookRelationships(workbookRelsXml);
    final sheetPathByName = _parseWorkbookSheets(workbookXml, relsMap);

    final result = <String, List<List<String>>>{};
    for (final entry in sheetPathByName.entries) {
      final sheetXml = _readArchiveFileAsString(archive, entry.value);
      result[entry.key] = _parseSheetRows(sheetXml, sharedStrings);
    }
    return result;
  }

  static String _readArchiveFileAsString(
    Archive archive,
    String targetPath, {
    bool required = true,
  }) {
    ArchiveFile? file;
    final normalizedTarget = targetPath.toLowerCase();
    for (final item in archive.files) {
      final name = item.name.toLowerCase();
      if (name == normalizedTarget || '/$name' == normalizedTarget) {
        file = item;
        break;
      }
    }

    if (file == null) {
      if (required) {
        throw EpdCatalogExcelException(
          'Archivo interno faltante en Excel: $targetPath',
        );
      }
      return '';
    }

    final content = file.content;
    if (content is List<int>) {
      return utf8.decode(content, allowMalformed: true);
    }
    if (content is Uint8List) {
      return utf8.decode(content, allowMalformed: true);
    }
    throw EpdCatalogExcelException(
      'No se pudo leer contenido interno del Excel: $targetPath',
    );
  }

  static Map<String, String> _parseWorkbookRelationships(String relsXml) {
    final doc = XmlDocument.parse(relsXml);
    final rels = <String, String>{};
    for (final rel in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'Relationship',
    )) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id == null || id.isEmpty || target == null || target.isEmpty) {
        continue;
      }
      rels[id] = _normalizeWorksheetPath(target);
    }
    return rels;
  }

  static Map<String, String> _parseWorkbookSheets(
    String workbookXml,
    Map<String, String> relsMap,
  ) {
    final doc = XmlDocument.parse(workbookXml);
    final byName = <String, String>{};
    for (final sheet in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'sheet',
    )) {
      final name = sheet.getAttribute('name');
      final rid =
          sheet.getAttribute('id', namespace: _officeDocRelsNs) ??
          sheet.getAttribute('r:id') ??
          sheet.getAttribute('id');
      if (name == null || name.isEmpty || rid == null || rid.isEmpty) {
        continue;
      }
      final path = relsMap[rid];
      if (path != null) {
        byName[name] = path;
      }
    }
    return byName;
  }

  static String _normalizeWorksheetPath(String rawTarget) {
    final target = rawTarget.replaceAll('\\', '/').trim();
    if (target.startsWith('/')) {
      return target.substring(1);
    }
    if (target.startsWith('xl/')) {
      return target;
    }
    return 'xl/$target';
  }

  static List<String> _parseSharedStrings(String sharedStringsXml) {
    if (sharedStringsXml.trim().isEmpty) return const <String>[];
    final doc = XmlDocument.parse(sharedStringsXml);
    final result = <String>[];

    for (final si in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'si',
    )) {
      final textParts = si.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText)
          .toList();
      result.add(textParts.join());
    }

    return result;
  }

  static List<List<String>> _parseSheetRows(
    String sheetXml,
    List<String> sharedStrings,
  ) {
    final doc = XmlDocument.parse(sheetXml);
    final rows = <List<String>>[];

    final rowElements = doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'row',
    );

    for (final rowElement in rowElements) {
      final rowNumber = int.tryParse(rowElement.getAttribute('r') ?? '');
      final index = (rowNumber != null && rowNumber > 0)
          ? rowNumber - 1
          : rows.length;

      while (rows.length <= index) {
        rows.add(<String>[]);
      }

      final valuesByColumn = <int, String>{};
      var fallbackColumn = 0;

      final cells = rowElement.childElements.where((e) => e.name.local == 'c');
      for (final cell in cells) {
        final ref = cell.getAttribute('r');
        final colIndex = ref == null
            ? fallbackColumn
            : _columnIndexFromRef(ref);
        if (colIndex < 0) continue;

        valuesByColumn[colIndex] = _readCellValue(cell, sharedStrings);
        fallbackColumn = colIndex + 1;
      }

      if (valuesByColumn.isEmpty) {
        continue;
      }

      final maxCol = valuesByColumn.keys.reduce((a, b) => a > b ? a : b);
      final rowValues = List<String>.filled(maxCol + 1, '');
      for (final entry in valuesByColumn.entries) {
        rowValues[entry.key] = entry.value.trim();
      }
      rows[index] = rowValues;
    }

    return rows;
  }

  static int _columnIndexFromRef(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (letters.isEmpty) return -1;

    var value = 0;
    for (var i = 0; i < letters.length; i++) {
      final code = letters.codeUnitAt(i);
      if (code < 65 || code > 90) return -1;
      value = value * 26 + (code - 64);
    }
    return value - 1;
  }

  static String _readCellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t') ?? '';

    if (type == 'inlineStr') {
      final textParts = cell.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText)
          .toList();
      return textParts.join();
    }

    final valueElement = cell.childElements.firstWhere(
      (e) => e.name.local == 'v',
      orElse: () => XmlElement(XmlName('v')),
    );
    final rawValue = valueElement.innerText;
    if (rawValue.isEmpty) return '';

    if (type == 's') {
      final idx = int.tryParse(rawValue);
      if (idx == null || idx < 0 || idx >= sharedStrings.length) return '';
      return sharedStrings[idx];
    }
    if (type == 'b') {
      return rawValue == '1' ? '1' : '0';
    }

    return rawValue;
  }

  static List<Map<String, dynamic>> _parseCategoriesFromRows(
    List<List<String>> rows,
  ) {
    final headers = _readHeadersFromRows(rows);

    final categoriaRefIndex = _headerIndex(headers, [
      'referencia categoria',
      'ref categoria',
      'categoria_ref',
    ]);
    final nombreIndex = _headerIndex(headers, [
      'nombre categoria',
      'categoria',
      'nombrecategoria',
    ]);
    final descripcionIndex = _headerIndex(headers, ['descripcion']);
    final colorIndex = _headerIndex(headers, ['color', 'color hex']);
    final activoIndex = _headerIndex(headers, ['activo', 'activo 1/0']);

    if (categoriaRefIndex == null || nombreIndex == null) {
      throw const EpdCatalogExcelException(
        'La hoja Categorias debe incluir al menos Referencia categoria y Nombre categoria.',
      );
    }

    final parsed = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1;

      final categoriaRef = _readCellStringFromStrings(row, categoriaRefIndex);
      final nombreCategoria = _readCellStringFromStrings(row, nombreIndex);
      final descripcion = descripcionIndex == null
          ? ''
          : _readCellStringFromStrings(row, descripcionIndex);
      final color = colorIndex == null
          ? ''
          : _normalizeCategoryColor(
              _readCellStringFromStrings(row, colorIndex),
            );
      final activo = activoIndex == null
          ? ''
          : _readCellStringFromStrings(row, activoIndex);

      if (_isCompletelyEmpty([
        categoriaRef,
        nombreCategoria,
        descripcion,
        color,
        activo,
      ])) {
        continue;
      }

      parsed.add({
        'rowNumber': rowNumber,
        'categoria_ref': categoriaRef,
        'NombreCategoria': nombreCategoria,
        'descripcion': descripcion,
        'Color': color,
        'activo': activo,
      });
    }

    return parsed;
  }

  static List<Map<String, dynamic>> _parseProductsFromRows(
    List<List<String>> rows,
  ) {
    final headers = _readHeadersFromRows(rows);

    final productoRefIndex = _headerIndex(headers, [
      'referencia producto',
      'ref producto',
      'producto_ref',
    ]);
    final nombreIndex = _headerIndex(headers, [
      'nombre producto',
      'producto',
      'nombreproducto',
    ]);
    final categoriaRefIndex = _headerIndex(headers, [
      'referencia categoria',
      'ref categoria',
      'categoria_ref',
    ]);
    final descripcionIndex = _headerIndex(headers, ['descripcion']);
    final precioUnidadIndex = _headerIndex(headers, [
      'precio unidad',
      'preciounidad',
    ]);
    final precioLibraIndex = _headerIndex(headers, [
      'precio libra',
      'preciolibra',
    ]);
    final promoPriceIndex = _headerIndex(headers, [
      'precio promocion unidad',
      'precio promo unidad',
      'promo_price',
    ]);
    final promoPriceLbIndex = _headerIndex(headers, [
      'precio promocion libra',
      'precio promo libra',
      'promo_price_lb',
    ]);
    final costoIndex = _headerIndex(headers, ['costo']);
    final activoIndex = _headerIndex(headers, ['activo', 'activo 1/0']);

    if (productoRefIndex == null ||
        nombreIndex == null ||
        categoriaRefIndex == null) {
      throw const EpdCatalogExcelException(
        'La hoja Productos debe incluir Referencia producto, Nombre producto y Referencia categoria.',
      );
    }

    final parsed = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1;

      final productoRef = _readCellStringFromStrings(row, productoRefIndex);
      final nombreProducto = _readCellStringFromStrings(row, nombreIndex);
      final categoriaRef = _readCellStringFromStrings(row, categoriaRefIndex);
      final descripcion = descripcionIndex == null
          ? ''
          : _readCellStringFromStrings(row, descripcionIndex);
      final precioUnidadRaw = precioUnidadIndex == null
          ? ''
          : _readCellStringFromStrings(row, precioUnidadIndex);
      final precioLibra = precioLibraIndex == null
          ? ''
          : _readCellStringFromStrings(row, precioLibraIndex);
      final promoPrice = promoPriceIndex == null
          ? ''
          : _readCellStringFromStrings(row, promoPriceIndex);
      final promoPriceLb = promoPriceLbIndex == null
          ? ''
          : _readCellStringFromStrings(row, promoPriceLbIndex);
      final costo = costoIndex == null
          ? ''
          : _readCellStringFromStrings(row, costoIndex);
      final activo = activoIndex == null
          ? ''
          : _readCellStringFromStrings(row, activoIndex);

      if (_isCompletelyEmpty([
        productoRef,
        nombreProducto,
        categoriaRef,
        descripcion,
        precioUnidadRaw,
        precioLibra,
        promoPrice,
        promoPriceLb,
        costo,
        activo,
      ])) {
        continue;
      }

      final precioUnidad = _toNumberOrZero(precioUnidadRaw);
      final precioLb = _toNumberOrZero(precioLibra);
      final promoUnit = _toNumberOrZero(promoPrice);
      final promoLb = _toNumberOrZero(promoPriceLb);
      final computedModoVenta = _computeSaleMode(
        precioUnidad: precioUnidad,
        precioLibra: precioLb,
      );
      final computedIsPromo = (promoUnit > 0 || promoLb > 0) ? 1 : 0;

      parsed.add({
        'rowNumber': rowNumber,
        'producto_ref': productoRef,
        'NombreProducto': nombreProducto,
        'categoria_ref': categoriaRef,
        'descripcion': descripcion,
        'preciounidad': precioUnidad,
        'precioLibra': precioLb,
        'ModoVventa': computedModoVenta,
        'is_promo': computedIsPromo,
        'promo_price': promoUnit,
        'promo_price_lb': promoLb,
        'costo': costo,
        'fotoUrl': '',
        'activo': activo,
      });
    }

    return parsed;
  }

  static Map<String, int> _readHeadersFromRows(List<List<String>> rows) {
    if (rows.isEmpty) {
      throw const EpdCatalogExcelException('La hoja no contiene encabezados.');
    }

    final headers = <String, int>{};
    final headerRow = rows.first;
    for (var i = 0; i < headerRow.length; i++) {
      final key = _normalizeHeaderKey(headerRow[i]);
      if (key.isNotEmpty) {
        headers[key] = i;
      }
    }
    return headers;
  }

  static String _readCellStringFromStrings(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static Sheet? _findSheetByName(Excel excel, String target) {
    for (final entry in excel.tables.entries) {
      if (entry.key.trim().toLowerCase() == target.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _parseCategories(Sheet sheet) {
    final headers = _readHeaders(sheet);

    final categoriaRefIndex = _headerIndex(headers, [
      'referencia categoria',
      'ref categoria',
      'categoria_ref',
    ]);
    final nombreIndex = _headerIndex(headers, [
      'nombre categoria',
      'categoria',
      'nombrecategoria',
    ]);
    final descripcionIndex = _headerIndex(headers, ['descripcion']);
    final colorIndex = _headerIndex(headers, ['color', 'color hex']);
    final activoIndex = _headerIndex(headers, ['activo', 'activo 1/0']);

    if (categoriaRefIndex == null || nombreIndex == null) {
      throw const EpdCatalogExcelException(
        'La hoja Categorias debe incluir al menos Referencia categoria y Nombre categoria.',
      );
    }

    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;

      final categoriaRef = _readCellString(row, categoriaRefIndex);
      final nombreCategoria = _readCellString(row, nombreIndex);
      final descripcion = descripcionIndex == null
          ? ''
          : _readCellString(row, descripcionIndex);
      final color = colorIndex == null
          ? ''
          : _normalizeCategoryColor(_readCellString(row, colorIndex));
      final activo = activoIndex == null
          ? ''
          : _readCellString(row, activoIndex);

      if (_isCompletelyEmpty([
        categoriaRef,
        nombreCategoria,
        descripcion,
        color,
        activo,
      ])) {
        continue;
      }

      rows.add({
        'rowNumber': rowNumber,
        'categoria_ref': categoriaRef,
        'NombreCategoria': nombreCategoria,
        'descripcion': descripcion,
        'Color': color,
        'activo': activo,
      });
    }

    return rows;
  }

  static List<Map<String, dynamic>> _parseProducts(Sheet sheet) {
    final headers = _readHeaders(sheet);

    final productoRefIndex = _headerIndex(headers, [
      'referencia producto',
      'ref producto',
      'producto_ref',
    ]);
    final nombreIndex = _headerIndex(headers, [
      'nombre producto',
      'producto',
      'nombreproducto',
    ]);
    final categoriaRefIndex = _headerIndex(headers, [
      'referencia categoria',
      'ref categoria',
      'categoria_ref',
    ]);
    final descripcionIndex = _headerIndex(headers, ['descripcion']);
    final precioUnidadIndex = _headerIndex(headers, [
      'precio unidad',
      'preciounidad',
    ]);
    final precioLibraIndex = _headerIndex(headers, [
      'precio libra',
      'preciolibra',
    ]);
    final promoPriceIndex = _headerIndex(headers, [
      'precio promocion unidad',
      'precio promo unidad',
      'promo_price',
    ]);
    final promoPriceLbIndex = _headerIndex(headers, [
      'precio promocion libra',
      'precio promo libra',
      'promo_price_lb',
    ]);
    final costoIndex = _headerIndex(headers, ['costo']);
    final activoIndex = _headerIndex(headers, ['activo', 'activo 1/0']);

    if (productoRefIndex == null ||
        nombreIndex == null ||
        categoriaRefIndex == null) {
      throw const EpdCatalogExcelException(
        'La hoja Productos debe incluir Referencia producto, Nombre producto y Referencia categoria.',
      );
    }

    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;

      final productoRef = _readCellString(row, productoRefIndex);
      final nombreProducto = _readCellString(row, nombreIndex);
      final categoriaRef = _readCellString(row, categoriaRefIndex);
      final descripcion = descripcionIndex == null
          ? ''
          : _readCellString(row, descripcionIndex);
      final precioUnidadRaw = precioUnidadIndex == null
          ? ''
          : _readCellNumberOrRaw(row, precioUnidadIndex);
      final precioLibra = precioLibraIndex == null
          ? ''
          : _readCellNumberOrRaw(row, precioLibraIndex);
      final promoPrice = promoPriceIndex == null
          ? ''
          : _readCellNumberOrRaw(row, promoPriceIndex);
      final promoPriceLb = promoPriceLbIndex == null
          ? ''
          : _readCellNumberOrRaw(row, promoPriceLbIndex);
      final costo = costoIndex == null
          ? ''
          : _readCellNumberOrRaw(row, costoIndex);
      final activo = activoIndex == null
          ? ''
          : _readCellNumberOrRaw(row, activoIndex);

      if (_isCompletelyEmpty([
        productoRef,
        nombreProducto,
        categoriaRef,
        descripcion,
        precioUnidadRaw,
        precioLibra,
        promoPrice,
        promoPriceLb,
        costo,
        activo,
      ])) {
        continue;
      }

      final precioUnidad = _toNumberOrZero(precioUnidadRaw);
      final precioLb = _toNumberOrZero(precioLibra);
      final promoUnit = _toNumberOrZero(promoPrice);
      final promoLb = _toNumberOrZero(promoPriceLb);
      final computedModoVenta = _computeSaleMode(
        precioUnidad: precioUnidad,
        precioLibra: precioLb,
      );
      final computedIsPromo = (promoUnit > 0 || promoLb > 0) ? 1 : 0;

      rows.add({
        'rowNumber': rowNumber,
        'producto_ref': productoRef,
        'NombreProducto': nombreProducto,
        'categoria_ref': categoriaRef,
        'descripcion': descripcion,
        'preciounidad': precioUnidad,
        'precioLibra': precioLb,
        'ModoVventa': computedModoVenta,
        'is_promo': computedIsPromo,
        'promo_price': promoUnit,
        'promo_price_lb': promoLb,
        'costo': costo,
        'fotoUrl': '',
        'activo': activo,
      });
    }

    return rows;
  }

  static Map<String, int> _readHeaders(Sheet sheet) {
    if (sheet.rows.isEmpty) {
      throw const EpdCatalogExcelException('La hoja no contiene encabezados.');
    }

    final headers = <String, int>{};
    final headerRow = sheet.rows.first;
    for (var i = 0; i < headerRow.length; i++) {
      final key = _normalizeHeaderKey(_readCellString(headerRow, i));
      if (key.isNotEmpty) {
        headers[key] = i;
      }
    }
    return headers;
  }

  static int? _headerIndex(Map<String, int> headers, List<String> aliases) {
    for (final alias in aliases) {
      final index = headers[_normalizeHeaderKey(alias)];
      if (index != null) return index;
    }
    return null;
  }

  static String _normalizeHeaderKey(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _normalizeCategoryColor(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    final key = _normalizeHeaderKey(raw);
    final mapped = _friendlyColorMap[key];
    if (mapped != null) return mapped;

    final cleaned = raw
        .replaceAll(RegExp(r'^#'), '')
        .replaceAll(RegExp(r'^0x', caseSensitive: false), '')
        .trim();

    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      return '0xFF${cleaned.toUpperCase()}';
    }
    if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned)) {
      return '0x${cleaned.toUpperCase()}';
    }

    return raw;
  }

  static num _toNumberOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return 0;
    final normalized = text.replaceAll(',', '.');
    final number = num.tryParse(normalized);
    return number ?? 0;
  }

  static String _computeSaleMode({
    required num precioUnidad,
    required num precioLibra,
  }) {
    final hasUnidad = precioUnidad > 0;
    final hasLibra = precioLibra > 0;
    if (hasUnidad && hasLibra) return 'AMBOS';
    if (hasLibra) return 'PESO';
    return 'UNIDAD';
  }

  static String _readCellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final cell = row[index];
    if (cell == null) return '';
    return _cellValueToString(cell.value).trim();
  }

  static dynamic _readCellNumberOrRaw(List<Data?> row, int index) {
    final raw = _readCellString(row, index);
    if (raw.isEmpty) return '';

    final numberText = raw.replaceAll(',', '.');
    final asNumber = num.tryParse(numberText);
    if (asNumber != null) return asNumber;

    return raw;
  }

  static bool _isCompletelyEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return false;
    }
    return true;
  }

  static String _cellValueToString(dynamic value) {
    if (value == null) return '';

    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final number = value.value;
      if (number == number.roundToDouble()) {
        return number.toInt().toString();
      }
      return number.toString();
    }
    if (value is BoolCellValue) return value.value ? '1' : '0';

    return value.toString();
  }
}
