import 'dart:convert';

import '../viewmodels/qrecauda_dashboard_viewmodel.dart';

class QRecaudaCollectionPayloadMapper {
  const QRecaudaCollectionPayloadMapper._();

  static Map<String, dynamic> fromApiToForm({
    required String sectionId,
    required Map<String, dynamic> row,
  }) {
    final formData = Map<String, dynamic>.from(row);

    _normalizeFlagFieldForForm(formData, 'activa');
    _normalizeFlagFieldForForm(formData, 'activo');
    _normalizeFlagFieldForForm(formData, 'estado');
    _normalizeFlagFieldForForm(formData, 'isActive');

    if (sectionId == 'locales' &&
        !formData.containsKey('nombreSocial') &&
        formData['nombre'] != null) {
      formData['nombreSocial'] = formData['nombre'];
    }

    if (formData['rutaAsignada'] is List) {
      formData['rutaAsignada'] = (formData['rutaAsignada'] as List)
          .map((e) => e.toString())
          .join(', ');
    }

    if (formData['idsDeudasSaldadas'] is List) {
      formData['idsDeudasSaldadas'] = (formData['idsDeudasSaldadas'] as List)
          .map((e) => e.toString())
          .join(', ');
    }

    if (formData['fechasDeudasSaldadas'] is List) {
      formData['fechasDeudasSaldadas'] =
          (formData['fechasDeudasSaldadas'] as List)
              .map((e) => e.toString())
              .join(', ');
    }

    return formData;
  }

  static Map<String, dynamic> fromFormToApi({
    required String sectionId,
    required QRecaudaDashboardState state,
    required Map<String, dynamic> formData,
  }) {
    final payload = Map<String, dynamic>.from(formData);
    _trimStringValues(payload);

    if (sectionId == 'municipalidades' &&
        payload.containsKey('activo') &&
        !payload.containsKey('activa')) {
      payload['activa'] = payload['activo'];
      payload.remove('activo');
    }

    if (sectionId != 'municipalidades') {
      final hasMunicipalidadId =
          (payload['municipalidadId']?.toString().trim() ?? '').isNotEmpty;
      if (!hasMunicipalidadId && state.selectedMunicipalidades.length == 1) {
        final contextId =
            state.selectedMunicipalidades.first['id']?.toString().trim() ?? '';
        if (contextId.isNotEmpty) {
          payload['municipalidadId'] = contextId;
        }
      }
    }

    _normalizeMaybeListField(payload, 'rutaAsignada');
    _normalizeMaybeListField(payload, 'idsDeudasSaldadas');
    _normalizeMaybeListField(payload, 'fechasDeudasSaldadas');

    final idText = payload['id']?.toString().trim() ?? '';
    if (idText.isEmpty) {
      payload.remove('id');
    }

    _removeEmptyStrings(payload, const {
      'numeroBoleta',
      'observaciones',
      'mercadoId',
      'tipoNegocioId',
      'codigo',
      'codigoCatastral',
      'clave',
      'logo',
      'slogan',
      'telefonoRepresentante',
      'representante',
    });

    return payload;
  }

  static void _trimStringValues(Map<String, dynamic> payload) {
    for (final key in payload.keys.toList()) {
      final value = payload[key];
      if (value is String) {
        payload[key] = value.trim();
      }
    }
  }

  static void _normalizeFlagFieldForForm(
    Map<String, dynamic> payload,
    String key,
  ) {
    if (!payload.containsKey(key)) return;
    final value = payload[key];
    if (value is bool) {
      payload[key] = value ? 1 : 0;
      return;
    }
    if (value is num) {
      payload[key] = value > 0 ? 1 : 0;
      return;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return;
    if (text == 'true' || text == '1' || text == 'si' || text == 'yes') {
      payload[key] = 1;
      return;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      payload[key] = 0;
    }
  }

  static void _normalizeMaybeListField(
    Map<String, dynamic> payload,
    String key,
  ) {
    if (!payload.containsKey(key)) return;
    final value = payload[key];
    if (value == null) return;

    if (value is List) {
      payload[key] = value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return;
    }

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) {
        payload.remove(key);
        return;
      }

      if (text.startsWith('[') && text.endsWith(']')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            payload[key] = decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
            return;
          }
        } catch (_) {
          // Falls back to CSV parsing.
        }
      }

      payload[key] = text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return;
    }

    payload[key] = [value.toString()];
  }

  static void _removeEmptyStrings(
    Map<String, dynamic> payload,
    Set<String> keys,
  ) {
    for (final key in keys) {
      if (!payload.containsKey(key)) continue;
      if ((payload[key]?.toString().trim() ?? '').isEmpty) {
        payload.remove(key);
      }
    }
  }
}
