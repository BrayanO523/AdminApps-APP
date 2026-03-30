import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/network_provider.dart';
import '../../../../core/utils/resolvable_state.dart';
import '../../data/datasources/qrecauda_remote_datasource.dart';
import '../../domain/entities/qrecauda_section.dart';
import '../../domain/services/qrecauda_collection_save_rules.dart';

// ── Estado ──
class QRecaudaDashboardState implements ResolvableState {
  final String activeSection;
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final int totalItems;
  final String? searchField;
  final String? searchValue;

  /// Mapas de resolución: ID → nombre legible
  final Map<String, String> municipalidadNames;
  final Map<String, String> mercadoNames;
  final Map<String, String> usuarioNames;

  final List<Map<String, dynamic>> selectedMunicipalidades;

  const QRecaudaDashboardState({
    this.activeSection = 'municipalidades',
    this.isLoading = false,
    this.errorMessage,
    this.data = const [],
    this.hasMore = true,
    this.totalItems = 0,
    this.searchField,
    this.searchValue,
    this.municipalidadNames = const {},
    this.mercadoNames = const {},
    this.usuarioNames = const {},
    this.selectedMunicipalidades = const [],
  });

  QRecaudaDashboardState copyWith({
    String? activeSection,
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? data,
    bool? hasMore,
    int? totalItems,
    String? searchField,
    String? searchValue,
    Map<String, String>? municipalidadNames,
    Map<String, String>? mercadoNames,
    Map<String, String>? usuarioNames,
    List<Map<String, dynamic>>? selectedMunicipalidades,
    bool clearError = false,
    bool clearSearch = false,
    bool clearMunicipalidades = false,
  }) {
    return QRecaudaDashboardState(
      activeSection: activeSection ?? this.activeSection,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data: data ?? this.data,
      hasMore: hasMore ?? this.hasMore,
      totalItems: totalItems ?? this.totalItems,
      searchField: clearSearch ? null : (searchField ?? this.searchField),
      searchValue: clearSearch ? null : (searchValue ?? this.searchValue),
      municipalidadNames: municipalidadNames ?? this.municipalidadNames,
      mercadoNames: mercadoNames ?? this.mercadoNames,
      usuarioNames: usuarioNames ?? this.usuarioNames,
      selectedMunicipalidades: clearMunicipalidades
          ? const []
          : (selectedMunicipalidades ?? this.selectedMunicipalidades),
    );
  }

  String get activeSectionLabel {
    return qrecaudaSections
        .firstWhere(
          (s) => s.id == activeSection,
          orElse: () => qrecaudaSections.first,
        )
        .label;
  }

  @override
  String resolveId(String fieldName, String rawValue) {
    final lower = fieldName.toLowerCase();
    final cleanValue = rawValue.trim();

    if (lower.contains('municipalidad') || lower.contains('municipality')) {
      return municipalidadNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('mercado') || lower.contains('market')) {
      return mercadoNames[cleanValue] ?? rawValue;
    }
    if (lower.contains('usuario') ||
        lower.contains('user') ||
        lower.contains('uid') ||
        lower.contains('cobrador')) {
      return usuarioNames[cleanValue] ?? rawValue;
    }
    return rawValue;
  }

  @override
  bool isResolvableField(String fieldName) {
    final lower = fieldName.toLowerCase();
    return lower.contains('municipalidad') ||
        lower.contains('municipality') ||
        lower.contains('mercado') ||
        lower.contains('market') ||
        lower.contains('usuario') ||
        lower.contains('user') ||
        lower.contains('uid') ||
        lower.contains('cobrador');
  }
}

// ── ViewModel ──
class QRecaudaDashboardViewModel extends StateNotifier<QRecaudaDashboardState> {
  final QRecaudaRemoteDataSource _dataSource;

  QRecaudaDashboardViewModel(this._dataSource)
    : super(const QRecaudaDashboardState());

  static const _nameFields = [
    'nombre',
    'name',
    'razonSocial',
    'nombreComercial',
    'NombreCompleto',
    'email',
    'descripcion',
  ];

