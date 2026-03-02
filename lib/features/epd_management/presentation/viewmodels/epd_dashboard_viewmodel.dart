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
    bool clearError = false,
    bool clearSearch = false,
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
        lower == 'creadopor' ||
        lower == 'modificadopor') {
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
        lower == 'creadopor' ||
        lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories') ||
        lower == 'modificadopor';
  }
}

// ── ViewModel ──
class EpdDashboardViewModel extends StateNotifier<EpdDashboardState> {
  final EpdRemoteDataSource _dataSource;
  bool _refsLoaded = false;

  EpdDashboardViewModel(this._dataSource) : super(const EpdDashboardState());

  /// Carga las colecciones de referencia para resolver IDs → nombres.
  Future<void> _loadReferences() async {
    if (_refsLoaded) return;

    final results = await Future.wait([
      _dataSource.getCollection('companies', limit: 1000),
      _dataSource.getCollection('branches', limit: 1000),
      _dataSource.getCollection('users', limit: 1000),
      _dataSource.getCollection('categories', limit: 1000),
    ]);

    final empresaMap = <String, String>{};
    final sucursalMap = <String, String>{};
    final usuarioMap = <String, String>{};
    final categoriaMap = <String, String>{};

    results[0].fold((_) {}, (response) {
      for (final doc in response.data) {
        final id = doc['id']?.toString() ?? '';
        final name =
            doc['nombreComercial']?.toString() ??
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
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
        final name =
            doc['NombreCategoria']?.toString() ??
            doc['nombreCategoria']?.toString() ??
            doc['nombre']?.toString() ??
            doc['name']?.toString() ??
            id;
        if (id.isNotEmpty) categoriaMap[id] = name;
      }
    });

    state = state.copyWith(
      empresaNames: empresaMap,
      sucursalNames: sucursalMap,
      usuarioNames: usuarioMap,
      categoriaNames: categoriaMap,
    );

    _refsLoaded = true;
  }

  /// Cambia la sección activa y carga los datos.
  Future<void> selectSection(String sectionId) async {
    final section = epdSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => epdSections.first,
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
        hasMore: response.data.length == 20,
      ),
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
