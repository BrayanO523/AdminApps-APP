import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/network_provider.dart';
import '../../../../core/utils/resolvable_state.dart';
import '../../data/datasources/carwash_remote_datasource.dart';
import '../../domain/entities/carwash_section.dart';

// ── Estado ──
class CarwashDashboardState implements ResolvableState {
  final String activeSection;
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final int totalItems;
  final String? searchField;
  final String? searchValue;

  /// Mapas de resolución: ID → nombre legible
  final Map<String, String> empresaNames; // empresaId → nombre
  final Map<String, String> sucursalNames; // sucursalId → nombre
  final Map<String, String> usuarioNames; // userId → nombre/email
  final Map<String, String> clienteNames; // clienteId → nombre
  final Map<String, String> tipoLavadoNames; // tipoLavadoId → nombre
  final Map<String, String> categoriaNames; // categoriaId → nombre

  final List<Map<String, dynamic>> selectedEmpresas;

  const CarwashDashboardState({
    this.activeSection = 'empresas',
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
    this.clienteNames = const {},
    this.tipoLavadoNames = const {},
    this.categoriaNames = const {},
    this.selectedEmpresas = const [],
  });

  CarwashDashboardState copyWith({
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
    Map<String, String>? clienteNames,
    Map<String, String>? tipoLavadoNames,
    Map<String, String>? categoriaNames,
    List<Map<String, dynamic>>? selectedEmpresas,
    bool clearError = false,
    bool clearSearch = false,
    bool clearEmpresas = false,
  }) {
    return CarwashDashboardState(
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
      clienteNames: clienteNames ?? this.clienteNames,
      tipoLavadoNames: tipoLavadoNames ?? this.tipoLavadoNames,
      categoriaNames: categoriaNames ?? this.categoriaNames,
      selectedEmpresas: clearEmpresas
          ? const []
          : (selectedEmpresas ?? this.selectedEmpresas),
    );
  }

  String get activeSectionLabel {
    return carwashSections
        .firstWhere(
          (s) => s.id == activeSection,
          orElse: () => carwashSections.first,
        )
        .label;
  }

  /// Resuelve un ID a un nombre legible según el campo.
  @override
  String resolveId(String fieldName, String rawValue) {
    final lower = fieldName.toLowerCase();
    if (lower.contains('empresa')) {
      return empresaNames[rawValue] ?? rawValue;
    }
    if (lower.contains('sucursal')) {
      return sucursalNames[rawValue] ?? rawValue;
    }
    if (lower.contains('usuario') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('creado_por') ||
        lower.contains('modificado') ||
        lower.contains('modificadopor') ||
        lower.contains('admin') ||
        lower.contains('adminid')) {
      return usuarioNames[rawValue] ?? rawValue;
    }
    if (lower.contains('cliente')) {
      return clienteNames[rawValue] ?? rawValue;
    }
    if (lower.contains('servicio') ||
        lower.contains('tipolavado') ||
        lower.contains('tipo_lavado')) {
      return tipoLavadoNames[rawValue] ?? rawValue;
    }
    if (lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories')) {
      return categoriaNames[rawValue] ?? rawValue;
    }
    return rawValue;
  }

  /// Verifica si un campo es un ID que se puede resolver.
  @override
  bool isResolvableField(String fieldName) {
    final lower = fieldName.toLowerCase();
    return lower.contains('empresa') ||
        lower.contains('sucursal') ||
        lower.contains('usuario') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('modificado') ||
        lower.contains('admin') ||
        lower.contains('cliente') ||
        lower.contains('servicio') ||
        lower.contains('tipolavado') ||
        lower.contains('tipo_lavado') ||
        lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories');
  }
}

// ── ViewModel ──
class CarwashDashboardViewModel extends StateNotifier<CarwashDashboardState> {
  final CarwashRemoteDataSource _dataSource;