  String? _extractName(Map<String, dynamic> doc) {
    for (final f in _nameFields) {
      final val = doc[f];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return null;
  }

  String? _detectCollection(String fieldNameLower) {
    if (fieldNameLower.contains('municipalidad') ||
        fieldNameLower.contains('municipality')) {
      return 'municipalidades';
    }
    if (fieldNameLower.contains('mercado') ||
        fieldNameLower.contains('market')) {
      return 'mercados';
    }
    if (fieldNameLower.contains('usuario') ||
        fieldNameLower.contains('user') ||
        fieldNameLower.contains('uid') ||
        fieldNameLower.contains('cobrador')) {
      return 'usuarios';
    }
    return null;
  }

  Future<void> _resolveIdsFromData(List<Map<String, dynamic>> data) async {
    final idsToResolve = <String, Set<String>>{};

    for (final row in data) {
      for (final entry in row.entries) {
        final lower = entry.key.toLowerCase();
        if (lower == 'id' ||
            lower == 'activo' ||
            lower == 'rol' ||
            lower == 'nombre' ||
            lower == 'name' ||
            lower.contains('fecha') ||
            lower.contains('date') ||
            lower.contains('token') ||
            lower.contains('telefono') ||
            lower.contains('direccion') ||
            lower.contains('correo') ||
            lower.contains('monto') ||
            lower.contains('precio') ||
            lower.contains('total')) {
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
        }
      }
    }

    if (idsToResolve.isEmpty) return;

    final newMunicipalidad = Map<String, String>.from(state.municipalidadNames);
    final newMercado = Map<String, String>.from(state.mercadoNames);
    final newUsuario = Map<String, String>.from(state.usuarioNames);

    for (final entry in idsToResolve.entries) {
      final collection = entry.key;
      final ids = entry.value;
      final targetMap = _getTargetMap(
        collection,
        newMunicipalidad,
        newMercado,
        newUsuario,
      );
      final limitedIds = ids.take(30);
      await Future.wait(
        limitedIds.map((id) async {
          final result = await _dataSource.getDocumentById(collection, id);
          result.fold((_) {}, (doc) {
            if (doc != null) {
              final name = _extractName(doc);
              if (name != null) targetMap[id] = name;
            }
          });
        }),
      );
    }

    state = state.copyWith(
      municipalidadNames: newMunicipalidad,
      mercadoNames: newMercado,
      usuarioNames: newUsuario,
    );
  }

  Map<String, String> _getCachedMap(String collection) {
    switch (collection) {
      case 'municipalidades':
        return state.municipalidadNames;
      case 'mercados':
        return state.mercadoNames;
      case 'usuarios':
        return state.usuarioNames;
      default:
        return {};
    }
  }

  Map<String, String> _getTargetMap(
    String collection,
    Map<String, String> municipalidad,
    Map<String, String> mercado,
    Map<String, String> usuario,
  ) {
    switch (collection) {
      case 'municipalidades':
        return municipalidad;
      case 'mercados':
        return mercado;
      case 'usuarios':
        return usuario;
      default:
        return {};
    }
  }

  String? _contextMunicipalidadIdForSection(String sectionId) {
    if (sectionId == 'municipalidades') return null;
    if (state.selectedMunicipalidades.length != 1) return null;
    final contextId =
        state.selectedMunicipalidades.first['id']?.toString().trim() ?? '';
    return contextId.isEmpty ? null : contextId;
  }

  ({String? searchField, String? searchValue, String? searchOperator})
  _resolveEffectiveQuery({
    required String sectionId,
    String? requestedField,
    String? requestedValue,
    String? requestedOperator,
  }) {
    final contextMunicipalidadId = _contextMunicipalidadIdForSection(sectionId);
    if (contextMunicipalidadId == null) {
      return (
        searchField: requestedField,
        searchValue: requestedValue,
        searchOperator: requestedOperator,
      );
    }

    // Regla administrativa: cuando hay exactamente 1 municipalidad de contexto,
    // la consulta de secciones dependientes siempre queda restringida por ella.
    return (
      searchField: 'municipalidadId',
      searchValue: contextMunicipalidadId,
      searchOperator: '==',
    );
  }

  void selectMunicipalidadContext(Map<String, dynamic> municipalidad) {
    final current = List<Map<String, dynamic>>.from(
      state.selectedMunicipalidades,
    );
    final id = municipalidad['id']?.toString();
    final idx = current.indexWhere((e) => e['id']?.toString() == id);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(municipalidad);
    }
    state = state.copyWith(selectedMunicipalidades: current, clearError: true);
    if (state.activeSection != 'municipalidades') {
      // ignore: discarded_futures
      selectSection(state.activeSection);
    }
  }

  void clearMunicipalidadContext() {
    state = state.copyWith(clearMunicipalidades: true, clearError: true);
    if (state.activeSection != 'municipalidades') {
      // ignore: discarded_futures
      selectSection(state.activeSection);
    }
  }

  Future<void> selectSection(String sectionId) async {
    final section = qrecaudaSections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => qrecaudaSections.first,
    );
    final effectiveQuery = _resolveEffectiveQuery(sectionId: section.id);

