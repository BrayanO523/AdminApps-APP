import '../viewmodels/qrecauda_dashboard_viewmodel.dart';

class QRecaudaCollectionPayloadMapper {
  const QRecaudaCollectionPayloadMapper._();

  static Map<String, dynamic> fromApiToForm({
    required String sectionId,
    required Map<String, dynamic> row,
  }) {
    final formData = Map<String, dynamic>.from(row);
    _normalizeFlagFieldForForm(formData, 'activo');
    _normalizeFlagFieldForForm(formData, 'estado');
    _normalizeFlagFieldForForm(formData, 'isActive');
    return formData;
  }

  static Map<String, dynamic> fromFormToApi({
    required String sectionId,
    required QRecaudaDashboardState state,
    required Map<String, dynamic> formData,
  }) {
    final payload = Map<String, dynamic>.from(formData);
    _trimStringValues(payload);

    final idText = payload['id']?.toString().trim() ?? '';
    if (idText.isEmpty) {
      payload.remove('id');
    }

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
    if (text == 'true' || text == '1' || text == 'si' || text == 'sí') {
      payload[key] = 1;
      return;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      payload[key] = 0;
    }
  }
}
