import '../viewmodels/epd_dashboard_viewmodel.dart';

class EpdCollectionPayloadMapper {
  const EpdCollectionPayloadMapper._();

  static Map<String, dynamic> fromFormToApi({
    required String sectionId,
    required EpdDashboardState state,
    required Map<String, dynamic> formData,
  }) {
    final payload = Map<String, dynamic>.from(formData);

    if (sectionId == 'expense_categories') {
      final normalizedName =
          (payload['name'] ?? payload['nombre'])?.toString().trim() ?? '';
      payload['name'] = normalizedName;

      final colorValue = payload['color']?.toString().trim() ?? '';
      payload['color'] = colorValue.isNotEmpty ? colorValue : '#EF4444';

      final iconValue = payload['icon']?.toString().trim() ?? '';
      payload['icon'] = iconValue.isNotEmpty ? iconValue : 'receipt_long';

      final activeRaw = payload['isActive'] ?? payload['activo'];
      payload['isActive'] = _toFlagInt(activeRaw, fallback: 1);

      payload.remove('nombre');
      payload.remove('descripcion');
      payload.remove('activo');
      return payload;
    }

    if (sectionId == 'expenses') {
      payload['categoryId'] =
          (payload['categoryId'] ?? payload['IdTipoGasto'])
              ?.toString()
              .trim() ??
          '';
      payload.remove('IdTipoGasto');

      payload['description'] =
          (payload['description'] ?? payload['descripcion'])
              ?.toString()
              .trim() ??
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

    if (sectionId == 'supplier_assignments') {
      final proveedorId =
          (payload['proveedorId'] ??
                  payload['IdProveedor'] ??
                  payload['supplierId'])
              ?.toString()
              .trim() ??
          '';
      payload['proveedorId'] = proveedorId;

      final rawSucursal =
          (payload['sucursalId'] ??
                  payload['IdSucursal'] ??
                  payload['branchId'])
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

    return payload;
  }

  static Map<String, dynamic> fromApiToForm({
    required String sectionId,
    required Map<String, dynamic> row,
  }) {
    final initialData = Map<String, dynamic>.from(row);

    if (sectionId == 'expense_categories') {
      if ((initialData['name'] == null ||
              initialData['name'].toString().isEmpty) &&
          initialData['nombre'] != null) {
        initialData['name'] = initialData['nombre'];
      }
      if (initialData['color'] == null ||
          initialData['color'].toString().trim().isEmpty) {
        initialData['color'] = '#EF4444';
      }
      if (initialData['icon'] == null ||
          initialData['icon'].toString().trim().isEmpty) {
        initialData['icon'] = 'receipt_long';
      }

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

  static double _toDouble(dynamic rawValue) {
    if (rawValue is num) return rawValue.toDouble();
    return double.tryParse(rawValue?.toString() ?? '') ?? 0.0;
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

    addValue(raw);
    return values;
  }
}