  CarwashDashboardViewModel(this._dataSource)
    : super(const CarwashDashboardState());

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
    // Usuarios: uid, creadoPor, creado_por, adminId, modificadoPor, IdUsuario
    if (fieldNameLower.contains('uid') ||
        fieldNameLower.contains('creado') ||
        fieldNameLower.contains('modificado') ||
        fieldNameLower.contains('admin') ||
        fieldNameLower.contains('usuario')) {
      return 'usuarios';
    }
    // Empresas
    if (fieldNameLower.contains('empresa')) return 'empresas';
    // Sucursales
    if (fieldNameLower.contains('sucursal')) return 'sucursales';
    // Clientes
    if (fieldNameLower.contains('cliente')) return 'clientes';
    // Tipos de lavado
    if (fieldNameLower.contains('tipolavado') ||
        fieldNameLower.contains('tipo_lavado') ||
        fieldNameLower.contains('servicio')) {
      return 'tiposLavados';
    }
    // Categorías
    if (fieldNameLower.contains('categor') ||
        fieldNameLower.contains('category') ||
        fieldNameLower.contains('categories')) {
      return 'categorias';
    }
    return null;
  }

  /// Resuelve los IDs encontrados en los datos cargados a nombres legibles.
  /// Solo busca IDs que aún no estén en caché para minimizar lecturas.
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
          // Parece un ID (UUID o similar)
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

    // Fetch cada ID individualmente y guardar en el mapa correspondiente
    final newEmpresa = Map<String, String>.from(state.empresaNames);
    final newSucursal = Map<String, String>.from(state.sucursalNames);
    final newUsuario = Map<String, String>.from(state.usuarioNames);
    final newCliente = Map<String, String>.from(state.clienteNames);
    final newTipoLavado = Map<String, String>.from(state.tipoLavadoNames);
    final newCategoria = Map<String, String>.from(state.categoriaNames);

    for (final entry in idsToResolve.entries) {
      final collection = entry.key;
      final ids = entry.value;
      final targetMap = _getTargetMap(
        collection,
        newEmpresa,
        newSucursal,
        newUsuario,
        newCliente,
        newTipoLavado,
        newCategoria,
      );

      // Limitar a 30 IDs para no saturar la API
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
      clienteNames: newCliente,
      tipoLavadoNames: newTipoLavado,
      categoriaNames: newCategoria,
    );
  }

  Map<String, String> _getCachedMap(String collection) {
    switch (collection) {
      case 'empresas':
        return state.empresaNames;
      case 'sucursales':
        return state.sucursalNames;
      case 'usuarios':
        return state.usuarioNames;
      case 'clientes':
        return state.clienteNames;
      case 'tiposLavados':
        return state.tipoLavadoNames;
      case 'categorias':
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
    Map<String, String> cliente,
    Map<String, String> tipoLavado,
    Map<String, String> categoria,
  ) {
    switch (collection) {
      case 'empresas':
        return empresa;
      case 'sucursales':
        return sucursal;
      case 'usuarios':
        return usuario;
      case 'clientes':
        return cliente;
      case 'tiposLavados':
        return tipoLavado;
      case 'categorias':
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
    final section = carwashSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => carwashSections.first,
    );

    String? currentField = state.searchField;
    String? currentValue = state.searchValue;

    // Si no estamos en la sección de empresas, requerimos al menos una empresa seleccionada.
    if (sectionId != 'empresas' && state.selectedEmpresas.isEmpty) {
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

    // Si hay empresas seleccionadas, forzamos el filtro de empresa_id
    if (state.selectedEmpresas.isNotEmpty && sectionId != 'empresas') {
      currentField = 'empresa_id';
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
    if (state.selectedEmpresas.length > 1 && sectionId != 'empresas') {
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
      // Actualizamos el filtro activo al de la empresa (si aplica)
      searchField: currentField,
      searchValue: currentValue,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: currentField,
      searchValue: currentValue,
      searchOperator: operator,
      empresaId: _getEmpresaIdsStr(state),
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) async {
        if (response.data.isNotEmpty) {
          print('DEBUG CARWASH PAYLOAD: ${response.data.first}');
        }
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
    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => carwashSections.first,
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
      empresaId: _getEmpresaIdsStr(state),
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

  /// Carga la siguiente página de datos.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      ultimoDocId: state.data.last['id'],
      searchField: state.searchField,
      searchValue: state.searchValue,
      searchOperator: state.searchField != null
          ? (state.searchValue?.contains(',') ?? false ? 'in' : null)
          : null,
      empresaId: _getEmpresaIdsStr(state),
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
    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
    );

    final result = await _dataSource.createDocument(section.collection, data);
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

  /// Actualiza un documento existente en la colección activa actual por ID.
  Future<String?> updateItem(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
    );

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
    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
    );

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

  String? _getEmpresaIdsStr(CarwashDashboardState currentState) {
    if (currentState.selectedEmpresas.isEmpty) return null;
    if (currentState.activeSection == 'empresas') return null;
    return currentState.selectedEmpresas
        .map((e) => e['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .join(',');
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Providers ──
final carwashDataSourceProvider = Provider<CarwashRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return CarwashRemoteDataSource(dioClient);
});

final carwashDashboardProvider =
    StateNotifierProvider<CarwashDashboardViewModel, CarwashDashboardState>((
      ref,
    ) {
      final dataSource = ref.watch(carwashDataSourceProvider);
      return CarwashDashboardViewModel(dataSource);
    });
