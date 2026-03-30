import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/widgets/dynamic_data_table.dart';
import '../../../shared/presentation/widgets/dynamic_form_field_schema.dart';
import '../../../shared/presentation/widgets/dynamic_form_dialog.dart';
import '../../application/models/carwash_dashboard_state.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';
import '../widgets/carwash_account_statement_view.dart';
import '../widgets/carwash_balance_view.dart';
import '../widgets/carwash_error_state.dart';
import '../widgets/carwash_filter_bar.dart';
import '../widgets/carwash_invoice_view.dart';
import '../widgets/carwash_sidebar.dart';
import '../widgets/carwash_top_bar.dart';

class CarwashDashboardScreen extends ConsumerStatefulWidget {
  const CarwashDashboardScreen({super.key});

  @override
  ConsumerState<CarwashDashboardScreen> createState() =>
      _CarwashDashboardScreenState();
}

class _CarwashDashboardScreenState
    extends ConsumerState<CarwashDashboardScreen> {
  final _searchController = TextEditingController();
  static const int _pageSize = 20;
  String? _selectedSearchField;
  String _localSearchText = '';
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(carwashDashboardProvider.notifier).selectSection('empresas');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(carwashDashboardProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    ref.listen<CarwashDashboardState>(carwashDashboardProvider, (
      previous,
      next,
    ) {
      if (previous?.activeSection != next.activeSection) {
        _currentPage = 0;
        _searchController.clear();
        setState(() {
          _localSearchText = '';
          _selectedSearchField = null;
        });
      }
    });

    final filteredData = _applyLocalFilter(state.data);
    final totalItemsCount = _localSearchText.isNotEmpty
        ? filteredData.length
        : (state.totalItems > 0 ? state.totalItems : filteredData.length);
    final totalPagesCount = (totalItemsCount / _pageSize).ceil();
    final startIdx = _currentPage * _pageSize;
    final paginatedData = filteredData.skip(startIdx).take(_pageSize).toList();
    final endIdx = startIdx + paginatedData.length;

    final selectedCompanyId = state.selectedEmpresas.length == 1
        ? state.selectedEmpresas.first['id']?.toString()
        : null;

    final content = Column(
      children: [
        CarwashTopBar(
          state: state,
          hasFilters: state.searchField != null && state.searchValue != null,
          isMobile: isMobile,
          searchController: _searchController,
          selectedSearchField: _selectedSearchField,
          onSearchFieldChanged: (value) {
            setState(() => _selectedSearchField = value);
          },
          onSearchChanged: (value) {
            setState(() => _localSearchText = value);
          },
          onCreate: () => _showCreateDialog(state),
          onClearFilters: _clearFilters,
          iconButtonBuilder: _iconBtn,
        ),
        if (!state.isLoading && state.data.isNotEmpty)
          CarwashFilterBar(
            state: state,
            onClearFilters: _clearFilters,
            isRawIdField: _isRawIdField,
          ),
        Expanded(
          child: state.activeSection == 'balance'
              ? CarwashBalanceView(companyId: selectedCompanyId)
              : state.activeSection == 'facturas'
              ? CarwashInvoiceView(companyId: selectedCompanyId)
              : state.activeSection == 'estadoCuenta'
              ? CarwashAccountStatementView(companyId: selectedCompanyId)
              : state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                )
              : state.errorMessage != null
              ? CarwashErrorState(
                  message: state.errorMessage!,
                  onRetry: () {
                    ref
                        .read(carwashDashboardProvider.notifier)
                        .selectSection(state.activeSection);
                  },
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 8 : 20,
                    8,
                    isMobile ? 8 : 20,
                    0,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: DynamicDataTable(
                              data: paginatedData,
                              dashboardState: state,
                              activeFilters: const {},
                              isContextSelected: (row) =>
                                  state.selectedEmpresas.any(
                                    (item) =>
                                        item['id']?.toString() ==
                                        row['id']?.toString(),
                                  ),
                              onSelectContext: state.activeSection == 'empresas'
                                  ? (row) => _toggleEmpresaContext(row)
                                  : null,
                              onEdit: _showEditDialog,
                              onDelete: _showDeleteDialog,
                              onFilterToggle: (column, rawValue) {
                                ref
                                    .read(carwashDashboardProvider.notifier)
                                    .applyFilter(column, rawValue);
                              },
                            ),
                          ),
                        ),
                      ),
                      if (state.hasMore ||
                          state.data.length >= 20 ||
                          totalPagesCount > 1)
                        _buildPaginationBar(
                          totalItemsCount,
                          totalPagesCount,
                          startIdx,
                          endIdx,
                          state.hasMore,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
        ),
      ],
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0C1929),
          child: SafeArea(
            child: CarwashSidebar(onItemTap: () => Navigator.pop(context)),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const CarwashSidebar(),
          Expanded(child: content),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applyLocalFilter(
    List<Map<String, dynamic>> data,
  ) {
    if (_localSearchText.isEmpty || _selectedSearchField == null) return data;
    final query = _localSearchText.toLowerCase();
    final field = _selectedSearchField!;
    return data.where((row) {
      final value = row[field];
      if (value == null) return false;
      if (value is Iterable) {
        return value.any((item) => item.toString().toLowerCase().contains(query));
      }
      return value.toString().toLowerCase().contains(query);
    }).toList();
  }

  static bool _isRawIdField(String key) {
    final normalized = key.trim();
    if (normalized.toLowerCase() == 'id') return true;
    if (normalized.endsWith('Id') && normalized.length > 2) return true;
    if (normalized.endsWith('_id') && normalized.length > 3) return true;
    if (normalized.toLowerCase().startsWith('id_') && normalized.length > 3) {
      return true;
    }
    if (normalized.endsWith('ID') && normalized.length > 2) return true;
    if (normalized.length > 2 &&
        normalized.startsWith('Id') &&
        normalized[2] == normalized[2].toUpperCase() &&
        normalized[2] != '_') {
      return true;
    }
    return false;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _localSearchText = '';
      _selectedSearchField = null;
    });

    final state = ref.read(carwashDashboardProvider);
    if (state.selectedEmpresas.isNotEmpty && state.activeSection != 'empresas') {
      final empresaIds = state.selectedEmpresas
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .join(',');
      ref.read(carwashDashboardProvider.notifier).applyFilter(
            'empresa_id',
            empresaIds.isNotEmpty ? empresaIds : null,
          );
      return;
    }

    ref.read(carwashDashboardProvider.notifier).applyFilter(null, null);
  }

  void _toggleEmpresaContext(Map<String, dynamic> row) {
    final isSelected = ref
        .read(carwashDashboardProvider)
        .selectedEmpresas
        .any((item) => item['id']?.toString() == row['id']?.toString());

    ref.read(carwashDashboardProvider.notifier).selectEmpresaContext(row);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSelected
              ? 'Empresa ${row['nombre'] ?? row['name'] ?? ''} deseleccionada.'
              : 'Empresa ${row['nombre'] ?? row['name'] ?? ''} seleccionada.',
        ),
        backgroundColor: isSelected
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _showCreateDialog(CarwashDashboardState state) async {
    final template = state.data.isNotEmpty
        ? state.data.first
        : <String, dynamic>{};
    final initialData = <String, dynamic>{};
    for (final key in template.keys) {
      if (key == 'id') continue;
      final value = template[key];
      if (value is int) {
        initialData[key] = 0;
      } else if (value is double) {
        initialData[key] = 0.0;
      } else if (value is bool) {
        initialData[key] = false;
      } else if (value is String) {
        initialData[key] = '';
      }
    }

    final formConfig = await _buildFormConfig(
      baseInitialData: initialData,
      state: state,
      isEdit: false,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: formConfig.initialData,
        isEdit: false,
        title: 'Crear en ${state.activeSectionLabel}',
        fieldSchemas: formConfig.fieldSchemas,
        hiddenFields: formConfig.hiddenFields,
      ),
    );

    if (result == null || !mounted) return;

    final error = await ref
        .read(carwashDashboardProvider.notifier)
        .createItem(result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Documento creado con éxito',
        ),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final formConfig = await _buildFormConfig(
      baseInitialData: row,
      state: ref.read(carwashDashboardProvider),
      isEdit: true,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: formConfig.initialData,
        isEdit: true,
        title: 'Editar Documento',
        fieldSchemas: formConfig.fieldSchemas,
        hiddenFields: formConfig.hiddenFields,
      ),
    );

    if (result == null || !mounted) return;

    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: El documento no tiene ID')),
      );
      return;
    }

    final error = await ref
        .read(carwashDashboardProvider.notifier)
        .updateItem(id, result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Documento actualizado'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('¿Eliminar documento?'),
        content: const Text(
          'Esta acción es irreversible. ¿Seguro que deseas eliminar el registro permanentemente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final error = await ref
        .read(carwashDashboardProvider.notifier)
        .deleteItem(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Documento eliminado'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildPaginationBar(
    int totalItems,
    int totalPages,
    int start,
    int end,
    bool hasServerMore,
  ) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            start == end
                ? 'Mostrando $end de $totalItems'
                : 'Mostrando ${start + 1}-$end de $totalItems',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              _paginationBtn(
                Icons.first_page_rounded,
                _currentPage > 0,
                () => setState(() => _currentPage = 0),
              ),
              const SizedBox(width: 4),
              _paginationBtn(
                Icons.chevron_left_rounded,
                _currentPage > 0,
                () => setState(() => _currentPage--),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _paginationBtn(
                Icons.chevron_right_rounded,
                ((_currentPage + 1) * _pageSize) <
                        ref.read(carwashDashboardProvider).data.length ||
                    hasServerMore,
                () {
                  final dataLength = ref.read(carwashDashboardProvider).data.length;
                  final nextStartIndex = (_currentPage + 1) * _pageSize;

                  if (nextStartIndex >= dataLength && hasServerMore) {
                    ref.read(carwashDashboardProvider.notifier).loadMore().then((_) {
                      if (mounted) {
                        setState(() => _currentPage++);
                      }
                    });
                  } else if (nextStartIndex < dataLength) {
                    setState(() => _currentPage++);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paginationBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? const Color(0xFF475569) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 18),
        ),
      ),
    );
  }

  Future<_CarwashFormConfig> _buildFormConfig({
    required Map<String, dynamic> baseInitialData,
    required CarwashDashboardState state,
    required bool isEdit,
  }) async {
    final initialData = Map<String, dynamic>.from(baseInitialData);
    final hiddenFields = <String>{
      'createdBy',
      'createdAt',
      'updatedBy',
      'updatedAt',
      'creado_en',
      'creado_por',
      'fecha_creacion',
    };
    final fieldSchemas = <String, DynamicFormFieldSchema>{};

    _applySectionDefaults(
      initialData: initialData,
      activeSection: state.activeSection,
    );

    final selectedCompanyId = state.selectedEmpresas.length == 1
        ? state.selectedEmpresas.first['id']?.toString()
        : null;
    final effectiveCompanyId =
        selectedCompanyId ??
        initialData['empresa_id']?.toString() ??
        initialData['empresaId']?.toString();

    if (effectiveCompanyId != null && effectiveCompanyId.isNotEmpty) {
      if (initialData.containsKey('empresa_id')) {
        initialData['empresa_id'] = effectiveCompanyId;
        hiddenFields.add('empresa_id');
      }
      if (initialData.containsKey('empresaId')) {
        initialData['empresaId'] = effectiveCompanyId;
        hiddenFields.add('empresaId');
      }
    }

    final branchOptions = await _loadBranchOptions(effectiveCompanyId);
    final branchFieldKeys = ['sucursal_id', 'sucursalId'];
    for (final key in branchFieldKeys) {
      if (!initialData.containsKey(key)) continue;
      fieldSchemas[key] = DynamicFormFieldSchema(
        type: DynamicFormFieldType.dropdown,
        label: 'Sucursal',
        options: branchOptions,
      );

      final currentValue = initialData[key]?.toString() ?? '';
      if (currentValue.isEmpty && branchOptions.length == 1) {
        initialData[key] = branchOptions.first['value']?.toString() ?? '';
      }
    }

    if (!isEdit && effectiveCompanyId != null && branchOptions.isEmpty) {
      hiddenFields.remove('sucursal_id');
      hiddenFields.remove('sucursalId');
    }

    if (state.activeSection == 'productos') {
      if (initialData.containsKey('sucursal_ids')) {
        fieldSchemas['sucursal_ids'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.multiselectDropdown,
          label: 'Sucursales',
          options: branchOptions,
        );
      }

      if (initialData.containsKey('activo')) {
        fieldSchemas['activo'] = const DynamicFormFieldSchema(
          type: DynamicFormFieldType.radioSelect,
          label: 'Activo',
          options: [
            {'value': 'true', 'label': 'true'},
            {'value': 'false', 'label': 'false'},
          ],
        );
      }
    }

    if (state.activeSection == 'tiposLavados') {
      final categoryOptions = _extractDistinctOptions(
        state.data,
        field: 'categoria',
      );
      final vehicleTypeOptions = _extractVehicleTypeOptions(state.data);

      if (initialData.containsKey('categoria')) {
        fieldSchemas['categoria'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.dropdown,
          label: 'Categoria',
          options: categoryOptions,
          allowCustomEntries: true,
        );
      }

      if (initialData.containsKey('sucursal_ids')) {
        fieldSchemas['sucursal_ids'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.multiselectDropdown,
          label: 'Sucursales',
          options: branchOptions,
        );
      }

      if (initialData.containsKey('activo')) {
        fieldSchemas['activo'] = const DynamicFormFieldSchema(
          type: DynamicFormFieldType.radioSelect,
          label: 'Activo',
          options: [
            {'value': 'true', 'label': 'true'},
            {'value': 'false', 'label': 'false'},
          ],
        );
      }

      if (initialData.containsKey('precios')) {
        fieldSchemas['precios'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.keyValueNumberMap,
          label: 'Precios por Vehiculo',
          options: vehicleTypeOptions,
          allowCustomEntries: true,
        );
      }
    }

    if (state.activeSection == 'vehiculos') {
      final washTypeOptions = await _loadWashTypeOptions(effectiveCompanyId);
      final vehicleTypeOptions = _extractVehicleTypeOptions(state.data);

      if (initialData.containsKey('tipo_vehiculo')) {
        fieldSchemas['tipo_vehiculo'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.dropdown,
          label: 'Tipo Vehiculo',
          options: vehicleTypeOptions,
          allowCustomEntries: true,
        );
      }

      if (initialData.containsKey('servicios')) {
        fieldSchemas['servicios'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.multiselectDropdown,
          label: 'Servicios',
          options: washTypeOptions,
        );
      }

      if (initialData.containsKey('estado')) {
        fieldSchemas['estado'] = DynamicFormFieldSchema(
          type: DynamicFormFieldType.dropdown,
          label: 'Estado',
          options: _extractDistinctOptions(state.data, field: 'estado'),
          allowCustomEntries: true,
        );
      }
    }

    if (state.activeSection == 'usuarios' &&
        initialData.containsKey('is_first_login')) {
      fieldSchemas['is_first_login'] = const DynamicFormFieldSchema(
        type: DynamicFormFieldType.radioSelect,
        label: 'Is First Login',
        options: [
          {'value': 'true', 'label': 'true'},
          {'value': 'false', 'label': 'false'},
        ],
      );
    }

    return _CarwashFormConfig(
      initialData: initialData,
      hiddenFields: hiddenFields.toList(),
      fieldSchemas: fieldSchemas,
    );
  }

  void _applySectionDefaults({
    required Map<String, dynamic> initialData,
    required String activeSection,
  }) {
    if (activeSection == 'productos') {
      initialData.putIfAbsent('empresa_id', () => '');
      initialData.putIfAbsent('sucursal_ids', () => <String>[]);
      initialData.putIfAbsent('nombre', () => '');
      initialData.putIfAbsent('descripcion', () => '');
      initialData.putIfAbsent('precio', () => 0.0);
      initialData.putIfAbsent('categoria', () => '');
      initialData.putIfAbsent('imagen_url', () => '');
      initialData.putIfAbsent('activo', () => true);
    }

    if (activeSection == 'tiposLavados') {
      initialData.putIfAbsent('nombre', () => '');
      initialData.putIfAbsent('descripcion', () => '');
      initialData.putIfAbsent('categoria', () => '');
      initialData.putIfAbsent('activo', () => true);
      initialData.putIfAbsent('precios', () => <String, dynamic>{});
      initialData.putIfAbsent('empresa_id', () => '');
      initialData.putIfAbsent('sucursal_ids', () => <String>[]);
    }

    if (activeSection == 'vehiculos') {
      initialData.putIfAbsent('cliente_id', () => '');
      initialData.putIfAbsent('empresa_id', () => '');
      initialData.putIfAbsent('fecha_ingreso', () => '');
      initialData.putIfAbsent('fotos', () => <String>[]);
      initialData.putIfAbsent('estado', () => '');
      initialData.putIfAbsent('nombre_cliente', () => '');
      initialData.putIfAbsent('tipo_vehiculo', () => '');
      initialData.putIfAbsent('sucursal_id', () => '');
      initialData.putIfAbsent('servicios', () => <String>[]);
    }
  }

  Future<List<Map<String, dynamic>>> _loadBranchOptions(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return const [];

    final repository = ref.read(carwashRepositoryProvider);
    final result = await repository.getCollection(
      'sucursales',
      limit: 100,
      searchField: 'empresa_id',
      searchValue: companyId,
      empresaId: companyId,
    );

    return result.fold(
      (_) => const [],
      (response) => response.data
          .map(
            (row) => {
              'value': row['id']?.toString() ?? '',
              'label': row['nombre']?.toString() ?? row['id']?.toString() ?? '',
            },
          )
          .where((option) => (option['value'] ?? '').isNotEmpty)
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadWashTypeOptions(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return const [];

    final repository = ref.read(carwashRepositoryProvider);
    final result = await repository.getCollection(
      'tiposLavados',
      limit: 100,
      searchField: 'empresa_id',
      searchValue: companyId,
      empresaId: companyId,
    );

    return result.fold(
      (_) => const [],
      (response) => response.data
          .map(
            (row) => {
              'value': row['id']?.toString() ?? '',
              'label': row['nombre']?.toString() ?? row['id']?.toString() ?? '',
            },
          )
          .where((option) => (option['value'] ?? '').isNotEmpty)
          .toList(),
    );
  }

  List<Map<String, dynamic>> _extractDistinctOptions(
    List<Map<String, dynamic>> rows, {
    required String field,
  }) {
    final values = <String>{};
    for (final row in rows) {
      final raw = row[field]?.toString().trim() ?? '';
      if (raw.isNotEmpty) values.add(raw);
    }
    final sorted = values.toList()..sort();
    return sorted.map((value) => {'value': value, 'label': value}).toList();
  }

  List<Map<String, dynamic>> _extractVehicleTypeOptions(
    List<Map<String, dynamic>> rows,
  ) {
    final values = <String>{};
    for (final row in rows) {
      final precios = row['precios'];
      if (precios is Map) {
        values.addAll(
          precios.keys.map((key) => key.toString()).where((key) => key.isNotEmpty),
        );
      }
    }
    final sorted = values.toList()..sort();
    return sorted.map((value) => {'value': value, 'label': value}).toList();
  }
}

class _CarwashFormConfig {
  final Map<String, dynamic> initialData;
  final List<String> hiddenFields;
  final Map<String, DynamicFormFieldSchema> fieldSchemas;

  const _CarwashFormConfig({
    required this.initialData,
    required this.hiddenFields,
    required this.fieldSchemas,
  });
}
