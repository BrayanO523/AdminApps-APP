import '../../../shared/presentation/widgets/dynamic_form_field_schema.dart';
import '../viewmodels/epd_dashboard_viewmodel.dart';

class EpdCollectionFormRegistry {
  const EpdCollectionFormRegistry._();

  static const List<String> _baseHiddenSystemFields = [
    'creado_offline',
    'modificado_offline',
    'SYNC_STATUS',
    'last_modified',
    'last_updated_cloud',
    'fechacreacion',
    'fecha_creacion_registro',
    'creado_por',
    'modificado_por',
    'idusuario',
    'Idvendedor',
    'seller_id',
    'estado',
    'Favorito',
    'OrdenFavorito',
    'contador_ventas',
    'isTemplate',
    'source_template_id',
    'sync_status',
    'adminId',
    'empresaId',
    'IdProducto',
    'IdCombo',
    'IdInventario',
    'IdTransaccion',
    'IdVenta',
    'IdCliente',
    'IdUsuario',
    'selected_categories',
    'IdSucursalesAsignadas',
    'IdSucursal',
    'items',
    'combo_items_editor',
  ];

  static List<String> hiddenSystemFieldsForSection(String sectionId) {
    final hidden = List<String>.from(_baseHiddenSystemFields);

    if (sectionId == 'branches') {
      hidden.remove('control_inventario');
      hidden.remove('clientes_enabled');
      hidden.remove('pesos_rapidos_enabled');
      hidden.remove('fiscal_enabled');
      hidden.remove('CodigoSucursal');
    }

    if (sectionId == 'expenses') {
      hidden.remove('estado');
      hidden.remove('date');
    }

    if (sectionId == 'expense_categories') {
      hidden.add('icon');
    }

    if (sectionId == 'companies') {
      hidden.remove('activo');
    }

    if (sectionId == 'products') {
      hidden.remove('Activo');
    }

    return hidden;
  }

  static List<String> formFieldOrder(String sectionId) {
    switch (sectionId) {
      case 'companies':
        return const [
          'nombreComercial',
          'razonSocial',
          'rtn',
          'telefono',
          'correo',
          'direccion',
          'logoUrl',
          'activo',
        ];
      case 'branches':
        return const [
          'Nombre',
          'CodigoSucursal',
          'direccion_referencia',
          'telefono_contacto',
          'control_inventario',
          'clientes_enabled',
          'pesos_rapidos_enabled',
          'fiscal_enabled',
          'activo',
          'assigned_seller_ids',
          'allowed_categories',
        ];
      case 'users':
        return const [
          'NombreCompleto',
          'CodigoUsuario',
          'pin',
          'rol',
          'activo',
        ];
      case 'clients':
        return const ['NombreCompleto', 'RTN', 'Movil', 'activo'];
      case 'categories':
        return const ['NombreCategoria', 'OrdenVisual', 'Color', 'activo'];
      case 'products':
        return const [
          'IdCategoria',
          'NombreProducto',
          'descripcion',
          'fotoUrl',
          'preciounidad',
          'precioLibra',
          'costo',
          'ModoVventa',
          'is_promo',
          'promo_price',
          'promo_price_lb',
          'Activo',
        ];
      case 'combos':
        return const [
          'nombre',
          'descripcion',
          'fotoUrl',
          'precioCombo',
          'productos_combo',
          'sucursales_asignadas',
          'activo',
        ];
      case 'expense_categories':
        return const ['name', 'color', 'isActive'];
      case 'expenses':
        return const [
          'amount',
          'categoryId',
          'date',
          'description',
          'branchId',
          'registeredByUserId',
          'estado',
        ];
      case 'suppliers':
        return const [
          'nombre',
          'telefono',
          'email',
          'direccion',
          'notas',
          'esGlobal',
          'activo',
        ];
      case 'supplier_assignments':
        return const ['proveedorId', 'sucursalId', 'productoIds', 'activo'];
      default:
        return const [];
    }
  }

