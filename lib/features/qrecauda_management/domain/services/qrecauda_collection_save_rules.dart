import '../utils/qrecauda_id_normalizer.dart';

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

    final inputId = _text(payload['id']);
    payload.remove('id');
    _injectAuditFields(payload: payload, isEdit: isEdit);

    switch (sectionId) {
      case 'municipalidades':
        return _prepareMunicipalidades(
          payload,
          isEdit: isEdit,
          inputId: inputId,
        );
      case 'mercados':
        return _prepareMercados(payload, isEdit: isEdit, inputId: inputId);
      case 'locales':
        return _prepareLocales(payload, isEdit: isEdit, inputId: inputId);
      case 'cobros':
        return _prepareCobros(payload);
      case 'tipos_negocio':
        return _prepareTiposNegocio(payload, isEdit: isEdit, inputId: inputId);
      case 'usuarios':
        return _prepareUsuarios(payload);
      default:
        return QRecaudaSavePreparation(payload: payload, error: null);
    }
  }

  static QRecaudaSavePreparation _prepareMunicipalidades(
    Map<String, dynamic> payload, {
    required bool isEdit,
    required String inputId,
  }) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre de la municipalidad es obligatorio.',
      );
    }

    payload['nombre'] = nombre;
    payload['activa'] = _toFlagBool(
      payload['activa'] ?? payload['activo'],
      fallback: true,
    );
    payload.remove('activo');
    payload['porcentaje'] = _toDouble(payload['porcentaje'], fallback: 0);

    if (!isEdit) {
      payload['id'] = inputId.isNotEmpty
          ? inputId
          : QRecaudaIdNormalizer.municipalidadId(nombre);
    }

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareMercados(
    Map<String, dynamic> payload, {
    required bool isEdit,
    required String inputId,
  }) {
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
    payload['activo'] = _toFlagBool(
      payload['activo'] ?? payload['activa'],
      fallback: true,
    );
    payload['latitud'] = _toNullableDouble(payload['latitud']);
    payload['longitud'] = _toNullableDouble(payload['longitud']);

    if (!isEdit) {
      payload['id'] = inputId.isNotEmpty
          ? inputId
          : QRecaudaIdNormalizer.mercadoId(municipalidadId, nombre);
    }

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareLocales(
    Map<String, dynamic> payload, {
    required bool isEdit,
    required String inputId,
  }) {
    final nombreSocial = _firstNonEmpty([
      payload['nombreSocial'],
      payload['nombre'],
      payload['name'],
    ]);
    if (nombreSocial.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre social del local es obligatorio.',
      );
    }

    final mercadoId = _firstNonEmpty([
      payload['mercadoId'],
      payload['idMercado'],
    ]);
    if (mercadoId.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'Debes seleccionar un mercado para el local.',
      );
    }

    payload['nombreSocial'] = nombreSocial;
    payload.remove('nombre');
    payload['mercadoId'] = mercadoId;
    payload['activo'] = _toFlagBool(payload['activo'], fallback: true);
    payload['cuotaDiaria'] = _toNullableDouble(payload['cuotaDiaria']);
    payload['espacioM2'] = _toNullableDouble(payload['espacioM2']);
    payload['saldoAFavor'] = _toNullableDouble(payload['saldoAFavor']);
    payload['deudaAcumulada'] = _toNullableDouble(payload['deudaAcumulada']);
    payload['diaCobroMensual'] = _toNullableInt(payload['diaCobroMensual']);

    final codigo = _text(payload['codigo']);
    if (codigo.isNotEmpty) payload['codigoLower'] = codigo.toLowerCase();
    final codigoCatastral = _text(payload['codigoCatastral']);
    if (codigoCatastral.isNotEmpty) {
      payload['codigoCatastralLower'] = codigoCatastral.toLowerCase();
    }
    final clave = _text(payload['clave']);
    if (clave.isNotEmpty) payload['clave'] = clave.toUpperCase();

    if (!isEdit) {
      final generatedId = inputId.isNotEmpty
          ? inputId
          : QRecaudaIdNormalizer.localId(mercadoId, nombreSocial);
      payload['id'] = generatedId;
      payload['qrData'] = _firstNonEmpty([payload['qrData'], generatedId]);
      if (!payload.containsKey('saldoAFavor')) payload['saldoAFavor'] = 0;
      if (!payload.containsKey('deudaAcumulada')) payload['deudaAcumulada'] = 0;
    }

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareCobros(Map<String, dynamic> payload) {
    final monto = _toDouble(payload['monto'], fallback: 0);
    if (monto <= 0) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El monto del cobro debe ser mayor a 0.',
      );
    }

    payload['monto'] = monto;
    final fecha = _firstNonEmpty([payload['fecha'], payload['date']]);
    payload['fecha'] = fecha.isEmpty ? DateTime.now().toIso8601String() : fecha;
    if (_text(payload['estado']).isEmpty) {
      payload['estado'] = 'registrado';
    }

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static QRecaudaSavePreparation _prepareTiposNegocio(
    Map<String, dynamic> payload, {
    required bool isEdit,
    required String inputId,
  }) {
    final nombre = _firstNonEmpty([payload['nombre'], payload['name']]);
    if (nombre.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'El nombre del tipo de negocio es obligatorio.',
      );
    }

    final municipalidadId = _firstNonEmpty([
      payload['municipalidadId'],
      payload['idMunicipalidad'],
    ]);
    if (municipalidadId.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'Debes seleccionar una municipalidad para el tipo de negocio.',
      );
    }

    payload['nombre'] = nombre;
    payload['municipalidadId'] = municipalidadId;
    payload['activo'] = _toFlagBool(payload['activo'], fallback: true);

    if (!isEdit) {
      payload['id'] = inputId.isNotEmpty
          ? inputId
          : QRecaudaIdNormalizer.tipoNegocioId(nombre);
    }

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

    final municipalidadId = _firstNonEmpty([
      payload['municipalidadId'],
      payload['idMunicipalidad'],
    ]);
    if (municipalidadId.isEmpty) {
      return QRecaudaSavePreparation(
        payload: payload,
        error: 'Debes seleccionar una municipalidad para el usuario.',
      );
    }

    payload['nombre'] = nombre;
    if (email.isNotEmpty) payload['email'] = email;
    payload['municipalidadId'] = municipalidadId;

    final rol = _firstNonEmpty([payload['rol']]);
    payload['rol'] = rol.isEmpty ? 'cobrador' : rol.toLowerCase();
    payload['activo'] = _toFlagBool(payload['activo'], fallback: true);

    final codigo = _text(payload['codigoCobrador']);
    if (codigo.isNotEmpty) payload['codigoCobrador'] = codigo.toUpperCase();

    return QRecaudaSavePreparation(payload: payload, error: null);
  }

  static void _injectAuditFields({
    required Map<String, dynamic> payload,
    required bool isEdit,
  }) {
    final nowIso = DateTime.now().toIso8601String();
    final actor = _firstNonEmpty([
      payload['actualizadoPor'],
      payload['creadoPor'],
      'admin-web',
    ]);

    payload['actualizadoEn'] = nowIso;
    payload['actualizadoPor'] = actor;

    if (!isEdit) {
      if (_text(payload['creadoEn']).isEmpty) payload['creadoEn'] = nowIso;
      if (_text(payload['creadoPor']).isEmpty) payload['creadoPor'] = actor;
    } else {
      if (_text(payload['creadoEn']).isEmpty) payload.remove('creadoEn');
      if (_text(payload['creadoPor']).isEmpty) payload.remove('creadoPor');
    }
  }

  static void _trimStringValues(Map<String, dynamic> payload) {
    for (final key in payload.keys.toList()) {
      final value = payload[key];
      if (value is String) {
        payload[key] = value.trim();
      }
    }
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static bool _toFlagBool(dynamic rawValue, {bool fallback = true}) {
    if (rawValue == null) return fallback;
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue > 0;

    final text = rawValue.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'si' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return fallback;
  }

  static double _toDouble(dynamic rawValue, {double fallback = 0}) {
    if (rawValue == null) return fallback;
    if (rawValue is num) return rawValue.toDouble();
    final text = rawValue.toString().trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text.replaceAll(',', '.')) ?? fallback;
  }

  static double? _toNullableDouble(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is num) return rawValue.toDouble();
    final text = rawValue.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  static int? _toNullableInt(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.toInt();
    final text = rawValue.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static bool _isValidEmail(String value) {
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    return RegExp(pattern).hasMatch(value.trim());
  }
}
