class QRecaudaSavePreparation {
  final Map<String, dynamic> payload;
  final String? error;

  const QRecaudaSavePreparation({required this.payload, required this.error});
}

class QRecaudaCollectionSaveRules {
  const QRecaudaCollectionSaveRules._();

  static QRecaudaSavePreparation prepare({
    required String sectionId,
    required Map<String, dynamic> rawPayload,
    required bool isEdit,
  }) {
    final payload = Map<String, dynamic>.from(rawPayload);

    _trimStringValues(payload);
    payload.remove('id');

    switch (sectionId) {
      case 'municipalidades':
        return _prepareMunicipalidades(payload);
      case 'mercados':
        return _prepareMercados(payload);
      case 'locales':
        return _prepareLocales(payload);
      case 'cobros':
        return _prepareCobros(payload);
      case 'tipos_negocio':
        return _prepareTiposNegocio(payload);
      case 'usuarios':
        return _prepareUsuarios(payload);
      default:
        return QRecaudaSavePreparation(payload: payload, error: null);
    }
  }

  static QRecaudaSavePreparation _prepareMunicipalidades(
    Map<String, dynamic> payload,
  ) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre de la municipalidad es obligatorio.',
      );
    }
    payload['nombre'] = nombre;
    payload['activo'] = _toFlagInt(
      payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );
    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareMercados(
    Map<String, dynamic> payload,
  ) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre del mercado es obligatorio.',
      );
    }

    final municipalidadId = _firstNonEmpty([
      payload['municipalidadId'],
      payload['idMunicipalidad'],
      payload['municipioId'],
    ]);
    if (municipalidadId.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'Debes seleccionar una municipalidad para el mercado.',
      );
    }

    payload['nombre'] = nombre;
    payload['municipalidadId'] = municipalidadId;
    payload['activo'] = _toFlagInt(
      payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );
    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareLocales(Map<String, dynamic> payload) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre del local es obligatorio.',
      );
    }

    final mercadoId = _firstNonEmpty([
      payload['mercadoId'],
      payload['idMercado'],
    ]);
    final municipalidadId = _firstNonEmpty([
      payload['municipalidadId'],
      payload['idMunicipalidad'],
    ]);
    if (mercadoId.isEmpty && municipalidadId.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'Debes asociar el local a un mercado o municipalidad.',
      );
    }

    payload['nombre'] = nombre;
    payload['mercadoId'] = mercadoId;
    payload['municipalidadId'] = municipalidadId;
    payload['activo'] = _toFlagInt(
      payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );
    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareCobros(Map<String, dynamic> payload) {
    final montoRaw = payload['monto'] ?? payload['amount'] ?? payload['total'];
    final monto = _toDouble(montoRaw);
    if (monto <= 0) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El monto del cobro debe ser mayor a 0.',
      );
    }

    final fecha = _firstNonEmpty([payload['fecha'], payload['date']]);
    payload['monto'] = monto;
    payload['fecha'] = fecha.isEmpty ? DateTime.now().toIso8601String() : fecha;
    payload['estado'] = _toFlagInt(
      payload['estado'] ?? payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareTiposNegocio(
    Map<String, dynamic> payload,
  ) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre del tipo de negocio es obligatorio.',
      );
    }
    payload['nombre'] = nombre;
    payload['activo'] = _toFlagInt(
      payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );
    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareUsuarios(
    Map<String, dynamic> payload,
  ) {
    final nombre = _firstNonEmpty([
      payload['nombre'],
      payload['name'],
      payload['NombreCompleto'],
    ]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre del usuario es obligatorio.',
      );
    }

    final email = _firstNonEmpty([payload['email'], payload['correo']]);
    if (email.isNotEmpty && !_isValidEmail(email)) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El correo del usuario no tiene un formato valido.',
      );
    }

    payload['nombre'] = nombre;
    if (email.isNotEmpty) payload['email'] = email;
    payload['activo'] = _toFlagInt(
      payload['activo'] ?? payload['isActive'],
      fallback: 1,
    );
    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static void _trimStringValues(Map<String, dynamic> payload) {
    for (final key in payload.keys.toList()) {
      final value = payload[key];
      if (value is String) {
        payload[key] = value.trim();
      }
    }
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int _toFlagInt(dynamic rawValue, {int fallback = 1}) {
    if (rawValue == null) return fallback;
    if (rawValue is bool) return rawValue ? 1 : 0;
    if (rawValue is num) return rawValue > 0 ? 1 : 0;
    final text = rawValue.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'si' || text == 'sí') {
      return 1;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return 0;
    }
    return fallback;
  }

  static double _toDouble(dynamic rawValue) {
    if (rawValue is num) return rawValue.toDouble();
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return 0;
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  static bool _isValidEmail(String value) {
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    return RegExp(pattern).hasMatch(value.trim());
  }
}
