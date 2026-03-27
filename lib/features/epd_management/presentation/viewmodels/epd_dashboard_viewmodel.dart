import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/network_provider.dart';
import '../../../../core/utils/resolvable_state.dart';
import '../../data/datasources/epd_remote_datasource.dart';
import '../../domain/entities/epd_section.dart';

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Estado ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
class EpdDashboardState implements ResolvableState {
  final String activeSection;
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final int totalItems;
  final String? searchField;
  final String? searchValue;
  final String? searchOperator;

  /// Mapas de resoluciÃƒÆ’Ã‚Â³n: ID ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ nombre legible
  final Map<String, String> empresaNames;
  final Map<String, String> sucursalNames;
  final Map<String, String> usuarioNames;
  final Map<String, String> categoriaNames;
  final Map<String, String> productoNames;
  final Map<String, String> proveedorNames;
  final Map<String, String> tipoGastoNames;

  /// Documentos completos cacheados para poder filtrar por empresa
  final List<Map<String, dynamic>> cachedCategories;
  final List<Map<String, dynamic>> cachedBranches;
  final List<Map<String, dynamic>> cachedUsers;
  final List<Map<String, dynamic>> cachedProducts;
  final List<Map<String, dynamic>> cachedSuppliers;
  final List<Map<String, dynamic>> cachedExpenseTypes;

  final List<Map<String, dynamic>> selectedEmpresas;

  const EpdDashboardState({
    this.activeSection = 'companies',
    this.isLoading = false,
    this.errorMessage,
    this.data = const [],
    this.hasMore = true,
    this.totalItems = 0,
    this.searchField,
    this.searchValue,
    this.searchOperator,
    this.empresaNames = const {},
    this.sucursalNames = const {},
    this.usuarioNames = const {},
    this.categoriaNames = const {},
    this.productoNames = const {},
    this.proveedorNames = const {},
    this.tipoGastoNames = const {},
    this.cachedCategories = const [],
    this.cachedBranches = const [],
    this.cachedUsers = const [],
    this.cachedProducts = const [],
    this.cachedSuppliers = const [],
    this.cachedExpenseTypes = const [],
    this.selectedEmpresas = const [],
  });

  EpdDashboardState copyWith({
    String? activeSection,
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? data,
    bool? hasMore,
    int? totalItems,
    String? searchField,
    String? searchValue,
    String? searchOperator,
    Map<String, String>? empresaNames,
    Map<String, String>? sucursalNames,
    Map<String, String>? usuarioNames,
    Map<String, String>? categoriaNames,
    Map<String, String>? productoNames,
    Map<String, String>? proveedorNames,
    Map<String, String>? tipoGastoNames,
    List<Map<String, dynamic>>? cachedCategories,
    List<Map<String, dynamic>>? cachedBranches,
    List<Map<String, dynamic>>? cachedUsers,
    List<Map<String, dynamic>>? cachedProducts,
    List<Map<String, dynamic>>? cachedSuppliers,
    List<Map<String, dynamic>>? cachedExpenseTypes,
    List<Map<String, dynamic>>? selectedEmpresas,
    bool clearError = false,
    bool clearSearch = false,
    bool clearEmpresas = false,
  }) {
    return EpdDashboardState(
      activeSection: activeSection ?? this.activeSection,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data: data ?? this.data,
      hasMore: hasMore ?? this.hasMore,
      totalItems: totalItems ?? this.totalItems,
      searchField: clearSearch ? null : (searchField ?? this.searchField),
      searchValue: clearSearch ? null : (searchValue ?? this.searchValue),
      searchOperator: clearSearch
          ? null
          : (searchOperator ?? this.searchOperator),
      empresaNames: empresaNames ?? this.empresaNames,
      sucursalNames: sucursalNames ?? this.sucursalNames,
      usuarioNames: usuarioNames ?? this.usuarioNames,
      categoriaNames: categoriaNames ?? this.categoriaNames,
      productoNames: productoNames ?? this.productoNames,
      proveedorNames: proveedorNames ?? this.proveedorNames,
      tipoGastoNames: tipoGastoNames ?? this.tipoGastoNames,
      cachedCategories: cachedCategories ?? this.cachedCategories,
      cachedBranches: cachedBranches ?? this.cachedBranches,
      cachedUsers: cachedUsers ?? this.cachedUsers,
      cachedProducts: cachedProducts ?? this.cachedProducts,
      cachedSuppliers: cachedSuppliers ?? this.cachedSuppliers,
      cachedExpenseTypes: cachedExpenseTypes ?? this.cachedExpenseTypes,
      selectedEmpresas: clearEmpresas
          ? const []
          : (selectedEmpresas ?? this.selectedEmpresas),
    );
  }