    state = state.copyWith(
      activeSection: sectionId,
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: effectiveQuery.searchField,
      searchValue: effectiveQuery.searchValue,
      clearSearch: effectiveQuery.searchField == null,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: effectiveQuery.searchField,
      searchValue: effectiveQuery.searchValue,
      searchOperator: effectiveQuery.searchOperator,
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

  Future<void> applyFilter(String? field, String? value) async {
    final section = qrecaudaSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => qrecaudaSections.first,
    );

    String? operator;
    if (field != null) {
      if (value != null && value.contains(',')) {
        operator = 'in';
      } else {
        for (final row in state.data) {
          if (row[field] != null) {
            if (row[field] is Iterable) operator = 'array-contains';
            break;
          }
        }
      }
    }
    final effectiveQuery = _resolveEffectiveQuery(
      sectionId: section.id,
      requestedField: field,
      requestedValue: value,
      requestedOperator: operator,
    );

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: effectiveQuery.searchField,
      searchValue: effectiveQuery.searchValue,
      clearSearch: effectiveQuery.searchField == null,
    );

    final result = await _dataSource.getCollection(
      section.collection,
      limit: 20,
      searchField: effectiveQuery.searchField,
      searchValue: effectiveQuery.searchValue,
      searchOperator: effectiveQuery.searchOperator,
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

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final section = qrecaudaSections.firstWhere(
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

  Future<String?> createItem(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = qrecaudaSections.firstWhere(
      (s) => s.id == state.activeSection,
    );
    final prepared = QRecaudaCollectionSaveRules.prepare(
      sectionId: section.id,
      rawPayload: data,
      isEdit: false,
    );
    if (prepared.error != null) {
      state = state.copyWith(isLoading: false, errorMessage: prepared.error);
      return prepared.error;
    }

    final result = await _dataSource.createDocument(
      section.collection,
      prepared.payload,
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

  Future<String?> updateItem(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = qrecaudaSections.firstWhere(
      (s) => s.id == state.activeSection,
    );
    final prepared = QRecaudaCollectionSaveRules.prepare(
      sectionId: section.id,
      rawPayload: data,
      isEdit: true,
    );
    if (prepared.error != null) {
      state = state.copyWith(isLoading: false, errorMessage: prepared.error);
      return prepared.error;
    }

    final result = await _dataSource.updateDocument(
      section.collection,
      id,
      prepared.payload,
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

  Future<String?> deleteItem(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = qrecaudaSections.firstWhere(
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

  Future<String?> createAdminUser({
    required String nombre,
    required String email,
    required String password,
    required String municipalidadId,
    String? mercadoId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final cleanNombre = nombre.trim();
    final cleanEmail = email.trim();
    final cleanMunicipalidadId = municipalidadId.trim();

    if (cleanNombre.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'El nombre del admin es obligatorio.',
      );
      return state.errorMessage;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Debes ingresar un correo valido.',
      );
      return state.errorMessage;
    }
    if (password.trim().length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'La contrasena debe tener al menos 6 caracteres.',
      );
      return state.errorMessage;
    }
    if (cleanMunicipalidadId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Selecciona una municipalidad valida.',
      );
      return state.errorMessage;
    }

    final result = await _dataSource.createAdminUser(
      nombre: cleanNombre,
      email: cleanEmail,
      password: password,
      municipalidadId: cleanMunicipalidadId,
      mercadoId: mercadoId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message;
      },
      (_) async {
        await selectSection('usuarios');
        return null;
      },
    );
  }

  Future<String?> createCobradorUser({
    required String nombre,
    required String email,
    required String password,
    required String municipalidadId,
    String? mercadoId,
    String? codigoCobrador,
    List<String>? rutaAsignada,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final cleanNombre = nombre.trim();
    final cleanEmail = email.trim();
    final cleanMunicipalidadId = municipalidadId.trim();
    final cleanPassword = password.trim();

    if (cleanNombre.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'El nombre del cobrador es obligatorio.',
      );
      return state.errorMessage;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Debes ingresar un correo valido.',
      );
      return state.errorMessage;
    }
    if (cleanPassword.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'La contrasena debe tener al menos 6 caracteres.',
      );
      return state.errorMessage;
    }
    if (cleanMunicipalidadId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Selecciona una municipalidad valida.',
      );
      return state.errorMessage;
    }

    final normalizedRuta = (rutaAsignada ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final result = await _dataSource.createCobradorUser(
      nombre: cleanNombre,
      email: cleanEmail,
      password: cleanPassword,
      municipalidadId: cleanMunicipalidadId,
      mercadoId: mercadoId,
      codigoCobrador: codigoCobrador,
      rutaAsignada: normalizedRuta,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return failure.message;
      },
      (_) async {
        await selectSection('usuarios');
        return null;
      },
    );
  }
}

// ── Providers ──
final qrecaudaDataSourceProvider = Provider<QRecaudaRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return QRecaudaRemoteDataSource(dioClient);
});

final qrecaudaDashboardProvider =
    StateNotifierProvider<QRecaudaDashboardViewModel, QRecaudaDashboardState>((
      ref,
    ) {
      final dataSource = ref.watch(qrecaudaDataSourceProvider);
      return QRecaudaDashboardViewModel(dataSource);
    });
