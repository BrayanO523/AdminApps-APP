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
    'nombreLower',
    'nombreSocialLower',
    'codigoLower',
    'codigoCatastralLower',
    'ubicacion_geo',
  ];

  static List<String> hiddenSystemFieldsForSection(
    String sectionId, {
    bool isEdit = false,
  }) {
    final hidden = List<String>.from(_baseHiddenSystemFields)
      ..addAll(['creadoEn', 'actualizadoEn', 'creadoPor', 'actualizadoPor']);

    if (sectionId == 'locales') {
      hidden.add('codigoCatastral');
    }

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
            type: DynamicFormFieldType.imageUpload,
            label: 'Logo',
            storagePath: 'qrecauda/municipalidades/{id}/{timestamp}.jpg',
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
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'tipoNegocioId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Tipo de Negocio',
            optionsResolver: () => _toDropdownOptions(state.tipoNegocioNames),
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
          'latitud': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Latitud',
          ),
          'longitud': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Longitud',
          ),
          'frecuenciaCobro': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Frecuencia de Cobro',
            options: const [
              {'value': 'diaria', 'label': 'Diaria'},
              {'value': 'mensual', 'label': 'Mensual'},
            ],
          ),
          'diaCobroMensual': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Dia de Cobro Mensual',
          ),
          'saldoAFavor': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Saldo a Favor',
          ),
          'deudaAcumulada': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Deuda Acumulada',
          ),
          'codigo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo Local (Puesto)',
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
            isRequired: true,
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
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.municipalidadNames),
          ),
          'localId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            label: 'Local',
            isRequired: true,
            optionsResolver: () => _toDropdownOptions(state.localNames),
          ),
          'estado': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Estado',
          ),
          'observaciones': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Observaciones',
          ),
          'cuotaDiaria': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Cuota Diaria',
          ),
          'saldoPendiente': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Saldo Pendiente',
          ),
          'deudaAnterior': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Deuda Anterior',
          ),
          'montoAbonadoDeuda': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Monto Abonado Deuda',
          ),
          'pagoACuota': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Pago a Cuota',
          ),
          'nuevoSaldoFavor': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Nuevo Saldo Favor',
          ),
          'montoMora': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Monto Mora',
          ),
          'correlativo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Correlativo',
          ),
          'anioCorrelativo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Anio Correlativo',
          ),
          'numeroBoleta': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Numero Boleta',
          ),
          'idsDeudasSaldadas': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'IDs Deudas Saldadas (coma)',
          ),
          'fechasDeudasSaldadas': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Fechas Deudas Saldadas (coma)',
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
          'rutaAsignada': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Ruta Asignada (IDs por coma)',
          ),
          'ultimoCorrelativo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Ultimo Correlativo',
          ),
          'anioCorrelativo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Anio Correlativo',
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
          'latitud': 0.0,
          'longitud': 0.0,
          'frecuenciaCobro': 'diaria',
          'diaCobroMensual': 1,
          'saldoAFavor': 0.0,
          'deudaAcumulada': 0.0,
          'codigo': '',
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
          'estado': 'registrado',
          'observaciones': '',
          'cuotaDiaria': 0.0,
          'saldoPendiente': 0.0,
          'deudaAnterior': 0.0,
          'montoAbonadoDeuda': 0.0,
          'pagoACuota': 0.0,
          'nuevoSaldoFavor': 0.0,
          'montoMora': 0.0,
          'correlativo': 0,
          'anioCorrelativo': DateTime.now().year,
          'numeroBoleta': '',
          'idsDeudasSaldadas': '',
          'fechasDeudasSaldadas': '',
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
          'rutaAsignada': '',
          'ultimoCorrelativo': 0,
          'anioCorrelativo': DateTime.now().year,
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