  String get activeSectionLabel {
    return epdSections
        .firstWhere(
          (s) => s.id == activeSection,
          orElse: () => epdSections.first,
        )
        .label;
  }

  static const Map<String, List<String>> _collectionIdFields = {
    'companies': ['empresaId', 'id'],
    'branches': ['IdSucursal', 'CodigoSucursal', 'id'],
    'users': ['IdUsuario', 'id'],
    'categories': ['idCategoria', 'IdCategoria', 'id'],
    'products': ['IdProducto', 'id'],
    'suppliers': ['idProveedor', 'proveedorId', 'id'],
    'expense_categories': ['id'],
    'expenses': ['id'],
    'combos': ['idCombo', 'IdCombo', 'id'],
    'supplier_assignments': ['id'],
  };

  String _extractCollectionId(String collection, Map<String, dynamic> doc) {
    final candidates = _collectionIdFields[collection] ?? const ['id'];
    for (final key in candidates) {
      final value = doc[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// Devuelve opciones para dropdowns filtradas por empresa seleccionada.
  List<Map<String, dynamic>> getDropdownOptions(String section) {
    // Soporta diferentes claves de empresa en el contexto seleccionado.
    final selectedIds = _selectedEmpresaIds();

    switch (section) {
      case 'companies':
        // Empresas no se filtran por empresa (son el nivel superior)
        final options = empresaNames.entries
            .map((e) => {'value': e.key, 'label': e.value})
            .toList();
        options.sort(
          (a, b) => a['label'].toString().compareTo(b['label'].toString()),
        );
        return options;

      case 'categories':
        // Filtrar por empresa si hay selecciÃƒÆ’Ã‚Â³n activa
        final docs = selectedIds.isEmpty
            ? cachedCategories
            : cachedCategories.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        return _docsToOptions(docs, section: 'categories');

      case 'branches':
        final docs = selectedIds.isEmpty
            ? cachedBranches
            : cachedBranches.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        return _docsToOptions(docs, section: 'branches');

      case 'users':
        final docs = selectedIds.isEmpty
            ? cachedUsers
            : cachedUsers.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        return _docsToOptions(docs, section: 'users');

      case 'products':
        final docs = selectedIds.isEmpty
            ? cachedProducts
            : cachedProducts.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        final options = docs
            .map((d) {
              final id = _extractCollectionId('products', d);
              final name = _extractDocName(d) ?? id;
              return {'value': id, 'label': name};
            })
            .where((o) => o['value']!.isNotEmpty)
            .toList();
        options.sort(
          (a, b) => a['label'].toString().compareTo(b['label'].toString()),
        );
        return options;

      case 'suppliers':
        final docs = selectedIds.isEmpty
            ? cachedSuppliers
            : cachedSuppliers.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        final options = docs
            .map((d) {
              final id = _extractCollectionId('suppliers', d);
              final name = _extractDocName(d) ?? id;
              return {'value': id, 'label': name};
            })
            .where((o) => o['value']!.isNotEmpty)
            .toList();
        options.sort(
          (a, b) => a['label'].toString().compareTo(b['label'].toString()),
        );
        return options;

      case 'expense_categories':
        final docs = selectedIds.isEmpty
            ? cachedExpenseTypes
            : cachedExpenseTypes.where((d) {
                final empId = _extractEmpresaIdFromDoc(d);
                return selectedIds.contains(empId);
              }).toList();
        return _docsToOptions(docs, section: 'expense_categories');

      default:
        return [];
    }
  }

  Set<String> _selectedEmpresaIds() {
    final ids = <String>{};
    for (final empresa in selectedEmpresas) {
      for (final key in const ['id', 'value', 'IdEmpresa', 'empresaId']) {
        final value = empresa[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) ids.add(value);
      }
    }
    return ids;
  }

  /// Convierte una lista de documentos a opciones de dropdown [{value, label}].
  List<Map<String, dynamic>> _docsToOptions(
    List<Map<String, dynamic>> docs, {
    required String section,
  }) {
    final options = docs
        .map((d) {
          final id = _extractCollectionId(section, d);
          final name = _extractDocName(d) ?? id;
          return {'value': id, 'label': name};
        })
        .where((o) => o['value']!.isNotEmpty)
        .toList();
    options.sort(
      (a, b) => a['label'].toString().compareTo(b['label'].toString()),
    );
    return options;
  }

  static String _extractEmpresaIdFromDoc(Map<String, dynamic> doc) {
    return (doc['empresaId'] ?? doc['IdEmpresa'] ?? '').toString().trim();
  }

  static String? _extractDocName(Map<String, dynamic> doc) {
    const nameFields = [
      'NombreCategoria',
      'nombreCategoria',
      'Nombrecategoria',
      'Nombre',
      'nombre',
      'name',
      'NombreTipoGasto',
      'tipoGasto',
      'categoryName',
      'NombreCompleto',
      'nombreComercial',
      'razonSocial',
      'email',
      'NombreProducto',
      'nombreProducto',
      'NombreCombo',
    ];
    for (final f in nameFields) {
      final val = doc[f];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return null;
  }

  /// Resuelve un ID a un nombre legible segÃƒÆ’Ã‚Âºn el campo.
  @override
  String resolveId(String fieldName, String rawValue) {
    final lower = fieldName.toLowerCase();
    final cleanValue = rawValue.trim();

    if (lower.contains('empresa') || lower.contains('company')) {
      return empresaNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('sucursal') || lower.contains('branch')) {
      return sucursalNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('usuario') ||
        lower.contains('user') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('modificado') ||
        lower.contains('admin')) {
      return usuarioNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('categoria') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories')) {
      return categoriaNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('producto') ||
        lower.contains('product') ||
        lower.contains('item')) {
      return productoNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('proveedor') || lower.contains('supplier')) {
      return proveedorNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('tipogasto') ||
        lower.contains('tipo_gasto') ||
        lower.contains('expense_type') ||
        lower.contains('expensetype')) {
      return tipoGastoNames[cleanValue] ?? rawValue;
    }
    return rawValue;
  }

  /// Verifica si un campo es un ID que se puede resolver.
  @override
  bool isResolvableField(String fieldName) {
    final lower = fieldName.toLowerCase();
    return lower.contains('empresa') ||
        lower.contains('company') ||
        lower.contains('sucursal') ||
        lower.contains('branch') ||
        lower.contains('usuario') ||
        lower.contains('user') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('modificado') ||
        lower.contains('admin') ||
        lower.contains('categoria') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories') ||
        lower.contains('producto') ||
        lower.contains('product') ||
        lower.contains('item') ||
        lower.contains('proveedor') ||
        lower.contains('supplier') ||
        lower.contains('tipogasto') ||
        lower.contains('tipo_gasto') ||
        lower.contains('expense_type') ||
        lower.contains('expensetype');
  }
}

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ ViewModel ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
class EpdDashboardViewModel extends StateNotifier<EpdDashboardState> {
  final EpdRemoteDataSource _dataSource;

  EpdDashboardViewModel(this._dataSource) : super(const EpdDashboardState()) {
    _loadDependencies();
  }

  /// Carga dependencias globales (empresas, sucursales, categorÃƒÆ’Ã‚Â­as) para los dropdowns.
  Future<void> _loadDependencies() async {
    final Map<String, String> newEmpresas = Map.from(state.empresaNames);
    final List<Map<String, dynamic>> newCachedBranches = [];
    final List<Map<String, dynamic>> newCachedCategories = [];
    final List<Map<String, dynamic>> newCachedUsers = [];
    final List<Map<String, dynamic>> newCachedProducts = [];
    final List<Map<String, dynamic>> newCachedSuppliers = [];
    final List<Map<String, dynamic>> newCachedExpenseTypes = [];
    final Map<String, String> newBranches = {};
    final Map<String, String> newCategories = {};
    final Map<String, String> newUsers = {};
    final Map<String, String> newProducts = {};
    final Map<String, String> newSuppliers = {};
    final Map<String, String> newExpenseTypes = {};

    await Future.wait([
      _dataSource.getCollection('companies', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('companies', doc);
            if (id.isNotEmpty) newEmpresas[id] = _extractName(doc) ?? id;
          }
        });
      }),
      _dataSource.getCollection('branches', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('branches', doc);
            if (id.isNotEmpty) {
              newBranches[id] = _extractName(doc) ?? id;
              newCachedBranches.add(doc);
            }
          }
        });
      }),
      _dataSource.getCollection('categories', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('categories', doc);
            if (id.isNotEmpty) {
              newCategories[id] = _extractName(doc) ?? id;
              newCachedCategories.add(doc);
            }
          }
        });
      }),
      _dataSource.getCollection('users', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('users', doc);
            if (id.isNotEmpty) {
              newUsers[id] = _extractName(doc) ?? id;
              newCachedUsers.add(doc);
            }
          }
        });
      }),
      _dataSource.getCollection('products', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('products', doc);
            if (id.isNotEmpty) {
              newProducts[id] = _extractName(doc) ?? id;
              newCachedProducts.add(doc);
            }
          }
        });
      }),
      _dataSource.getCollection('suppliers', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('suppliers', doc);
            if (id.isNotEmpty) {
              newSuppliers[id] = _extractName(doc) ?? id;
              newCachedSuppliers.add(doc);
            }
          }
        });
      }),
      _dataSource.getCollection('expense_categories', limit: 300).then((res) {
        res.fold((_) {}, (resp) {
          for (final doc in resp.data) {
            final id = state._extractCollectionId('expense_categories', doc);
            if (id.isNotEmpty) {
              newExpenseTypes[id] = _extractName(doc) ?? id;
              newCachedExpenseTypes.add(doc);
            }
          }
        });
      }),
    ]);

    state = state.copyWith(
      empresaNames: newEmpresas,
      sucursalNames: newBranches,
      categoriaNames: newCategories,
      usuarioNames: newUsers,
      productoNames: newProducts,
      proveedorNames: newSuppliers,
      tipoGastoNames: newExpenseTypes,
      cachedCategories: newCachedCategories,
      cachedBranches: newCachedBranches,
      cachedUsers: newCachedUsers,
      cachedProducts: newCachedProducts,
      cachedSuppliers: newCachedSuppliers,
      cachedExpenseTypes: newCachedExpenseTypes,
    );
  }

  /// Campos que contienen el nombre legible de un documento.
  static const _nameFields = [
    'NombreCategoria',
    'nombreCategoria', // Added to handle casing
    'Nombrecategoria',
    'nombre',
    'name',
    'NombreTipoGasto',
    'tipoGasto',
    'categoryName',
    'razonSocial',
    'nombreComercial',
    'NombreCompleto',
    'email',
    'NombreProducto',
    'nombreProducto',
    'NombreCombo',
  ];

  /// Extrae el nombre legible de un documento obtenido por ID.
  String? _extractName(Map<String, dynamic> doc) {
    for (final f in _nameFields) {
      final val = doc[f];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return null;
  }

  /// Detecta a quÃƒÆ’Ã‚Â© colecciÃƒÆ’Ã‚Â³n pertenece un campo basÃƒÆ’Ã‚Â¡ndose en su nombre.
  String? _detectCollection(String fieldNameLower) {
    if (fieldNameLower.contains('uid') ||
        fieldNameLower.contains('creado') ||
        fieldNameLower.contains('modificado') ||
        fieldNameLower.contains('admin') ||
        fieldNameLower.contains('usuario') ||
        fieldNameLower.contains('user')) {
      return 'users';
    }
    if (fieldNameLower.contains('empresa') ||
        fieldNameLower.contains('company')) {
      return 'companies';
    }
    if (fieldNameLower.contains('sucursal') ||
        fieldNameLower.contains('branch')) {
      return 'branches';
    }
    if (fieldNameLower.contains('categor') ||
        fieldNameLower.contains('category') ||
        fieldNameLower.contains('categories')) {
      return 'categories';
    }
    if (fieldNameLower.contains('producto') ||
        fieldNameLower.contains('product') ||
        fieldNameLower.contains('item')) {
      return 'products';
    }
    if (fieldNameLower.contains('proveedor') ||
        fieldNameLower.contains('supplier')) {
      return 'suppliers';
    }
    if (fieldNameLower.contains('tipogasto') ||
        fieldNameLower.contains('tipo_gasto') ||
        fieldNameLower.contains('expense_type') ||
        fieldNameLower.contains('expensetype')) {
      return 'expense_categories';
    }
    return null;
  }

  /// Resuelve los IDs encontrados en los datos cargados a nombres legibles.
  Future<void> _resolveIdsFromData(List<Map<String, dynamic>> data) async {
    final idsToResolve = <String, Set<String>>{};

    for (final row in data) {
      for (final entry in row.entries) {
        final lower = entry.key.toLowerCase();
        // Ignorar campos que claramente no son IDs de referencia
        if (lower == 'id' ||
            lower == 'activo' ||
            lower == 'rol' ||
            lower == 'nombre' ||
            lower == 'name' ||
            lower == 'nombrecompleto' ||
            lower.contains('fecha') ||
            lower.contains('date') ||
            lower.contains('time') ||
            lower.contains('creado_offline') ||
            lower.contains('token') ||
            lower.contains('telefono') ||
            lower.contains('direccion') ||
            lower.contains('correo') ||
            lower.contains('precio') ||
            lower.contains('cantidad') ||
            lower.contains('total') ||
            lower.contains('monto')) {
          continue;
        }

        final collection = _detectCollection(lower);
        if (collection == null) continue;

        final val = entry.value;
        if (val is String && val.isNotEmpty && val.length > 10) {
          final cached = _getCachedMap(collection);
          if (!cached.containsKey(val)) {
            idsToResolve.putIfAbsent(collection, () => {}).add(val);
          }
        } else if (val is Iterable) {
          for (final item in val) {
            final s = item?.toString() ?? '';
            if (s.isNotEmpty && s.length > 10) {
              final cached = _getCachedMap(collection);
              if (!cached.containsKey(s)) {
                idsToResolve.putIfAbsent(collection, () => {}).add(s);
              }
            }
          }
        }
      }
    }

    if (idsToResolve.isEmpty) return;

    final newEmpresa = Map<String, String>.from(state.empresaNames);
    final newSucursal = Map<String, String>.from(state.sucursalNames);
    final newUsuario = Map<String, String>.from(state.usuarioNames);
    final newCategoria = Map<String, String>.from(state.categoriaNames);
    final newProducto = Map<String, String>.from(state.productoNames);
    final newProveedor = Map<String, String>.from(state.proveedorNames);
    final newTipoGasto = Map<String, String>.from(state.tipoGastoNames);

    for (final entry in idsToResolve.entries) {
      final collection = entry.key;
      final ids = entry.value;
      final targetMap = _getTargetMap(
        collection,
        newEmpresa,
        newSucursal,
        newUsuario,
        newCategoria,
        newProducto,
        newProveedor,
        newTipoGasto,
      );

      final limitedIds = ids.take(30);
      await Future.wait(
        limitedIds.map((id) async {
          final result = await _dataSource.getDocumentById(collection, id);
          result.fold((_) {}, (doc) {
            if (doc != null) {
              final name = _extractName(doc);
              if (name != null) {
                targetMap[id] = name;
              }
            }
          });
        }),
      );
    }

    state = state.copyWith(
      empresaNames: newEmpresa,
      sucursalNames: newSucursal,
      usuarioNames: newUsuario,
      categoriaNames: newCategoria,
      productoNames: newProducto,
      proveedorNames: newProveedor,
      tipoGastoNames: newTipoGasto,
    );
  }

  Map<String, String> _getCachedMap(String collection) {
    switch (collection) {
      case 'companies':
        return state.empresaNames;
      case 'branches':
        return state.sucursalNames;
      case 'users':
        return state.usuarioNames;
      case 'categories':
        return state.categoriaNames;
      case 'products':
        return state.productoNames;
      case 'suppliers':
        return state.proveedorNames;
      case 'expense_categories':
        return state.tipoGastoNames;
      default:
        return {};
    }
  }

  Map<String, String> _getTargetMap(
    String collection,
    Map<String, String> empresa,
    Map<String, String> sucursal,
    Map<String, String> usuario,
    Map<String, String> categoria,
    Map<String, String> producto,
    Map<String, String> proveedor,
    Map<String, String> tipoGasto,
  ) {
    switch (collection) {
      case 'companies':
        return empresa;
      case 'branches':
        return sucursal;
      case 'users':
        return usuario;
      case 'categories':
        return categoria;
      case 'products':
        return producto;
      case 'suppliers':
        return proveedor;
      case 'expense_categories':
        return tipoGasto;
      default:
        return {};
    }
  }

  /// Toggle de empresa para multiselecciÃƒÆ’Ã‚Â³n.
  void selectEmpresaContext(Map<String, dynamic> empresa) {
    final current = List<Map<String, dynamic>>.from(state.selectedEmpresas);
    final id = empresa['id']?.toString();
    final idx = current.indexWhere((e) => e['id']?.toString() == id);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(empresa);
    }
    state = state.copyWith(selectedEmpresas: current, clearError: true);
  }

  /// Limpia todas las empresas seleccionadas.
  void clearEmpresaContext() {
    state = state.copyWith(clearEmpresas: true, clearError: true);
  }

  String? _getEmpresaContextParam(String sectionId) {
    if (sectionId == 'companies') return null;

    final ids = state._selectedEmpresaIds().toList();
    if (ids.isEmpty) return null;
    return ids.join(',');
  }

  String? _inferOperator({
    required String? field,
    required String? value,
    required String? explicitOperator,
  }) {
    if (explicitOperator != null && explicitOperator.trim().isNotEmpty) {
      return explicitOperator.trim();
    }
    if (field == null || field.isEmpty || value == null || value.isEmpty) {
      return null;
    }
    for (final row in state.data) {
      if (row[field] != null) {
        if (row[field] is Iterable) {
          return 'array-contains';
        }
        break;
      }
    }
    return '==';
  }

  /// Cambia la secciÃ³n activa y carga los datos.
  Future<void> selectSection(String sectionId) async {
    final section = epdSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => epdSections.first,
    );

    final keepExistingSearch = sectionId == state.activeSection;
    final currentField = keepExistingSearch ? state.searchField : null;
    final currentValue = keepExistingSearch ? state.searchValue : null;
    final currentOperator = keepExistingSearch ? state.searchOperator : null;

    if (sectionId != 'companies' && state.selectedEmpresas.isEmpty) {
      state = state.copyWith(
        activeSection: sectionId,
        isLoading: false,
        clearError: true,
        data: [],
        hasMore: false,
        errorMessage:
            'Debes seleccionar una empresa en la pestana Empresas para ver esta informacion.',
      );
      return;
    }

    final empresaIds = _getEmpresaContextParam(sectionId);

    state = state.copyWith(
      activeSection: sectionId,
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: currentField,
      searchValue: currentValue,
      searchOperator: currentOperator,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: currentField,
      searchValue: currentValue,
      searchOperator: currentOperator,
      empresaIds: empresaIds,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) async {
        state = state.copyWith(
          isLoading: false,
          data: response.data,
          totalItems: response.total,
          hasMore: response.data.length == 20,
        );
        await _resolveIdsFromData(response.data);
      },
    );
  }

  /// Aplica filtros en el servidor restando a la primera pÃ¡gina.
  Future<void> applyFilter(
    String? field,
    String? value, {
    String? operatorOverride,
  }) async {
    final section = epdSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => epdSections.first,
    );

    final normalizedValue = value?.trim();
    final effectiveValue = (normalizedValue == null || normalizedValue.isEmpty)
        ? null
        : normalizedValue;
    final effectiveField = effectiveValue == null ? null : field;
    final operator = _inferOperator(
      field: effectiveField,
      value: effectiveValue,
      explicitOperator: operatorOverride,
    );
    final empresaIds = _getEmpresaContextParam(state.activeSection);

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: effectiveField,
      searchValue: effectiveValue,
      searchOperator: operator,
      clearSearch: effectiveField == null,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: effectiveField,
      searchValue: effectiveValue,
      searchOperator: operator,
      empresaIds: empresaIds,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) async {
        state = state.copyWith(
          isLoading: false,
          data: response.data,
          totalItems: response.total,
          hasMore: response.data.length == 20,
        );
        await _resolveIdsFromData(response.data);
      },
    );
  }

  /// Carga la siguiente pÃ¡gina de datos de la API.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final section = epdSections.firstWhere((s) => s.id == state.activeSection);
    final lastDocId = state.data.last['id']?.toString();
    final empresaIds = _getEmpresaContextParam(state.activeSection);

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      ultimoDocId: lastDocId,
      searchField: state.searchField,
      searchValue: state.searchValue,
      searchOperator: state.searchOperator,
      empresaIds: empresaIds,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) {
        final newData = [...state.data, ...response.data];
        state = state.copyWith(
          isLoading: false,
          data: newData,
          totalItems: response.total,
          hasMore: response.data.length == 20,
        );
        _resolveIdsFromData(response.data);
      },
    );
  }

  bool _affectsDependencyCaches(String collection) {
    const dependencyCollections = {
      'companies',
      'branches',
      'categories',
      'users',
      'products',
      'suppliers',
      'expense_categories',
    };
    return dependencyCollections.contains(collection);
  }

  Future<void> _refreshDependenciesIfNeeded(String collection) async {
    if (_affectsDependencyCaches(collection)) {
      await _loadDependencies();
    }
  }

  List<String> _parseStringList(dynamic rawValue) {
    final result = <String>[];
    void addValue(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !result.contains(text)) {
        result.add(text);
      }
    }

    if (rawValue == null) return result;

    if (rawValue is String) {
      final raw = rawValue.trim();
      if (raw.isEmpty) return result;
      if (raw.startsWith('[') && raw.endsWith(']')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Iterable) {
            for (final item in decoded) {
              addValue(item);
            }
            return result;
          }
        } catch (_) {}
      }
      addValue(raw);
      return result;
    }

    if (rawValue is Iterable) {
      for (final item in rawValue) {
        addValue(item);
      }
      return result;
    }

    addValue(rawValue);
    return result;
  }

  /// Crea un nuevo documento y devuelve error + id creado.
  Future<({String? error, String? id})> createItemWithId(
    Map<String, dynamic> data,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = epdSections.firstWhere((s) => s.id == state.activeSection);

    final result = await _dataSource.createDocument(section.collection, data);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return (error: failure.message, id: null);
      },
      (response) async {
        final createdId = response['id']?.toString();
        await _refreshDependenciesIfNeeded(section.collection);
        // Recargar datos tras el ÃƒÆ’Ã‚Â©xito
        await selectSection(state.activeSection);
        return (error: null, id: createdId);
      },
    );
  }

  /// Crea un nuevo documento en la colecciÃƒÆ’Ã‚Â³n activa actual.
  Future<String?> createItem(Map<String, dynamic> data) async {
    final result = await createItemWithId(data);
    return result.error;
  }

  /// Actualiza un documento existente en la colecciÃƒÆ’Ã‚Â³n activa actual por ID.
  Future<String?> updateItem(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = epdSections.firstWhere((s) => s.id == state.activeSection);

    final result = await _dataSource.updateDocument(
      section.collection,
      id,
      data,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message;
      },
      (_) async {
        await _refreshDependenciesIfNeeded(section.collection);
        await selectSection(state.activeSection);
        return null;
      },
    );
  }

  /// Sincroniza la relaciÃƒÂ³n sucursal-vendedores en la colecciÃƒÂ³n `users`.
  /// La fuente de verdad es `users.IdSucursalesAsignadas`.
  Future<String?> syncBranchSellerAssignments({
    required String branchId,
    required List<String> sellerIds,
    String? empresaId,
  }) async {
    final trimmedBranchId = branchId.trim();
    if (trimmedBranchId.isEmpty) return 'No se pudo identificar la sucursal.';

    final targetSellers = sellerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final usersInScope = state.cachedUsers.where((u) {
      final userId = u['id']?.toString().trim() ?? '';
      if (userId.isEmpty) return false;
      if (empresaId == null || empresaId.trim().isEmpty) return true;
      final userEmpresa = u['empresaId']?.toString().trim() ?? '';
      return userEmpresa == empresaId.trim();
    }).toList();

    String? firstError;

    for (final user in usersInScope) {
      final userId = user['id']?.toString().trim() ?? '';
      if (userId.isEmpty) continue;

      final currentAssignments = _parseStringList(
        user['IdSucursalesAsignadas'],
      );
      final updatedAssignments = List<String>.from(currentAssignments);

      final shouldContain = targetSellers.contains(userId);
      final alreadyContains = updatedAssignments.contains(trimmedBranchId);

      if (shouldContain && !alreadyContains) {
        updatedAssignments.add(trimmedBranchId);
      } else if (!shouldContain && alreadyContains) {
        updatedAssignments.removeWhere((id) => id == trimmedBranchId);
      } else {
        continue;
      }

      final updateResult = await _dataSource.updateDocument('users', userId, {
        'IdSucursalesAsignadas': updatedAssignments,
        'IdSucursal': updatedAssignments.isNotEmpty
            ? updatedAssignments.first
            : '',
      });

      updateResult.fold((failure) {
        firstError ??= failure.message;
      }, (_) {});
    }

    if (firstError != null) {
      state = state.copyWith(errorMessage: firstError, isLoading: false);
      return firstError;
    }

    await _refreshDependenciesIfNeeded('users');
    return null;
  }

  /// Elimina un documento existente en la colecciÃƒÆ’Ã‚Â³n activa actual por ID.
  Future<String?> deleteItem(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = epdSections.firstWhere((s) => s.id == state.activeSection);

    final result = await _dataSource.deleteDocument(section.collection, id);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message;
      },
      (_) async {
        await _refreshDependenciesIfNeeded(section.collection);
        await selectSection(state.activeSection);
        return null;
      },
    );
  }

  /// Realiza un ajuste atÃƒÆ’Ã‚Â³mico de inventario usando el endpoint /inventario-ajuste.
  /// El [data] debe contener los campos requeridos por el endpoint:
  /// IdProducto, IdSucursal, IdEmpresa, cantidad, motivo, [observacion].
  Future<String?> adjustInventory(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _dataSource.adjustInventory(data);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message;
      },
      (_) async {
        // Recargar inventory e inventory_transactions tras el ajuste
        await selectSection(state.activeSection);
        return null;
      },
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Providers ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
final epdDataSourceProvider = Provider<EpdRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return EpdRemoteDataSource(dioClient);
});

final epdDashboardProvider =
    StateNotifierProvider<EpdDashboardViewModel, EpdDashboardState>((ref) {
      final dataSource = ref.watch(epdDataSourceProvider);
      return EpdDashboardViewModel(dataSource);
    });
