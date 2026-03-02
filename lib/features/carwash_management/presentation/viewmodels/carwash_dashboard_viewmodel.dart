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
    bool clearError = false,
    bool clearSearch = false,
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
        lower == 'creadopor') {
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
        lower.contains('cliente') ||
        lower.contains('servicio') ||
        lower.contains('tipolavado') ||
        lower.contains('tipo_lavado') ||
        lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories') ||
        lower == 'creadopor';
  }
}

// ── ViewModel ──
class CarwashDashboardViewModel extends StateNotifier<CarwashDashboardState> {
  final CarwashRemoteDataSource _dataSource;
  bool _refsLoaded = false;

  CarwashDashboardViewModel(this._dataSource)
    : super(const CarwashDashboardState());

  /// Carga las colecciones de referencia para resolver IDs → nombres
  Future<void> _loadReferences() async {
    if (_refsLoaded) return;

    // Cargar en paralelo
    final results = await Future.wait([
      _dataSource.getCollection('empresas', limit: 1000),
      _dataSource.getCollection('sucursales', limit: 1000),
      _dataSource.getCollection('usuarios', limit: 1000),
      _dataSource.getCollection('clientes', limit: 1000),
      _dataSource.getCollection('tiposLavados', limit: 1000),
      _dataSource.getCollection('categorias', limit: 1000),
    ]);

    final empresaMap = <String, String>{};
    final sucursalMap = <String, String>{};
    final usuarioMap = <String, String>{};
    final clienteMap = <String, String>{};
    final tipoLavadoMap = <String, String>{};
    final categoriaNames = <String, String>{};

    results[0].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name =
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
            doc['nombreEmpresa']?.toString() ??
            id;
        if (id.isNotEmpty) empresaMap[id] = name;
      }
    });

    results[1].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name =
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
            doc['nombreSucursal']?.toString() ??
            id;
        if (id.isNotEmpty) sucursalMap[id] = name;
      }
    });

    results[2].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name =
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
            doc['email']?.toString() ??
            id;
        if (id.isNotEmpty) usuarioMap[id] = name;
      }
    });

    results[3].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name = doc['nombre']?.toString() ?? doc['name']?.toString() ?? id;
        if (id.isNotEmpty) clienteMap[id] = name;
      }
    });

    results[4].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name =
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
            doc['nombreServicio']?.toString() ??
            id;
        if (id.isNotEmpty) tipoLavadoMap[id] = name;
      }
    });

    if (results.length > 5) {
      results[5].fold((_) {}, (response) {
        for (final doc in response.data) {
          final id = doc['id']?.toString() ?? '';
          final name =
              doc['nombre']?.toString() ??
              doc['name']?.toString() ??
              doc['nombreCategoria']?.toString() ??
              id;
          if (id.isNotEmpty) categoriaNames[id] = name;
        }
      });
    }

    state = state.copyWith(
      empresaNames: empresaMap,
      sucursalNames: sucursalMap,
      usuarioNames: usuarioMap,
      clienteNames: clienteMap,
      tipoLavadoNames: tipoLavadoMap,
      categoriaNames: categoriaNames,
    );

    _refsLoaded = true;
  }

  /// Cambia la sección activa y carga los datos.
  Future<void> selectSection(String sectionId) async {
    final section = carwashSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => carwashSections.first,
    );

    state = state.copyWith(
      activeSection: sectionId,
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: null,
      searchValue: null,
    );

    // Cargar referencias si es la primera vez
    await _loadReferences();

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) => state = state.copyWith(
        isLoading: false,
        data: response.data,
        totalItems: response.total,
        hasMore:
            response.data.length == 20, // Si trajo 20, asumimos que hay más
      ),
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
      for (final row in state.data) {
        if (row[field] != null) {
          if (row[field] is Iterable) {
            operator = 'array-contains';
          }
          break;
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
      (response) => state = state.copyWith(
        isLoading: false,
        data: response.data,
        totalItems: response.total,
        hasMore: response.data.length == 20,
      ),
    );
  }

  /// Carga la siguiente página de datos.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
    );
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
        state = state.copyWith(
          isLoading: false,
          data: [...state.data, ...response.data],
          totalItems: response.total,
          hasMore: response.data.length == 20,
        );
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
