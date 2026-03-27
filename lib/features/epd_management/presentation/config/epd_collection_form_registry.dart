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
    'control_inventario',
    'clientes_enabled',
    'pesos_rapidos_enabled',
    'adminId',
    'IdProducto',
    'IdCombo',
    'IdInventario',
    'IdTransaccion',
    'IdVenta',
    'IdCliente',
    'IdUsuario',
    'CodigoSucursal',
    'selected_categories',
    'IdSucursalesAsignadas',
    'IdSucursal',
    'items',
  ];

  static List<String> hiddenSystemFieldsForSection(String sectionId) {
    final hidden = List<String>.from(_baseHiddenSystemFields);
    if (sectionId == 'expenses') {
      hidden.remove('estado');
    }
    return hidden;
  }

  static Map<String, DynamicFormFieldSchema> buildFieldSchemas({
    required String sectionId,
    required EpdDashboardState state,
  }) {
    switch (sectionId) {
      case 'branches':
        return {
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
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'users':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa Activa',
          ),
          'rol': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': 'VENDEDOR', 'label': 'Vendedor'},
              {'value': 'ADMIN', 'label': 'Administrador'},
            ],
            label: 'Rol',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'categories':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'Color': DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color de Categoria',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'products':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'IdCategoria': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('categories'),
            label: 'Categoria',
          ),
          'fotoUrl': DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Producto',
            storagePath: 'products/{empresaId}/{id}/{timestamp}.jpg',
          ),
          'ModoVventa': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': 'UNIDAD', 'label': 'Por Unidad'},
              {'value': 'PESO', 'label': 'Por Libra/Peso'},
              {'value': 'AMBOS', 'label': 'Ambos'},
            ],
            label: 'Modo de Venta',
            isReadOnly: true,
          ),
          'is_promo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '0', 'label': 'No es Promocion'},
              {'value': '1', 'label': 'Si es Promocion'},
            ],
            label: 'En Promocion?',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'combos':
        return {
          'nombre': DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Nombre del Combo',
          ),
          'precioCombo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.text,
            label: 'Precio del Combo',
          ),
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'productos_combo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('products'),
            label: 'Productos del Combo',
          ),
          'sucursales_asignadas': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            optionsResolver: () => state.getDropdownOptions('branches'),
            label: 'Sucursales Disponibles',
          ),
          'fotoUrl': DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Combo',
            storagePath: 'combos/{empresaId}/{id}/{timestamp}.jpg',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'clients':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'expense_categories':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'color': DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color',
          ),
          'icon': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': 'receipt_long', 'label': 'Recibo'},
              {'value': 'payments', 'label': 'Pago'},
              {'value': 'shopping_bag', 'label': 'Compra'},
              {'value': 'local_shipping', 'label': 'Logistica'},
              {'value': 'build', 'label': 'Mantenimiento'},
              {'value': 'inventory_2', 'label': 'Inventario'},
            ],
            label: 'Icono',
          ),
          'isActive': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'expenses':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'branchId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('branches'),
            label: 'Sucursal',
          ),
          'categoryId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () =>
                state.getDropdownOptions('expense_categories'),
            label: 'Tipo de Gasto',
          ),
          'registeredByUserId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('users'),
            label: 'Registrado por',
          ),
          'estado': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'suppliers':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'esGlobal': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '0', 'label': 'Proveedor Local'},
              {'value': '1', 'label': 'Proveedor Global'},
            ],
            label: 'Alcance del Proveedor',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'supplier_assignments':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'proveedorId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('suppliers'),
            label: 'Proveedor',
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
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      case 'companies':
        return {
          'logoUrl': DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Logo de la Empresa',
            storagePath: 'companies/{id}/{timestamp}.jpg',
          ),
          'activo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };
      default:
        return {};
    }
  }

  static Map<String, dynamic> baseFields(String sectionId) {
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
          'direccion_referencia': '',
          'telefono_contacto': '',
          'empresaId': '',
          'adminId': '',
          'assigned_seller_ids': <String>[],
          'allowed_categories': <String>[],
          'control_inventario': 1,
          'clientes_enabled': 1,
          'pesos_rapidos_enabled': 0,
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
          'IdSucursalesAsignadas': '[]',
          'selected_categories': '[]',
          'activo': 1,
        };
      case 'clients':
        return {
          'NombreCompleto': '',
          'RTN': '',
          'Movil': '',
          'telefono': '',
          'correo': '',
          'direccion': '',
          'empresaId': '',
          'adminId': '',
          'activo': 1,
          'sync_status': 1,
        };
      case 'expense_categories':
        return {
          'name': '',
          'color': '#EF4444',
          'icon': 'receipt_long',
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
          'descripcion': '',
          'Color': '0xFF3498DB',
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
          'sucursales_asignadas': '[]',
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
          'esGlobal': 0,
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
