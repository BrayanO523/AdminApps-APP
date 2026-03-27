import 'dart:convert';

import '../viewmodels/epd_dashboard_viewmodel.dart';

class EpdCollectionPayloadMapper {
  const EpdCollectionPayloadMapper._();

  static Map<String, dynamic> fromFormToApi({
    required String sectionId,
    required EpdDashboardState state,
    required Map<String, dynamic> formData,
  }) {
    final payload = Map<String, dynamic>.from(formData);

    switch (sectionId) {
      case 'companies':
        return _normalizeCompanies(payload);
      case 'branches':
        return _normalizeBranches(payload);
      case 'users':
        return _normalizeUsers(payload);
      case 'clients':
        return _normalizeClients(payload);
      case 'categories':
        return _normalizeCategories(payload);
      case 'products':
        return _normalizeProducts(payload);
      case 'combos':
        return _normalizeCombos(payload);
      case 'expense_categories':
        return _normalizeExpenseCategories(payload);
      case 'expenses':
        return _normalizeExpenses(payload, state);
      case 'suppliers':
        return _normalizeSuppliers(payload);
      case 'supplier_assignments':
        return _normalizeSupplierAssignments(payload);
      default:
        return payload;
    }
  }

  static Map<String, dynamic> fromApiToForm({
    required String sectionId,
    required Map<String, dynamic> row,
  }) {
    final initialData = Map<String, dynamic>.from(row);

    if (sectionId == 'categories') {
      final idCategoria = _firstNonEmpty([
        initialData['idCategoria'],
        initialData['IdCategoria'],
        initialData['id'],
      ]);
      if (idCategoria != null) {
        initialData['idCategoria'] = idCategoria;
        initialData['IdCategoria'] = idCategoria;
      }
      initialData['OrdenVisual'] = _toInt(initialData['OrdenVisual'], 0);
      initialData['activo'] = _toFlagInt(initialData['activo'], fallback: 1);
      return initialData;
    }

    if (sectionId == 'products') {
      final idProducto = _firstNonEmpty([
        initialData['IdProducto'],
        initialData['idProducto'],
        initialData['id'],
      ]);
      if (idProducto != null) {
        initialData['IdProducto'] = idProducto;
      }
      initialData['Activo'] = _toFlagInt(
        initialData['Activo'] ?? initialData['activo'],
        fallback: 1,
      );
      initialData['is_promo'] = _toFlagInt(
        initialData['is_promo'],
        fallback: 0,
      );
      initialData['preciounidad'] = _toDouble(initialData['preciounidad']);
      initialData['precioLibra'] = _toDouble(initialData['precioLibra']);
      initialData['promo_price'] = _toDouble(initialData['promo_price']);
      initialData['promo_price_lb'] = _toDouble(initialData['promo_price_lb']);
      initialData['costo'] = _toDouble(initialData['costo']);
      return initialData;
    }

    if (sectionId == 'combos') {
      final comboId = _firstNonEmpty([
        initialData['idCombo'],
        initialData['IdCombo'],
        initialData['id'],
      ]);
      if (comboId != null) {
        initialData['idCombo'] = comboId;
        initialData['IdCombo'] = comboId;
      }
      initialData['precioCombo'] = _toDouble(
        initialData['precioCombo'] ?? initialData['precio'],
      );
      initialData['activo'] = _toFlagInt(initialData['activo'], fallback: 1);
      return initialData;
    }

    if (sectionId == 'expense_categories') {
      if ((initialData['name'] == null ||
              initialData['name'].toString().isEmpty) &&
          initialData['nombre'] != null) {
        initialData['name'] = initialData['nombre'];
      }
      initialData['color'] = _normalizeColorValue(
        initialData['color'],
        fallback: '0xFF2196F3',
      );
      initialData.remove('icon');

      final activeValue = initialData['isActive'] ?? initialData['activo'];
      initialData['isActive'] = _toFlagInt(activeValue, fallback: 1);
      initialData.remove('activo');
      return initialData;
    }

    if (sectionId == 'expenses') {
      if ((initialData['categoryId'] == null ||
              initialData['categoryId'].toString().isEmpty) &&
          initialData['IdTipoGasto'] != null) {
        initialData['categoryId'] = initialData['IdTipoGasto'];
      }
      if ((initialData['description'] == null ||
              initialData['description'].toString().isEmpty) &&
          initialData['descripcion'] != null) {
        initialData['description'] = initialData['descripcion'];
      }
      if (initialData['amount'] == null && initialData['monto'] != null) {
        initialData['amount'] = initialData['monto'];
      }
      if (initialData['date'] == null && initialData['fecha'] != null) {
        initialData['date'] = initialData['fecha'];
      }

      if (initialData['estado'] == null) {
        final activeRaw = initialData['isActive'] ?? initialData['activo'];
        initialData['estado'] = _toFlagInt(activeRaw, fallback: 1);
      }

      initialData.remove('IdTipoGasto');
      initialData.remove('descripcion');
      initialData.remove('monto');
      initialData.remove('fecha');
      initialData.remove('isActive');
      initialData.remove('activo');
      return initialData;
    }

    if (sectionId == 'supplier_assignments') {
      if ((initialData['proveedorId'] == null ||
              initialData['proveedorId'].toString().isEmpty) &&
          initialData['IdProveedor'] != null) {
        initialData['proveedorId'] = initialData['IdProveedor'];
      }
      if ((initialData['sucursalId'] == null ||
              initialData['sucursalId'].toString().isEmpty) &&
          initialData['IdSucursal'] != null) {
        initialData['sucursalId'] = initialData['IdSucursal'];
      }

      final products = _normalizeSupplierProducts(initialData);
      initialData['productos'] = products;
      initialData['productoIds'] = products
          .map((p) => p['productoId']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final activeRaw =
          initialData['activo'] ??
          initialData['isActive'] ??
          initialData['estado'];
      initialData['activo'] = _toFlagInt(activeRaw, fallback: 1);

      initialData.remove('IdProveedor');
      initialData.remove('IdSucursal');
      initialData.remove('isActive');
      initialData.remove('estado');
      return initialData;
    }

    return initialData;
  }

  static Map<String, dynamic> _normalizeCompanies(
    Map<String, dynamic> payload,
  ) {
    payload['empresaId'] =
        _firstNonEmpty([payload['empresaId'], payload['id']]) ?? '';

    payload['nombreComercial'] = _cleanString(payload['nombreComercial']);
    payload['razonSocial'] = _cleanString(payload['razonSocial']);
    payload['rtn'] = _cleanString(payload['rtn']);
    payload['telefono'] = _cleanString(payload['telefono']);
    payload['correo'] = _cleanString(payload['correo']);
    payload['direccion'] = _cleanString(payload['direccion']);
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);
    return payload;
  }

