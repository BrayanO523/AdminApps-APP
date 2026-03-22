import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/network_provider.dart';
import '../../../../core/utils/resolvable_state.dart';
import '../../data/datasources/epd_remote_datasource.dart';
import '../../domain/entities/epd_section.dart';

// ── Estado ──
class EpdDashboardState implements ResolvableState {
  final String activeSection;
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final int totalItems;
  final String? searchField;
  final String? searchValue;

  /// Mapas de resolución: ID → nombre legible
  final Map<String, String> empresaNames;
  final Map<String, String> sucursalNames;
  final Map<String, String> usuarioNames;
  final Map<String, String> categoriaNames;

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
    this.empresaNames = const {},
    this.sucursalNames = const {},
    this.usuarioNames = const {},
    this.categoriaNames = const {},
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
    Map<String, String>? empresaNames,
    Map<String, String>? sucursalNames,
    Map<String, String>? usuarioNames,
    Map<String, String>? categoriaNames,
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
      empresaNames: empresaNames ?? this.empresaNames,
      sucursalNames: sucursalNames ?? this.sucursalNames,
      usuarioNames: usuarioNames ?? this.usuarioNames,
      categoriaNames: categoriaNames ?? this.categoriaNames,
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

  /// Devuelve una lista de opciones formateadas para Dropdowns `[{'value': ID, 'label': Nombre}]`
  List<Map<String, dynamic>> getDropdownOptions(String section) {
    Map<String, String> targetMap;
    switch (section) {
      case 'companies':
        targetMap = empresaNames;
        break;
      case 'branches':
        targetMap = sucursalNames;
        break;
      case 'users':
        targetMap = usuarioNames;
        break;
      case 'categories':
        targetMap = categoriaNames;
        break;
      default:
        return [];
    }
    final options = targetMap.entries
        .map((e) => {'value': e.key, 'label': e.value})
        .toList();
    options.sort((a, b) => a['label'].toString().compareTo(b['label'].toString()));
    return options;
  }

  /// Resuelve un ID a un nombre legible según el campo.
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
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('categoríes') ||
        lower.contains('category') ||
        lower.contains('categories')) {
      return categoriaNames[cleanValue] ?? rawValue;
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
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories');
  }
}

// ── ViewModel ──
class EpdDashboardViewModel extends StateNotifier<EpdDashboardState> {
  final EpdRemoteDataSource _dataSource;

  EpdDashboardViewModel(this._dataSource) : super(const EpdDashboardState());

  /// Campos que contienen el nombre legible de un documento.
  static const _nameFields = [
    'NombreCategoria',
    'nombre',
    'name',
    'razonSocial',
    'nombreComercial',
    'NombreCompleto',
    'email',
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

  /// Detecta a qué colección pertenece un campo basándose en su nombre.
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

    for (final entry in idsToResolve.entries) {
      final collection = entry.key;
      final ids = entry.value;
      final targetMap = _getTargetMap(
        collection,
        newEmpresa,
        newSucursal,
        newUsuario,
        newCategoria,
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
      default:
        return {};
    }
  }

  /// Toggle de empresa para multiselección.
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

  /// Cambia la sección activa y carga los datos.
  Future<void> selectSection(String sectionId) async {
    final section = epdSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => epdSections.first,
    );

    String? currentField = state.searchField;
    String? currentValue = state.searchValue;

    if (sectionId != 'companies' && state.selectedEmpresas.isEmpty) {
      state = state.copyWith(
        activeSection: sectionId,
        isLoading: false,
        clearError: true,
        data: [],
        hasMore: false,
        errorMessage:
            'Debes seleccionar una empresa en la pestaña Empresas para ver esta información.',
      );
      return;
    }

    if (state.selectedEmpresas.isNotEmpty && sectionId != 'companies') {
      currentField = 'empresaId';
      if (state.selectedEmpresas.length == 1) {
        currentValue = state.selectedEmpresas.first['id']?.toString();
      } else {
        currentValue = state.selectedEmpresas
            .map((e) => e['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .join(',');
      }
    }

    String? operator;
    // Forzar operador 'in' para múltiples empresas
    if (state.selectedEmpresas.length > 1 && sectionId != 'companies') {
      operator = 'in';
    } else if (currentField != null) {
      for (final row in state.data) {
        if (row[currentField] != null) {
          if (row[currentField] is Iterable) {
            operator = 'array-contains';
          }
          break;
        }
      }
    }

    state = state.copyWith(
      activeSection: sectionId,
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: currentField,
      searchValue: currentValue,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: currentField,
      searchValue: currentValue,
      searchOperator: operator,
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

  /// Aplica filtros en el servidor restando a la primera página.
  Future<void> applyFilter(String? field, String? value) async {
    final section = epdSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => epdSections.first,
    );

    String? operator;
    if (field != null) {
      if (value != null && value.contains(',')) {
        operator = 'in';
      } else {
        for (final row in state.data) {
          if (row[field] != null) {
            if (row[field] is Iterable) {
              operator = 'array-contains';
            }
            break;
          }
        }
      }
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: field,
      searchValue: value,
      clearSearch: field == null,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: field,
      searchValue: value,
      searchOperator: operator,
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

  /// Carga la siguiente página de datos de la API.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final section = epdSections.firstWhere((s) => s.id == state.activeSection);
    final lastDocId = state.data.last['id']?.toString();

    String? operator;
    if (state.searchField != null) {
      for (final row in state.data) {
        if (row[state.searchField!] != null) {
          if (row[state.searchField!] is Iterable) {
            operator = 'array-contains';
          }
          break;
        }
      }
    }

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      ultimoDocId: lastDocId,
      searchField: state.searchField,
      searchValue: state.searchValue,
      searchOperator: operator,
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

  /// Crea un nuevo documento en la colección activa actual.
  Future<String?> createItem(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = epdSections.firstWhere((s) => s.id == state.activeSection);

    final result = await _dataSource.createDocument(section.collection, data);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message; // Devuelve error para mostrar en UI
      },
      (_) async {
        // Recargar datos tras el éxito
        await selectSection(state.activeSection);
        return null; // Null significa éxito
      },
    );
  }

  /// Actualiza un documento existente en la colección activa actual por ID.
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
        await selectSection(state.activeSection);
        return null;
      },
    );
  }

  /// Elimina un documento existente en la colección activa actual por ID.
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
        await selectSection(state.activeSection);
        return null;
      },
    );
  }

  /// Realiza un ajuste atómico de inventario usando el endpoint /inventario-ajuste.
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

// ── Providers ──
final epdDataSourceProvider = Provider<EpdRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return EpdRemoteDataSource(dioClient);
});

final epdDashboardProvider =
    StateNotifierProvider<EpdDashboardViewModel, EpdDashboardState>((ref) {
      final dataSource = ref.watch(epdDataSourceProvider);
      return EpdDashboardViewModel(dataSource);
    });
