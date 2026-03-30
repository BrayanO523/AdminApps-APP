import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/network_provider.dart';
import '../../application/models/carwash_dashboard_state.dart';
import '../../application/services/carwash_reference_resolver.dart';
import '../../data/datasources/carwash_remote_datasource.dart';
import '../../data/repositories/carwash_repository_impl.dart';
import '../../domain/entities/carwash_section.dart';
import '../../domain/repositories/carwash_repository.dart';

class CarwashDashboardViewModel extends StateNotifier<CarwashDashboardState> {
  final CarwashRepository _repository;
  final CarwashReferenceResolver _referenceResolver;

  CarwashDashboardViewModel(
    this._repository, {
    CarwashReferenceResolver referenceResolver =
        const CarwashReferenceResolver(),
  }) : _referenceResolver = referenceResolver,
       super(const CarwashDashboardState());

  void selectEmpresaContext(Map<String, dynamic> empresa) {
    final current = List<Map<String, dynamic>>.from(state.selectedEmpresas);
    final id = empresa['id']?.toString();
    final index = current.indexWhere((item) => item['id']?.toString() == id);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(empresa);
    }
    state = state.copyWith(selectedEmpresas: current, clearError: true);
  }

  void clearEmpresaContext() {
    state = state.copyWith(clearEmpresas: true, clearError: true);
  }

  Future<void> selectSection(String sectionId) async {
    final section = _findSection(sectionId);
    final preparedFilter = _buildSectionFilter(sectionId);

    if (section.usesCustomView) {
      state = state.copyWith(
        activeSection: sectionId,
        isLoading: false,
        clearError: true,
        data: [],
        hasMore: false,
        totalItems: 0,
        clearSearch: true,
      );
      return;
    }

    if (preparedFilter.requiresCompanySelection) {
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

    state = state.copyWith(
      activeSection: sectionId,
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: preparedFilter.field,
      searchValue: preparedFilter.value,
    );

    await _loadSectionData(
      section: section,
      searchField: preparedFilter.field,
      searchValue: preparedFilter.value,
      searchOperator: preparedFilter.operator,
    );
  }

  Future<void> applyFilter(String? field, String? value) async {
    final section = _findSection(state.activeSection);
    final operator = _detectOperator(field, value, state.data);

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      data: [],
      hasMore: true,
      searchField: field,
      searchValue: value,
      clearSearch: field == null,
    );

    await _loadSectionData(
      section: section,
      searchField: field,
      searchValue: value,
      searchOperator: operator,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.data.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final section = _findSection(state.activeSection);
    final result = await _repository.getCollection(
      section.collection,
      limit: 20,
      ultimoDocId: state.data.last['id'],
      searchField: state.searchField,
      searchValue: state.searchValue,
      searchOperator: _detectOperator(
        state.searchField,
        state.searchValue,
        state.data,
      ),
      empresaId: _getEmpresaIdsStr(state),
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (response) async {
        final newData = [...state.data, ...response.data];
        state = state.copyWith(
          isLoading: false,
          data: newData,
          totalItems: response.total,
          hasMore: response.data.length == 20,
        );
        await _resolveIdsFromData(response.data);
      },
    );
  }

  Future<String?> createItem(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final section = _findSection(state.activeSection);
    final result = await _repository.createDocument(section.collection, data);
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
    final section = _findSection(state.activeSection);
    final result = await _repository.updateDocument(section.collection, id, data);
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
    final section = _findSection(state.activeSection);
    final result = await _repository.deleteDocument(section.collection, id);
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

  Future<void> _loadSectionData({
    required CarwashSection section,
    required String? searchField,
    required String? searchValue,
    required String? searchOperator,
  }) async {
    final result = await _repository.getCollection(
      section.collection,
      limit: 20,
      searchField: searchField,
      searchValue: searchValue,
      searchOperator: searchOperator,
      empresaId: _getEmpresaIdsStr(state),
    );

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
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

  Future<void> _resolveIdsFromData(List<Map<String, dynamic>> data) async {
    final resolved = await _referenceResolver.resolveMissingReferences(
      data: data,
      repository: _repository,
      cache: {
        'empresas': state.empresaNames,
        'sucursales': state.sucursalNames,
        'usuarios': state.usuarioNames,
        'clientes': state.clienteNames,
        'tiposLavados': state.tipoLavadoNames,
        'categorias': state.categoriaNames,
      },
    );

    state = state.copyWith(
      empresaNames: resolved['empresas'] ?? state.empresaNames,
      sucursalNames: resolved['sucursales'] ?? state.sucursalNames,
      usuarioNames: resolved['usuarios'] ?? state.usuarioNames,
      clienteNames: resolved['clientes'] ?? state.clienteNames,
      tipoLavadoNames: resolved['tiposLavados'] ?? state.tipoLavadoNames,
      categoriaNames: resolved['categorias'] ?? state.categoriaNames,
    );
  }

  CarwashSection _findSection(String sectionId) {
    return carwashSections.firstWhere(
      (section) => section.id == sectionId,
      orElse: () => carwashSections.first,
    );
  }

  _PreparedFilter _buildSectionFilter(String sectionId) {
    if (sectionId != 'empresas' && state.selectedEmpresas.isEmpty) {
      return const _PreparedFilter(requiresCompanySelection: true);
    }

    String? field = state.searchField;
    String? value = state.searchValue;

    if (state.selectedEmpresas.isNotEmpty && sectionId != 'empresas') {
      field = 'empresa_id';
      if (state.selectedEmpresas.length == 1) {
        value = state.selectedEmpresas.first['id']?.toString();
      } else {
        value = state.selectedEmpresas
            .map((item) => item['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .join(',');
      }
    }

    final operator = state.selectedEmpresas.length > 1 && sectionId != 'empresas'
        ? 'in'
        : _detectOperator(field, value, state.data);

    return _PreparedFilter(field: field, value: value, operator: operator);
  }

  String? _detectOperator(
    String? field,
    String? value,
    List<Map<String, dynamic>> data,
  ) {
    if (field == null) return null;
    if (value != null && value.contains(',')) return 'in';

    for (final row in data) {
      if (row[field] is Iterable) {
        return 'array-contains';
      }
    }
    return null;
  }

  String? _getEmpresaIdsStr(CarwashDashboardState currentState) {
    if (currentState.selectedEmpresas.isEmpty) return null;
    if (currentState.activeSection == 'empresas') return null;
    return currentState.selectedEmpresas
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .join(',');
  }
}

class _PreparedFilter {
  final String? field;
  final String? value;
  final String? operator;
  final bool requiresCompanySelection;

  const _PreparedFilter({
    this.field,
    this.value,
    this.operator,
    this.requiresCompanySelection = false,
  });
}

final carwashDataSourceProvider = Provider<CarwashRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return CarwashRemoteDataSource(dioClient);
});

final carwashRepositoryProvider = Provider<CarwashRepository>((ref) {
  final dataSource = ref.watch(carwashDataSourceProvider);
  return CarwashRepositoryImpl(dataSource);
});

final carwashDashboardProvider =
    StateNotifierProvider<CarwashDashboardViewModel, CarwashDashboardState>((
      ref,
    ) {
      final repository = ref.watch(carwashRepositoryProvider);
      return CarwashDashboardViewModel(repository);
    });