  static Map<String, DynamicFormFieldSchema> buildFieldSchemas({
    required String sectionId,
    required EpdDashboardState state,
  }) {
    switch (sectionId) {
      case 'branches':
        return {
          'Nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre de Sucursal',
            isRequired: true,
          ),
          'CodigoSucursal': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo Sucursal',
            isReadOnly: true,
          ),
          'direccion_referencia': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Direccion o Referencia',
          ),
          'telefono_contacto': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono de Contacto',
          ),
          'control_inventario': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Control de Inventario',
          ),
          'clientes_enabled': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Gestion de Clientes',
          ),
          'pesos_rapidos_enabled': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Pesos Rapidos',
          ),
          'fiscal_enabled': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Facturacion Fiscal (CAI / SAR)',
          ),
          'assigned_seller_ids': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('users'),
            label: 'Vendedores Asignados',
          ),
          'allowed_categories': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('categories'),
            label: 'Categorias Permitidas',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'users':
        return {
          'NombreCompleto': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre Completo',
            isRequired: true,
          ),
          'CodigoUsuario': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Codigo de Acceso',
            isRequired: true,
          ),
          'pin': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'PIN',
          ),
          'rol': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: [
              {'value': 'VENDEDOR', 'label': 'Vendedor'},
              {'value': 'ADMIN', 'label': 'Administrador'},
            ],
            label: 'Rol',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'categories':
        return {
          'NombreCategoria': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre de Categoria',
            isRequired: true,
          ),
          'OrdenVisual': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Orden Visual',
          ),
          'Color': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'products':
        return {
          'IdCategoria': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('categories'),
            label: 'Categoria',
            isRequired: true,
          ),
          'NombreProducto': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre del Producto',
            isRequired: true,
          ),
          'descripcion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Descripcion',
          ),
          'fotoUrl': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Producto',
            storagePath: 'products/{empresaId}/{id}/{timestamp}.jpg',
          ),
          'preciounidad': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Precio Unidad',
          ),
          'precioLibra': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Precio Libra',
          ),
          'costo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Costo Compra',
          ),
          'ModoVventa': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: [
              {'value': 'UNIDAD', 'label': 'Solo Unidad'},
              {'value': 'PESO', 'label': 'Solo Peso'},
              {'value': 'AMBOS', 'label': 'Unidad y Peso'},
            ],
            label: 'Modo de Venta',
            isReadOnly: true,
          ),
          'is_promo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Producto en Promocion',
          ),
          'promo_price': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Precio Promocion Unidad',
          ),
          'promo_price_lb': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Precio Promocion Libra',
          ),
          'Activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'combos':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre del Combo',
            isRequired: true,
          ),
          'descripcion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Descripcion',
          ),
          'fotoUrl': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Combo',
            storagePath: 'combos/{empresaId}/{id}/{timestamp}.jpg',
          ),
          'precioCombo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Precio del Combo',
            isRequired: true,
          ),
          'productos_combo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('products'),
            label: 'Productos del Combo',
          ),
          'sucursales_asignadas': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('branches'),
            label: 'Sucursales Asignadas',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'clients':
        return {
          'NombreCompleto': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre Completo',
            isRequired: true,
          ),
          'RTN': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'RTN',
          ),
          'Movil': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'expense_categories':
        return {
          'name': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre',
            isRequired: true,
          ),
          'color': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color',
          ),
          'isActive': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'expenses':
        return {
          'amount': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.number,
            label: 'Monto',
            isRequired: true,
          ),
          'categoryId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () =>
                state.getDropdownOptions('expense_categories'),
            label: 'Tipo de Gasto',
            isRequired: true,
          ),
          'date': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.date,
            label: 'Fecha',
          ),
          'description': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Descripcion',
          ),
          'branchId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('branches'),
            label: 'Sucursal',
          ),
          'registeredByUserId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('users'),
            label: 'Registrado por',
          ),
          'estado': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'suppliers':
        return {
          'nombre': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre',
            isRequired: true,
          ),
          'telefono': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono',
          ),
          'email': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Email',
          ),
          'direccion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Direccion',
          ),
          'notas': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Notas',
          ),
          'esGlobal': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Proveedor Global',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'supplier_assignments':
        return {
          'proveedorId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('suppliers'),
            label: 'Proveedor',
            isRequired: true,
          ),
          'sucursalId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('branches'),
            label: 'Sucursal',
          ),
          'productoIds': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('products'),
            label: 'Productos',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      case 'companies':
        return {
          'nombreComercial': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre Comercial',
            isRequired: true,
          ),
          'razonSocial': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Razon Social',
          ),
          'rtn': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'RTN',
          ),
          'telefono': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Telefono',
          ),
          'correo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Correo',
          ),
          'direccion': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Direccion',
          ),
          'logoUrl': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Logo de la Empresa',
            storagePath: 'companies/{id}/{timestamp}.jpg',
          ),
          'activo': const DynamicFormFieldSchema(
            type: DynamicFormFieldType.boolean,
            label: 'Estado',
          ),
        };
      default:
        return {};
    }
  }

  static Map<String, dynamic> baseFields(String sectionId) {
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (sectionId) {
      case 'companies':
        return {
          'nombreComercial': '',
          'razonSocial': '',
          'rtn': '',
          'telefono': '',
          'correo': '',
          'logoUrl': '',
          'direccion': '',
          'adminId': '',
          'activo': 1,
        };
      case 'branches':
        return {
          'Nombre': '',
          'CodigoSucursal': 'SUC-$now',
          'direccion_referencia': '',
          'telefono_contacto': '',
          'empresaId': '',
          'adminId': '',
          'assigned_seller_ids': <String>[],
          'allowed_categories': <String>[],
          'control_inventario': 1,
          'clientes_enabled': 1,
          'pesos_rapidos_enabled': 0,
          'fiscal_enabled': 0,
          'sync_status': 1,
          'activo': 1,
        };
      case 'users':
        return {
          'NombreCompleto': '',
          'CodigoUsuario': '',
          'pin': '',
          'rol': 'VENDEDOR',
          'empresaId': '',
          'IdSucursal': '',
          'IdSucursalesAsignadas': <String>[],
          'selected_categories': <String>[],
          'activo': 1,
        };
      case 'clients':
        return {
          'NombreCompleto': '',
          'RTN': '',
          'Movil': '',
          'empresaId': '',
          'adminId': '',
          'activo': 1,
          'sync_status': 1,
        };
      case 'expense_categories':
        return {
          'name': '',
          'color': '0xFF2196F3',
          'empresaId': '',
          'isActive': 1,
        };
      case 'expenses':
        return {
          'categoryId': '',
          'categoryName': '',
          'description': '',
          'amount': 0.0,
          'date': DateTime.now().toIso8601String(),
          'branchId': '',
          'registeredByUserId': '',
          'empresaId': '',
          'estado': 1,
        };
      case 'categories':
        return {
          'NombreCategoria': '',
          'Color': '0xFF3498DB',
          'OrdenVisual': 0,
          'empresaId': '',
          'activo': 1,
        };
      case 'products':
        return {
          'NombreProducto': '',
          'descripcion': '',
          'fotoUrl': '',
          'preciounidad': 0.0,
          'precioLibra': 0.0,
          'ModoVventa': 'UNIDAD',
          'is_promo': 0,
          'promo_price': 0.0,
          'promo_price_lb': 0.0,
          'costo': 0.0,
          'IdCategoria': '',
          'empresaId': '',
          'Favorito': 0,
          'OrdenFavorito': 0,
          'contador_ventas': 0,
          'Activo': 1,
          'sync_status': 1,
        };
      case 'combos':
        return {
          'nombre': '',
          'descripcion': '',
          'precioCombo': 0.0,
          'fotoUrl': '',
          'productos_combo': <String>[],
          'sucursales_asignadas': <String>[],
          'empresaId': '',
          'activo': 1,
          'sync_status': 1,
        };
      case 'suppliers':
        return {
          'nombre': '',
          'telefono': '',
          'email': '',
          'direccion': '',
          'notas': '',
          'empresaId': '',
          'esGlobal': 1,
          'activo': 1,
        };
      case 'supplier_assignments':
        return {
          'proveedorId': '',
          'sucursalId': null,
          'productoIds': <String>[],
          'productos': <Map<String, dynamic>>[],
          'empresaId': '',
          'activo': 1,
        };
      case 'inventory':
      case 'inventory_transactions':
      case 'inventory_transfers':
      case 'sales':
      case 'waste_reports':
      case 'catalog_templates':
      case 'category_templates':
        return {};
      default:
        return {};
    }
  }
}
