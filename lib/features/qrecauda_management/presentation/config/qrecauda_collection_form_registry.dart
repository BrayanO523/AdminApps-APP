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
    'token',
  ];

  static List<String> hiddenSystemFieldsForSection(
    String sectionId, {
    bool isEdit = false,
  }) {
    final hidden = List<String>.from(_baseHiddenSystemFields)
      ..addAll(['creadoEn', 'actualizadoEn', 'creadoPor', 'actualizadoPor']);

    if (isEdit && sectionId == 'cobros') {
      hidden.addAll(['municipalidadId', 'mercadoId', 'localId', 'cobradorId']);
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
          'municipio': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Municipio',
          ),
          'departamento': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Departamento',
          ),
          'porcentaje': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Porcentaje',
          ),
          'slogan': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Slogan',
          ),
          'fechaReferenciaMora': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.date,
            label: 'Fecha Referencia Mora',
          ),
          'logo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Logo URL',
          ),
          'activa': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activa',
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
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'ubicacion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Ubicacion',
          ),
          'codigo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo',
          ),
          'latitud': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Latitud',
          ),
          'longitud': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Longitud',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Activo',
          ),
        };
      case 'locales':
        return {
          'nombreSocial': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre Social',
            isRequired: true,
          ),
          'mercadoId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Mercado',
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.mercadoNames),
          ),
          'municipalidadId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Municipalidad',
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'tipoNegocioId': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Tipo Negocio ID',
          ),
          'representante': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Representante',
          ),
          'telefonoRepresentante': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono Representante',
          ),
          'cuotaDiaria': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Cuota Diaria',
          ),
          'espacioM2': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Espacio M2',
          ),
          'codigo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo',
          ),
          'codigoCatastral': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo Catastral',
          ),
          'clave': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Clave',
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
          'cobradorId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Cobrador',
            optionsResolver: () => _toDropdownOptions(state.usuarioNames),
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
          'localId': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Local ID',
          ),
          'observaciones': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Observaciones',
          ),
          'estado': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Estado',
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
          'municipalidadId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Municipalidad',
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
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
          'rol': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Rol',
            options: const [
              {'value': 'admin', 'label': 'Admin'},
              {'value': 'cobrador', 'label': 'Cobrador'},
            ],
          ),
          'municipalidadId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Municipalidad',
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'mercadoId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Mercado',
            optionsResolver: () => _toDropdownOptions(state.mercadoNames),
          ),
          'codigoCobrador': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo Cobrador',
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
          'municipio': '',
          'departamento': '',
          'porcentaje': 0,
          'slogan': '',
          'logo': '',
          'fechaReferenciaMora': '',
          'activa': true,
        };
      case 'mercados':
        return {
          'nombre': '',
          'municipalidadId': '',
          'ubicacion': '',
          'codigo': '',
          'latitud': 0.0,
          'longitud': 0.0,
          'activo': true,
        };
      case 'locales':
        return {
          'nombreSocial': '',
          'mercadoId': '',
          'municipalidadId': '',
          'tipoNegocioId': '',
          'representante': '',
          'telefonoRepresentante': '',
          'cuotaDiaria': 0.0,
          'espacioM2': 0.0,
          'codigo': '',
          'codigoCatastral': '',
          'clave': '',
          'activo': true,
        };
      case 'cobros':
        return {
          'fecha': DateTime.now().toIso8601String(),
          'monto': 0.0,
          'cobradorId': '',
          'municipalidadId': '',
          'mercadoId': '',
          'localId': '',
          'observaciones': '',
          'estado': 'registrado',
        };
      case 'tipos_negocio':
        return {
          'nombre': '',
          'descripcion': '',
          'municipalidadId': '',
          'activo': true,
        };
      case 'usuarios':
        return {
          'nombre': '',
          'email': '',
          'rol': 'cobrador',
          'municipalidadId': '',
          'mercadoId': '',
          'codigoCobrador': '',
          'activo': true,
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
