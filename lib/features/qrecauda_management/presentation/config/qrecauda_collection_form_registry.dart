import '../../../shared/presentation/widgets/dynamic_form_field_schema.dart';
import '../viewmodels/qrecauda_dashboard_viewmodel.dart';

class QRecaudaCollectionFormRegistry {
  const QRecaudaCollectionFormRegistry._();

  static const List<String> _baseHiddenSystemFields = [
    'createdAt',
    'updatedAt',
    'created_at',
    'updated_at',
    'last_modified',
    'last_update_cloud',
    'sync_status',
    'creado_por',
    'modificado_por',
    'token',
  ];

  static List<String> hiddenSystemFieldsForSection(
    String sectionId, {
    bool isEdit = false,
  }) {
    final hidden = List<String>.from(_baseHiddenSystemFields);
    // En edicion no se debe permitir tocar IDs internos de relacion.
    if (isEdit && sectionId == 'cobros') {
      hidden.addAll(['municipalidadId', 'mercadoId', 'localId', 'usuarioId']);
    }
    return hidden;
  }

  static Map<String, DynamicFormFieldSchema> buildFieldSchemas({
    required String sectionId,
    required QRecaudaDashboardState state,
  }) {
    switch (sectionId) {
      case 'municipalidades':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre',
            isRequired: true,
          ),
          'direccion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Direccion',
          ),
          'telefono': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono',
          ),
          'correo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Correo',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'mercados':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre de Mercado',
            isRequired: true,
          ),
          'municipalidadId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Municipalidad',
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'direccion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Direccion',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'locales':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre del Local',
            isRequired: true,
          ),
          'mercadoId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Mercado',
            optionsResolver: () => _toDropdownOptions(state.mercadoNames),
          ),
          'municipalidadId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Municipalidad',
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'numeroLocal': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Numero de Local',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'cobros':
        return {
          'fecha': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.date,
            label: 'Fecha',
          ),
          'monto': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Monto',
            isRequired: true,
          ),
          'usuarioId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Usuario',
            optionsResolver: () => _toDropdownOptions(state.usuarioNames),
          ),
          'descripcion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Descripcion',
          ),
          'estado': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'tipos_negocio':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre',
            isRequired: true,
          ),
          'descripcion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Descripcion',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'usuarios':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre',
            isRequired: true,
          ),
          'email': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Correo',
          ),
          'telefono': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono',
          ),
          'rol': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Rol',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      default:
        return const {};
    }
  }

  static Map<String, dynamic> baseFieldsForSection(String sectionId) {
    switch (sectionId) {
      case 'municipalidades':
        return {
          'nombre': '',
          'direccion': '',
          'telefono': '',
          'correo': '',
          'activo': 1,
        };
      case 'mercados':
        return {
          'nombre': '',
          'municipalidadId': '',
          'direccion': '',
          'activo': 1,
        };
      case 'locales':
        return {
          'nombre': '',
          'numeroLocal': '',
          'mercadoId': '',
          'municipalidadId': '',
          'activo': 1,
        };
      case 'cobros':
        return {
          'fecha': DateTime.now().toIso8601String(),
          'monto': 0.0,
          'descripcion': '',
          'usuarioId': '',
          'estado': 1,
        };
      case 'tipos_negocio':
        return {'nombre': '', 'descripcion': '', 'activo': 1};
      case 'usuarios':
        return {
          'nombre': '',
          'email': '',
          'telefono': '',
          'rol': '',
          'activo': 1,
        };
      default:
        return {};
    }
  }

  static List<Map<String, dynamic>> _toDropdownOptions(
    Map<String, String> source,
  ) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return entries
        .map((entry) => {'value': entry.key, 'label': entry.value})
        .toList();
  }
}