  static Map<String, dynamic> _normalizeBranches(Map<String, dynamic> payload) {
    final code =
        _firstNonEmpty([payload['IdSucursal'], payload['CodigoSucursal']]) ??
        _generateId('SUC');

    payload['IdSucursal'] = code;
    payload['CodigoSucursal'] = code;
    payload['Nombre'] = _cleanString(payload['Nombre']);
    payload['direccion_referencia'] = _cleanString(
      payload['direccion_referencia'],
    );
    payload['telefono_contacto'] = _cleanString(payload['telefono_contacto']);

    payload['control_inventario'] = _toFlagInt(
      payload['control_inventario'],
      fallback: 1,
    );
    payload['clientes_enabled'] = _toFlagInt(
      payload['clientes_enabled'],
      fallback: 1,
    );
    payload['pesos_rapidos_enabled'] = _toFlagInt(
      payload['pesos_rapidos_enabled'],
      fallback: 0,
    );
    payload['fiscal_enabled'] = _toFlagInt(
      payload['fiscal_enabled'],
      fallback: 0,
    );
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);

    payload['allowed_categories'] = _toStringList(
      payload['allowed_categories'],
    );
    return payload;
  }

  static Map<String, dynamic> _normalizeUsers(Map<String, dynamic> payload) {
    payload['IdUsuario'] =
        _firstNonEmpty([payload['IdUsuario'], payload['id']]) ??
        _generateId('USR');
    payload['NombreCompleto'] = _cleanString(payload['NombreCompleto']);
    payload['CodigoUsuario'] = _cleanString(
      payload['CodigoUsuario'],
    ).toUpperCase();

    payload['rol'] = _firstNonEmpty([payload['rol']]) ?? 'VENDEDOR';
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);

    final assignedBranches = _toStringList(payload['IdSucursalesAsignadas']);
    payload['IdSucursalesAsignadas'] = assignedBranches;
    payload['selected_categories'] = _toStringList(
      payload['selected_categories'],
    );

    final explicitBranch = _cleanString(payload['IdSucursal']);
    payload['IdSucursal'] = explicitBranch.isNotEmpty
        ? explicitBranch
        : (assignedBranches.isNotEmpty ? assignedBranches.first : '');

    return payload;
  }

  static Map<String, dynamic> _normalizeClients(Map<String, dynamic> payload) {
    payload['IdCliente'] =
        _firstNonEmpty([payload['IdCliente'], payload['id']]) ??
        _generateUuidLike();

    payload['NombreCompleto'] = _cleanString(payload['NombreCompleto']);
    payload['RTN'] = _nullIfEmpty(payload['RTN']);
    payload['Movil'] = _nullIfEmpty(payload['Movil']);
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);
    return payload;
  }

  static Map<String, dynamic> _normalizeCategories(
    Map<String, dynamic> payload,
  ) {
    final categoryId =
        _firstNonEmpty([
          payload['idCategoria'],
          payload['IdCategoria'],
          payload['id'],
        ]) ??
        _generateUuidLike();

    payload['idCategoria'] = categoryId;
    payload['IdCategoria'] = categoryId;
    payload['NombreCategoria'] = _cleanString(payload['NombreCategoria']);
    payload['OrdenVisual'] = _toInt(payload['OrdenVisual'], 0);
    payload['Color'] = _firstNonEmpty([payload['Color']]) ?? '0xFF3498DB';
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);
    return payload;
  }

  static Map<String, dynamic> _normalizeProducts(Map<String, dynamic> payload) {
    final productId =
        _firstNonEmpty([payload['IdProducto'], payload['id']]) ??
        _generateId('PROD');
    payload['IdProducto'] = productId;

    payload['NombreProducto'] = _cleanString(payload['NombreProducto']);
    payload['descripcion'] = _cleanString(payload['descripcion']);

    payload['preciounidad'] = _toDouble(payload['preciounidad']);
    payload['precioLibra'] = _toDouble(payload['precioLibra']);
    payload['costo'] = _toDouble(payload['costo']);
    payload['promo_price'] = _toDouble(payload['promo_price']);
    payload['promo_price_lb'] = _toDouble(payload['promo_price_lb']);

    payload['is_promo'] = _toFlagInt(payload['is_promo'], fallback: 0);
    if (payload['is_promo'] == 0) {
      payload['promo_price'] = 0.0;
      payload['promo_price_lb'] = 0.0;
    }

    final hasUnit = _toDouble(payload['preciounidad']) > 0;
    final hasLb = _toDouble(payload['precioLibra']) > 0;
    payload['ModoVventa'] = hasUnit && hasLb
        ? 'AMBOS'
        : hasLb
        ? 'PESO'
        : 'UNIDAD';

    payload['Activo'] = _toFlagInt(
      payload['Activo'] ?? payload['activo'],
      fallback: 1,
    );
    payload.remove('activo');

    return payload;
  }

  static Map<String, dynamic> _normalizeCombos(Map<String, dynamic> payload) {
    final comboId =
        _firstNonEmpty([
          payload['idCombo'],
          payload['IdCombo'],
          payload['id'],
        ]) ??
        'CMB-${DateTime.now().millisecondsSinceEpoch}';

    payload['idCombo'] = comboId;
    payload['IdCombo'] = comboId;

    payload['nombre'] = _cleanString(payload['nombre']);
    payload['descripcion'] = _cleanString(payload['descripcion']);
    payload['precioCombo'] = _toDouble(
      payload['precioCombo'] ?? payload['precio'],
    );
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);

    payload['sucursales_asignadas'] = _toStringList(
      payload['sucursales_asignadas'],
    );
    payload['productos_combo'] = _toStringList(payload['productos_combo']);
    return payload;
  }

  static Map<String, dynamic> _normalizeExpenseCategories(
    Map<String, dynamic> payload,
  ) {
    payload['id'] = _firstNonEmpty([payload['id']]) ?? _generateUuidLike();

    payload['name'] =
        (payload['name'] ?? payload['nombre'])?.toString().trim() ?? '';

    payload['color'] = _normalizeColorValue(
      payload['color'],
      fallback: '0xFF2196F3',
    );

    final activeRaw = payload['isActive'] ?? payload['activo'];
    payload['isActive'] = _toFlagInt(activeRaw, fallback: 1);

    payload.remove('nombre');
    payload.remove('descripcion');
    payload.remove('activo');
    payload.remove('icon');
    return payload;
  }

  static Map<String, dynamic> _normalizeExpenses(
    Map<String, dynamic> payload,
    EpdDashboardState state,
  ) {
    payload['id'] = _firstNonEmpty([payload['id']]) ?? _generateUuidLike();

    payload['categoryId'] =
        (payload['categoryId'] ?? payload['IdTipoGasto'])?.toString().trim() ??
        '';
    payload.remove('IdTipoGasto');

    payload['description'] =
        (payload['description'] ?? payload['descripcion'])?.toString().trim() ??
        '';
    payload.remove('descripcion');

    final rawAmount = payload['amount'] ?? payload['monto'];
    payload['amount'] = _toDouble(rawAmount);
    payload.remove('monto');

    final rawDate = payload['date'] ?? payload['fecha'];
    payload['date'] = (rawDate?.toString().trim().isNotEmpty ?? false)
        ? rawDate.toString().trim()
        : DateTime.now().toIso8601String();
    payload.remove('fecha');

    final activeRaw =
        payload['estado'] ?? payload['isActive'] ?? payload['activo'];
    payload['estado'] = _toFlagInt(activeRaw, fallback: 1);
    payload.remove('isActive');
    payload.remove('activo');

    final categoryId = payload['categoryId']?.toString().trim() ?? '';
    if (categoryId.isNotEmpty) {
      final options = state.getDropdownOptions('expense_categories');
      for (final option in options) {
        if (option['value']?.toString() == categoryId) {
          payload['categoryName'] = option['label']?.toString() ?? '';
          break;
        }
      }
    }

    return payload;
  }

  static Map<String, dynamic> _normalizeSuppliers(
    Map<String, dynamic> payload,
  ) {
    payload['idProveedor'] =
        _firstNonEmpty([payload['idProveedor'], payload['id']]) ??
        _generateId('PROV');

    payload['nombre'] = _cleanString(payload['nombre']);
    payload['telefono'] = _nullIfEmpty(payload['telefono']);
    payload['email'] = _nullIfEmpty(payload['email']);
    payload['direccion'] = _nullIfEmpty(payload['direccion']);
    payload['notas'] = _nullIfEmpty(payload['notas']);
    payload['esGlobal'] = _toFlagInt(payload['esGlobal'], fallback: 1);
    payload['activo'] = _toFlagInt(payload['activo'], fallback: 1);

    return payload;
  }

  static Map<String, dynamic> _normalizeSupplierAssignments(
    Map<String, dynamic> payload,
  ) {
    final proveedorId =
        (payload['proveedorId'] ??
                payload['IdProveedor'] ??
                payload['supplierId'])
            ?.toString()
            .trim() ??
        '';
    payload['proveedorId'] = proveedorId;

    final rawSucursal =
        (payload['sucursalId'] ?? payload['IdSucursal'] ?? payload['branchId'])
            ?.toString()
            .trim() ??
        '';
    payload['sucursalId'] =
        rawSucursal.isEmpty || rawSucursal.toUpperCase() == 'GLOBAL'
        ? null
        : rawSucursal;

    final products = _normalizeSupplierProducts(payload);
    payload['productos'] = products;

    final activeRaw =
        payload['activo'] ?? payload['isActive'] ?? payload['estado'];
    payload['activo'] = _toFlagInt(activeRaw, fallback: 1);

    if (proveedorId.isNotEmpty) {
      final scope = payload['sucursalId']?.toString().trim();
      payload['id'] =
          '${proveedorId}_${scope == null || scope.isEmpty ? 'GLOBAL' : scope}';
    }

    payload.remove('IdProveedor');
    payload.remove('supplierId');
    payload.remove('IdSucursal');
    payload.remove('branchId');
    payload.remove('productoId');
    payload.remove('productoIds');
    payload.remove('isActive');
    payload.remove('estado');
    return payload;
  }

  static int _toFlagInt(dynamic rawValue, {int fallback = 1}) {
    if (rawValue == null) return fallback;
    if (rawValue is bool) return rawValue ? 1 : 0;
    if (rawValue is num) return rawValue > 0 ? 1 : 0;
    final text = rawValue.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'si') {
      return 1;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return 0;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) return fallback;
    return parsed > 0 ? 1 : 0;
  }

  static int _toInt(dynamic rawValue, int fallback) {
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.round();
    return int.tryParse(rawValue?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic rawValue) {
    if (rawValue is num) return rawValue.toDouble();
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return 0.0;
    return double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
  }

  static String _normalizeColorValue(
    dynamic rawValue, {
    String fallback = '0xFF2196F3',
  }) {
    if (rawValue == null) return fallback;

    if (rawValue is num) {
      final hex = rawValue.toInt().toRadixString(16).toUpperCase();
      final padded = hex.padLeft(8, '0');
      return '0x$padded';
    }

    final raw = rawValue.toString().trim();
    if (raw.isEmpty) return fallback;

    final cleaned = raw
        .replaceAll('#', '')
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .trim();

    final hex6 = RegExp(r'^[0-9A-Fa-f]{6}$');
    if (hex6.hasMatch(cleaned)) {
      return '0xFF${cleaned.toUpperCase()}';
    }

    final hex8 = RegExp(r'^[0-9A-Fa-f]{8}$');
    if (hex8.hasMatch(cleaned)) {
      return '0x${cleaned.toUpperCase()}';
    }

    return fallback;
  }

  static List<Map<String, dynamic>> _normalizeSupplierProducts(
    Map<String, dynamic> payload,
  ) {
    final products = <Map<String, dynamic>>[];

    final rawProducts = payload['productos'];
    if (rawProducts is Iterable) {
      for (final item in rawProducts) {
        if (item is Map) {
          final productId =
              (item['productoId'] ?? item['IdProducto'])?.toString().trim() ??
              '';
          if (productId.isEmpty) continue;
          products.add({
            'productoId': productId,
            'variantId': item['variantId']?.toString(),
            'activo': _toFlagInt(item['activo'], fallback: 1),
          });
        }
      }
      if (products.isNotEmpty) return products;
    }

    final selectedProductIds = _toStringList(
      payload['productoIds'] ?? payload['productoId'],
    );
    for (final productId in selectedProductIds) {
      products.add({'productoId': productId, 'variantId': null, 'activo': 1});
    }
    return products;
  }

  static List<String> _toStringList(dynamic raw) {
    final values = <String>[];

    void addValue(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !values.contains(text)) {
        values.add(text);
      }
    }

    if (raw is Iterable) {
      for (final item in raw) {
        addValue(item);
      }
      return values;
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is Iterable) {
            for (final item in parsed) {
              addValue(item);
            }
            return values;
          }
        } catch (_) {}
      }
      addValue(trimmed);
      return values;
    }

    addValue(raw);
    return values;
  }

  static String _cleanString(dynamic raw) => (raw?.toString() ?? '').trim();

  static String? _nullIfEmpty(dynamic raw) {
    final cleaned = _cleanString(raw);
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String _generateId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    return '$prefix-$ts';
  }

  static String _generateUuidLike() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final padded = ts.padLeft(32, '0').substring(0, 32);
    return '${padded.substring(0, 8)}-${padded.substring(8, 12)}-${padded.substring(12, 16)}-${padded.substring(16, 20)}-${padded.substring(20, 32)}';
  }
}
