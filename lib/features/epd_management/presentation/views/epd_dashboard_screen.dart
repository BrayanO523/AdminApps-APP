import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/di/network_provider.dart';

import '../../domain/entities/epd_section.dart';
import '../viewmodels/epd_dashboard_viewmodel.dart';
import '../widgets/epd_sidebar.dart';
import '../../../shared/presentation/widgets/dynamic_data_table.dart';
import '../../../shared/presentation/widgets/dynamic_form_dialog.dart';
import '../../../shared/presentation/widgets/dynamic_form_field_schema.dart';

class EpdDashboardScreen extends ConsumerStatefulWidget {
  const EpdDashboardScreen({super.key});

  @override
  ConsumerState<EpdDashboardScreen> createState() => _EpdDashboardScreenState();
}

class _EpdDashboardScreenState extends ConsumerState<EpdDashboardScreen> {
  final _searchController = TextEditingController();
  String? _selectedSearchField;
  static const int _pageSize = 20;
  int _currentPage = 0;

  Future<String> _uploadImageToStorage(
    List<int> bytes,
    String storagePath,
  ) async {
    try {
      final response = await ref
          .read(dioClientProvider)
          .instance
          .post(
            '/eficent/upload-image',
            data: {
              'imageBase64': base64Encode(bytes),
              'storagePath': storagePath,
            },
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final url = (data is Map<String, dynamic>)
            ? data['downloadUrl']?.toString()
            : null;
        if (url != null && url.isNotEmpty) return url;
      }

      throw Exception('La API no devolvió una URL válida de imagen.');
    } on TimeoutException {
      throw Exception(
        'Timeout subiendo imagen por API. Verifica conectividad y estado del servidor.',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final apiMessage = (data is Map ? data['error']?.toString() : null);
      throw Exception(
        'Error de API al subir imagen (${status ?? "sin status"}): ${apiMessage ?? e.message ?? "sin detalle"}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(epdDashboardProvider.notifier).selectSection('companies');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Detecta si un campo es un ID de referencia crudo (no aporta al usuario final).
  static bool _isRawIdField(String key) {
    final k = key.trim();
    if (k.toLowerCase() == 'id') return true;
    if (k.endsWith('Id') && k.length > 2) return true;
    if (k.endsWith('_id') && k.length > 3) return true;
    if (k.toLowerCase().startsWith('id_') && k.length > 3) return true;
    if (k.endsWith('ID') && k.length > 2) return true;
    // Empieza con 'Id' + mayÃºscula (IdSucursal, IdUsuario, IdEmpresa...)
    if (k.length > 2 &&
        k.startsWith('Id') &&
        k[2] == k[2].toUpperCase() &&
        k[2] != '_')
      return true;
    return false;
  }

  static const Set<String> _createDisabledSections = {
    'sales',
    'waste_reports',
    'inventory_transactions',
    'inventory_transfers',
  };

  bool _isCreateDisabled(String sectionId) =>
      _createDisabledSections.contains(sectionId);

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedSearchField = null;
    });
    ref.read(epdDashboardProvider.notifier).applyFilter(null, null);
  }

  Future<void> _applyTextSearch(EpdDashboardState state) async {
    final field = _selectedSearchField;
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      await ref.read(epdDashboardProvider.notifier).applyFilter(null, null);
      return;
    }

    if (field == null || field.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una columna antes de buscar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ref
        .read(epdDashboardProvider.notifier)
        .applyFilter(field, query, operatorOverride: 'contains');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epdDashboardProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    ref.listen<EpdDashboardState>(epdDashboardProvider, (previous, next) {
      if (previous?.activeSection != next.activeSection) {
        _currentPage = 0;
        _searchController.clear();
        setState(() {
          _selectedSearchField = null;
        });
      }
    });

    final hasFilters = state.searchField != null && state.searchValue != null;
    final filteredData = state.data;

    final totalItemsCount = state.totalItems > 0
        ? state.totalItems
        : filteredData.length;
    final totalPagesCount = (totalItemsCount / _pageSize).ceil();

    if (_currentPage >= totalPagesCount &&
        totalPagesCount > 0 &&
        !state.hasMore) {
      if ((filteredData.length / _pageSize).ceil() <= _currentPage) {
        _currentPage = (filteredData.length / _pageSize).ceil() - 1;
        if (_currentPage < 0) _currentPage = 0;
      }
    }

    final startIdx = _currentPage * _pageSize;
    final paginatedData = filteredData.skip(startIdx).take(_pageSize).toList();
    final endIdx = startIdx + paginatedData.length;

    final content = Column(
      children: [
        _buildTopBar(state, hasFilters, isMobile),
        if (!state.isLoading && state.data.isNotEmpty) _buildFilterBar(state),
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                )
              : state.errorMessage != null
              ? _buildError(state.errorMessage!)
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
                              isContextSelected: (row) => state.selectedEmpresas
                                  .any((e) => e['id'] == row['id']),
                              onSelectContext:
                                  state.activeSection == 'companies'
                                  ? (row) {
                                      final isSelected = state.selectedEmpresas
                                          .any((e) => e['id'] == row['id']);
                                      ref
                                          .read(epdDashboardProvider.notifier)
                                          .selectEmpresaContext(row);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isSelected
                                                ? 'Empresa ${row['nombre'] ?? row['name'] ?? ''} deseleccionada.'
                                                : 'Empresa ${row['nombre'] ?? row['name'] ?? ''} seleccionada.',
                                          ),
                                          backgroundColor: isSelected
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF8B5CF6),
                                        ),
                                      );
                                    }
                                  : null,
                              // BotÃ³n extra para ajuste atÃ³mico de stock
                              onExtraAction: state.activeSection == 'inventory'
                                  ? (row) => _showInventoryAdjustDialog(row)
                                  : null,
                              extraActionIcon: Icons.swap_vert_circle_rounded,
                              extraActionColor: const Color(0xFF059669),
                              extraActionTooltip: 'Ajustar Stock',
                              onEdit: (row) => _showEditDialog(row),
                              onDelete: (row) => _showDeleteDialog(row),
                              onFilterToggle: (column, rawValue) {
                                ref
                                    .read(epdDashboardProvider.notifier)
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
                          () {
                            ref
                                .read(epdDashboardProvider.notifier)
                                .loadMore()
                                .then((_) {
                                  if (mounted) {
                                    setState(() => _currentPage++);
                                  }
                                });
                          },
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
          backgroundColor: const Color(0xFF0F172A),
          child: SafeArea(
            child: EpdSidebar(onItemTap: () => Navigator.pop(context)),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const EpdSidebar(),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildTopBar(EpdDashboardState state, bool hasFilters, bool isMobile) {
    final section = epdSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => epdSections.first,
    );
    final canCreate =
        !_isCreateDisabled(state.activeSection) && !state.isLoading;
    final content = Row(
      children: [
        if (isMobile)
          Builder(
            builder: (ctx) => _iconBtn(Icons.menu_rounded, () {
              Scaffold.of(ctx).openDrawer();
            }),
          )
        else
          _iconBtn(Icons.arrow_back_rounded, () => context.go('/dashboard')),
        SizedBox(width: isMobile ? 8 : 16),
        Icon(
          section.icon,
          size: isMobile ? 20 : 24,
          color: const Color(0xFF0F172A),
        ),
        SizedBox(width: isMobile ? 6 : 12),
        if (!isMobile)
          Text(
            state.activeSectionLabel,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          )
        else
          Flexible(
            child: Text(
              state.activeSectionLabel,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (state.selectedEmpresas.isNotEmpty) ...[
          SizedBox(width: isMobile ? 6 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 14,
                  color: Color(0xFF7E22CE),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    state.selectedEmpresas.length == 1
                        ? (state.selectedEmpresas.first['nombre']?.toString() ??
                              state.selectedEmpresas.first['name']
                                  ?.toString() ??
                              state.selectedEmpresas.first['razonSocial']
                                  ?.toString() ??
                              'Empresa')
                        : '${state.selectedEmpresas.length} Empresas',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF7E22CE),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    ref
                        .read(epdDashboardProvider.notifier)
                        .clearEmpresaContext();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF7E22CE),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(width: isMobile ? 6 : 12),
        if (!state.isLoading && state.errorMessage == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hasFilters
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total: ${state.totalItems}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: hasFilters
                    ? const Color(0xFF92400E)
                    : const Color(0xFF6D28D9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!isMobile) const Spacer(),
        // BÃºsqueda textual - solo desktop
        if (!isMobile && (state.data.isNotEmpty || state.searchField != null))
          Container(
            height: 36,
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar texto...',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (value) {
                      _applyTextSearch(state);
                    },
                  ),
                ),
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSearchField,
                      hint: Text(
                        'Columna',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSearchField = newValue;
                        });
                      },
                      items: (() {
                        final cols = <String>{};
                        for (final row in state.data) {
                          cols.addAll(row.keys);
                        }
                        final list = cols
                            .where((col) => !_isRawIdField(col))
                            .toList();
                        list.removeWhere(
                          (col) => [
                            'createdAt',
                            'updatedAt',
                            'created_at',
                            'updated_at',
                            'creadoEn',
                            'actualizadoEn',
                            'sync_status',
                            'last_update_cloud',
                            'lastUpdateCloud',
                            'creado_offline',
                            'creado_por',
                            'fecha_creacion',
                          ].contains(col),
                        );
                        list.sort((a, b) {
                          final aLower = a.toLowerCase();
                          final bLower = b.toLowerCase();
                          final aIsName =
                              aLower.contains('nombre') ||
                              aLower == 'name' ||
                              aLower.contains('razon');
                          final bIsName =
                              bLower.contains('nombre') ||
                              bLower == 'name' ||
                              bLower.contains('razon');
                          if (aIsName && !bIsName) return -1;
                          if (!aIsName && bIsName) return 1;
                          return a.compareTo(b);
                        });
                        if (_selectedSearchField != null &&
                            !list.contains(_selectedSearchField)) {
                          list.insert(0, _selectedSearchField!);
                        }
                        return list.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList();
                      })(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 12),
        if (hasFilters)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: Text(
                'Limpiar filtro',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ),
        _iconBtn(Icons.refresh_rounded, () {
          ref
              .read(epdDashboardProvider.notifier)
              .selectSection(state.activeSection);
        }),
        const SizedBox(width: 12),
        if (isMobile)
          IconButton(
            onPressed: canCreate ? () => _showCreateDialog(state) : null,
            icon: const Icon(Icons.add_circle_rounded, size: 28),
            color: const Color(0xFF8B5CF6),
            tooltip: canCreate
                ? 'Crear Documento'
                : 'Creación deshabilitada para esta sección',
          )
        else
          ElevatedButton.icon(
            onPressed: canCreate ? () => _showCreateDialog(state) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Crear Documento',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );

    return Container(
      height: isMobile ? 56 : 80,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildFilterBar(EpdDashboardState state) {
    final columnas = <String>{};
    for (final row in state.data) {
      columnas.addAll(row.keys);
    }
    // Excluir campos de ID y tÃ©cnicos del filtro visible al usuario
    final listaColumnas = columnas.where((col) => !_isRawIdField(col)).toList()
      ..sort();
    listaColumnas.removeWhere(
      (col) => [
        'createdAt',
        'updatedAt',
        'created_at',
        'updated_at',
        'creadoEn',
        'actualizadoEn',
        'sync_status',
        'last_update_cloud',
        'lastUpdateCloud',
        'creado_offline',
        'creado_por',
        'fecha_creacion',
      ].contains(col),
    );

    final activeField = state.searchField;
    final activeValue = state.searchValue;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: listaColumnas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final col = listaColumnas[index];
          final isActive = activeField == col && activeValue != null;

          final valoresUnicos = <String>{};
          for (final row in state.data) {
            final val = row[col];
            if (val == null) continue;
            if (val is Iterable) {
              for (final item in val) {
                if (item != null && item.toString().trim().isNotEmpty) {
                  valoresUnicos.add(item.toString().trim());
                }
              }
            } else {
              if (val.toString().trim().isNotEmpty) {
                valoresUnicos.add(val.toString().trim());
              }
            }
          }
          final listaValores = valoresUnicos.toList()..sort();

          return Center(
            child: PopupMenuButton<String>(
              tooltip: 'Filtrar por $col',
              onSelected: (valor) {
                if (valor == '__CLEAR__') {
                  _clearFilters();
                } else {
                  ref
                      .read(epdDashboardProvider.notifier)
                      .applyFilter(col, valor);
                }
              },
              constraints: const BoxConstraints(maxHeight: 350, maxWidth: 300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              itemBuilder: (_) {
                final items = <PopupMenuEntry<String>>[];
                if (isActive) {
                  items.add(
                    PopupMenuItem(
                      value: '__CLEAR__',
                      child: Row(
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quitar filtro',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  items.add(const PopupMenuDivider());
                }
                for (final v in listaValores) {
                  final selected = isActive && activeValue == v;
                  final displayName = state.isResolvableField(col)
                      ? state.resolveId(col, v)
                      : v;
                  final label = displayName.length > 40
                      ? '${displayName.substring(0, 40)}...'
                      : displayName;
                  items.add(
                    PopupMenuItem(
                      value: v,
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  );
                }
                return items;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.filter_alt_rounded
                          : Icons.filter_list_rounded,
                      size: 14,
                      color: isActive
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive
                          ? '$col: ${state.isResolvableField(col) ? state.resolveId(col, activeValue) : activeValue}'
                          : col,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isActive
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, DynamicFormFieldSchema> _buildFieldSchemas(
    EpdDashboardState state,
  ) {
    switch (state.activeSection) {
      // -- Sucursales --
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
            label: 'Categorías Permitidas',
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

      // -- Usuarios --
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

      // -- Categorías --
      case 'categories':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            optionsResolver: () => state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'Color': DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color de Categoría',
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

      // -- Productos --
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
            label: 'Categoría',
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
              {'value': '0', 'label': 'No es Promoción'},
              {'value': '1', 'label': 'Sí es Promoción'},
            ],
            label: '¿En Promoción?',
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

      // -- Combos --
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

      // -- Clientes --
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

      // -- Tipos de Gasto --
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
          'isActive': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '1', 'label': 'Activo'},
              {'value': '0', 'label': 'Inactivo'},
            ],
            label: 'Estado',
          ),
        };

      // -- Registro de Gastos --
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

      // -- Proveedores --
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
            label: 'Alcance del Proveedor?',
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

      // -- Asignaciones de Proveedores --
      case 'supplier_assignments':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'IdSucursal': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('branches'),
            label: 'Sucursal',
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

      // -- Empresas ---------------------------------------------------------
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
  } // fin de _buildFieldSchemas

  // -- Lista global de campos de sistema que el admin NUNCA debe ver ni tocar --
  static const _hiddenSystemFields = [
    // SQLite offline-only
    'creado_offline', 'modificado_offline', 'SYNC_STATUS',
    // Timestamps gestionados por el backend
    'last_modified', 'last_updated_cloud', 'fechacreacion',
    'fecha_creacion_registro',
    // AuditorÃ­a interna
    'creado_por', 'modificado_por', 'idusuario', 'Idvendedor',
    'seller_id',
    // Banderas y contadores internos del motor mÃ³vil
    'estado', 'Favorito', 'OrdenFavorito',
    'contador_ventas', 'isTemplate', 'source_template_id',
    'sync_status', 'control_inventario', 'clientes_enabled',
    'pesos_rapidos_enabled', 'adminId',
    // IDs canÃ³nicos autogenerados por el backend al crear
    'IdProducto', 'IdCombo', 'IdInventario',
    'IdTransaccion', 'IdVenta', 'IdCliente', 'IdUsuario',
    // Autogenerados (no debe llenar el admin)
    'CodigoSucursal',
    // Campos de usuario que no aplican en el formulario
    'selected_categories',
    'IdSucursalesAsignadas',
    'IdSucursal',
    'items',
  ];

  /// Devuelve los campos base requeridos por cada colecciÃ³n, para que el formulario
  /// de creaciÃ³n funcione aunque la tabla estÃ© completamente vacÃ­a.
  Map<String, dynamic> _getBaseFieldsForSection(String section) {
    switch (section) {
      // -- Empresas --
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

      // -- Sucursales (CÃ³digoSucursal autogenerado por backend) --
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

      // -- Usuarios --
      case 'users':
        return {
          'NombreCompleto': '',
          'CodigoUsuario': '',
          'pin': '',
          'rol': 'VENDEDOR',
          'empresaId': '',
          // IdSucursal y selected_categories estÃ¡n en _hiddenSystemFields;
          // el backend rellena IdSucursal desde IdSucursalesAsignadas[0].
          'IdSucursal': '',
          'IdSucursalesAsignadas': '[]',
          'selected_categories': '[]',
          'activo': 1,
        };

      // -- Clientes --
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

      // -- Tipos de Gasto --
      case 'expense_categories':
        return {
          'name': '',
          'color': '#EF4444',
          'icon': 'receipt_long',
          'empresaId': '',
          'isActive': 1,
        };

      // -- Registro de Gastos --
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

      // -- Categorías --
      case 'categories':
        return {
          'NombreCategoria': '',
          'descripcion': '',
          'Color': '0xFF3498DB',
          'empresaId': '',
          'activo': 1,
        };

      // -- Productos --
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
          // Campos del motor mÃ³vil (ocultos, valores por defecto)
          'Favorito': 0,
          'OrdenFavorito': 0,
          'contador_ventas': 0,
          'Activo': 1,
          'sync_status': 1,
        };

      // -- Combos --
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

      // -- Proveedores --
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

      // -- Asignaciones de Proveedores --
      case 'supplier_assignments':
        return {
          'IdProveedor': '',
          'IdSucursal': '',
          'motivo': '',
          'empresaId': '',
          'activo': 1,
        };

      // Inventario, ventas, mermas, traslados -> solo lectura
      case 'inventory':
      case 'inventory_transactions':
      case 'inventory_transfers':
      case 'sales':
      case 'waste_reports':
      case 'catalog_templates':
      case 'category_templates':
        return {}; // Sin formulario de creaciÃ³n

      default:
        return {};
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

  List<String> _getAssignedSellerIdsForBranch(
    EpdDashboardState state,
    Map<String, dynamic> branchRow,
  ) {
    final branchId = branchRow['id']?.toString().trim() ?? '';
    if (branchId.isEmpty) return const [];

    final branchEmpresaId = branchRow['empresaId']?.toString().trim() ?? '';
    final result = <String>[];

    for (final user in state.cachedUsers) {
      final userId = user['id']?.toString().trim() ?? '';
      if (userId.isEmpty) continue;

      if (branchEmpresaId.isNotEmpty) {
        final userEmpresaId = user['empresaId']?.toString().trim() ?? '';
        if (userEmpresaId != branchEmpresaId) continue;
      }

      final assigned = _parseStringList(user['IdSucursalesAsignadas']);
      if (assigned.contains(branchId)) {
        result.add(userId);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _parseMapList(dynamic rawValue) {
    final result = <Map<String, dynamic>>[];
    dynamic source = rawValue;

    if (source is String) {
      final raw = source.trim();
      if (raw.isEmpty) return result;
      if (raw.startsWith('[') && raw.endsWith(']')) {
        try {
          source = jsonDecode(raw);
        } catch (_) {
          return result;
        }
      } else {
        return result;
      }
    }

    if (source is! Iterable) return result;

    for (final item in source) {
      if (item is Map<String, dynamic>) {
        result.add(Map<String, dynamic>.from(item));
        continue;
      }
      if (item is Map) {
        result.add(item.map((k, v) => MapEntry(k.toString(), v)));
        continue;
      }
      if (item is String) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            result.add(Map<String, dynamic>.from(decoded));
          } else if (decoded is Map) {
            result.add(decoded.map((k, v) => MapEntry(k.toString(), v)));
          }
        } catch (_) {}
      }
    }

    return result;
  }

  List<String> _extractComboProductIds(dynamic rawItems) {
    final items = _parseMapList(rawItems);
    final productIds = <String>[];
    for (final item in items) {
      final value =
          item['productoId']?.toString() ??
          item['productId']?.toString() ??
          item['IdProducto']?.toString() ??
          '';
      final productId = value.trim();
      if (productId.isNotEmpty && !productIds.contains(productId)) {
        productIds.add(productId);
      }
    }
    return productIds;
  }

  List<Map<String, dynamic>> _buildComboItemsPayload({
    required List<String> productIds,
    required String comboId,
    required List<Map<String, dynamic>> existingItems,
  }) {
    final existingByProduct = <String, Map<String, dynamic>>{};
    for (final item in existingItems) {
      final value =
          item['productoId']?.toString() ??
          item['productId']?.toString() ??
          item['IdProducto']?.toString() ??
          '';
      final productId = value.trim();
      if (productId.isNotEmpty && !existingByProduct.containsKey(productId)) {
        existingByProduct[productId] = item;
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return List<Map<String, dynamic>>.generate(productIds.length, (index) {
      final productId = productIds[index];
      final existing = existingByProduct[productId];

      final idComboItem = existing?['idComboItem']?.toString().trim() ?? '';
      final itemComboId = existing?['comboId']?.toString().trim() ?? '';
      final itemVariantId = existing?['variantId']?.toString() ?? '';
      final itemTipoUnidad = existing?['tipounidad']?.toString().trim() ?? '';
      final cantidadRaw = existing?['cantidad'];

      num cantidad = 1;
      if (cantidadRaw is num) {
        cantidad = cantidadRaw;
      } else if (cantidadRaw != null) {
        cantidad = num.tryParse(cantidadRaw.toString()) ?? 1;
      }

      return {
        'idComboItem': idComboItem.isNotEmpty
            ? idComboItem
            : 'combo_item_${timestamp}_$index',
        'comboId': comboId.isNotEmpty ? comboId : itemComboId,
        'productoId': productId,
        'variantId': itemVariantId,
        'cantidad': cantidad,
        'tipounidad': itemTipoUnidad.isNotEmpty ? itemTipoUnidad : 'UNIDAD',
      };
    });
  }

  Map<String, dynamic> _normalizePayloadForSubmit(
    EpdDashboardState state,
    Map<String, dynamic> result, {
    Map<String, dynamic>? existingRow,
  }) {
    final payload = Map<String, dynamic>.from(result);

    if (state.activeSection == 'expense_categories') {
      final normalizedName =
          (payload['name'] ?? payload['nombre'])?.toString().trim() ?? '';
      payload['name'] = normalizedName;
      payload.remove('nombre');
      payload.remove('descripcion');

      final activeRaw = payload['isActive'] ?? payload['activo'];
      if (activeRaw is bool) {
        payload['isActive'] = activeRaw ? 1 : 0;
      } else {
        payload['isActive'] = int.tryParse(activeRaw?.toString() ?? '') ?? 1;
      }
      payload.remove('activo');
      return payload;
    }

    if (state.activeSection == 'expenses') {
      payload['categoryId'] =
          (payload['categoryId'] ?? payload['IdTipoGasto'])
              ?.toString()
              .trim() ??
          '';
      payload.remove('IdTipoGasto');

      payload['description'] =
          (payload['description'] ?? payload['descripcion'])
              ?.toString()
              .trim() ??
          '';
      payload.remove('descripcion');

      final rawAmount = payload['amount'] ?? payload['monto'];
      if (rawAmount is num) {
        payload['amount'] = rawAmount.toDouble();
      } else {
        payload['amount'] = double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
      }
      payload.remove('monto');

      final rawDate = payload['date'] ?? payload['fecha'];
      payload['date'] = (rawDate?.toString().trim().isNotEmpty ?? false)
          ? rawDate.toString().trim()
          : DateTime.now().toIso8601String();
      payload.remove('fecha');

      final activeRaw =
          payload['estado'] ?? payload['isActive'] ?? payload['activo'];
      if (activeRaw is bool) {
        payload['estado'] = activeRaw ? 1 : 0;
      } else {
        payload['estado'] = int.tryParse(activeRaw?.toString() ?? '') ?? 1;
      }
      payload.remove('isActive');
      payload.remove('activo');

      final categoryId = payload['categoryId']?.toString().trim() ?? '';
      if (categoryId.isNotEmpty) {
        final options = state.getDropdownOptions('expense_categories');
        Map<String, dynamic>? matched;
        for (final option in options) {
          if (option['value']?.toString() == categoryId) {
            matched = option;
            break;
          }
        }
        if (matched != null) {
          payload['categoryName'] = matched['label']?.toString() ?? '';
        }
      }
      return payload;
    }

    if (state.activeSection == 'branches') {
      // Solo para UI de sucursales; no debe persistirse en el documento branch.
      payload.remove('assigned_seller_ids');
      payload.remove('Idvendedor');
      payload.remove('seller_id');
      return payload;
    }

    if (state.activeSection != 'combos') return payload;

    // Normalizar alias legacy -> esquema canÃ³nico de combos usado por la app mÃ³vil.
    final comboName = (payload['nombre'] ?? payload['NombreCombo'])
        ?.toString()
        .trim();
    if (comboName != null && comboName.isNotEmpty) {
      payload['nombre'] = comboName;
    }
    payload.remove('NombreCombo');

    final rawPrice = payload['precioCombo'] ?? payload['precio'];
    if (rawPrice is num) {
      payload['precioCombo'] = rawPrice.toDouble();
    } else if (rawPrice != null) {
      payload['precioCombo'] = double.tryParse(rawPrice.toString()) ?? 0.0;
    } else {
      payload['precioCombo'] = 0.0;
    }
    payload.remove('precio');

    final selectedProductIds = _parseStringList(
      payload.remove('productos_combo'),
    );
    final existingItems = _parseMapList(existingRow?['items']);
    final comboId =
        existingRow?['id']?.toString() ?? payload['id']?.toString() ?? '';

    payload['items'] = _buildComboItemsPayload(
      productIds: selectedProductIds,
      comboId: comboId,
      existingItems: existingItems,
    );

    return payload;
  }

  Map<String, dynamic> _buildDialogInitialData(
    EpdDashboardState state,
    Map<String, dynamic> row,
  ) {
    if (state.activeSection == 'expense_categories') {
      final initialData = Map<String, dynamic>.from(row);
      if ((initialData['name'] == null ||
              initialData['name'].toString().isEmpty) &&
          initialData['nombre'] != null) {
        initialData['name'] = initialData['nombre'];
      }

      final activeValue = initialData['isActive'] ?? initialData['activo'];
      if (activeValue is bool) {
        initialData['isActive'] = activeValue ? 1 : 0;
      } else if (activeValue != null) {
        initialData['isActive'] = int.tryParse(activeValue.toString()) ?? 1;
      } else {
        initialData['isActive'] = 1;
      }
      initialData.remove('activo');
      return initialData;
    }

    if (state.activeSection == 'expenses') {
      final initialData = Map<String, dynamic>.from(row);
      if ((initialData['categoryId'] == null ||
              initialData['categoryId'].toString().isEmpty) &&
          initialData['IdTipoGasto'] != null) {
        initialData['categoryId'] = initialData['IdTipoGasto'];
      }
      if ((initialData['description'] == null ||
              initialData['description'].toString().isEmpty) &&
          initialData['descripcion'] != null) {
        initialData['description'] = initialData['descripcion'];
      }
      if (initialData['amount'] == null && initialData['monto'] != null) {
        initialData['amount'] = initialData['monto'];
      }
      if (initialData['date'] == null && initialData['fecha'] != null) {
        initialData['date'] = initialData['fecha'];
      }
      if (initialData['estado'] == null) {
        final activeRaw = initialData['isActive'] ?? initialData['activo'];
        if (activeRaw is bool) {
          initialData['estado'] = activeRaw ? 1 : 0;
        } else {
          initialData['estado'] =
              int.tryParse(activeRaw?.toString() ?? '') ?? 1;
        }
      }
      initialData.remove('IdTipoGasto');
      initialData.remove('descripcion');
      initialData.remove('monto');
      initialData.remove('fecha');
      initialData.remove('isActive');
      initialData.remove('activo');
      return initialData;
    }

    if (state.activeSection == 'branches') {
      final initialData = Map<String, dynamic>.from(row);
      initialData['assigned_seller_ids'] = _getAssignedSellerIdsForBranch(
        state,
        row,
      );
      return initialData;
    }

    if (state.activeSection != 'combos') {
      return Map<String, dynamic>.from(row);
    }

    final initialData = Map<String, dynamic>.from(row);
    if ((initialData['nombre'] == null || initialData['nombre'] == '') &&
        initialData['NombreCombo'] != null) {
      initialData['nombre'] = initialData['NombreCombo'];
    }
    if (initialData['precioCombo'] == null && initialData['precio'] != null) {
      initialData['precioCombo'] = initialData['precio'];
    }
    initialData.remove('NombreCombo');
    initialData.remove('precio');
    initialData['productos_combo'] = _extractComboProductIds(row['items']);
    return initialData;
  }

  Future<void> _showCreateDialog(EpdDashboardState state) async {
    if (_isCreateDisabled(state.activeSection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La creación está deshabilitada para esta sección.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (state.activeSection == 'branches' &&
        state.selectedEmpresas.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para crear una sucursal debes seleccionar exactamente 1 empresa en el contexto.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Plantilla base por secciÃ³n (robusta, no depende de state.data.first)
    final initialData = _getBaseFieldsForSection(state.activeSection);

    // Inyectar automÃ¡ticamente el contexto activo (empresa seleccionada, filtros de bÃºsqueda)
    final contextHidden = <String>[];

    // Si hay una sola empresa seleccionada, se inyecta como empresaId
    if (state.selectedEmpresas.length == 1) {
      final empresaId =
          state.selectedEmpresas.first['value']?.toString() ??
          state.selectedEmpresas.first['id']?.toString() ??
          '';
      if (empresaId.isNotEmpty) {
        initialData['empresaId'] = empresaId;
        contextHidden.add('empresaId');
      }
    }

    // Si hay un filtro de bÃºsqueda activo, tambiÃ©n se inyecta y oculta
    if (state.searchField != null &&
        state.searchValue != null &&
        state.searchValue!.isNotEmpty) {
      initialData[state.searchField!] = state.searchValue!;
      contextHidden.add(state.searchField!);
    }

    // Lista combinada de ocultos: sistema + contexto ya inyectado.
    final hiddenFields = [
      ..._hiddenSystemFields,
      if (state.activeSection == 'branches') 'empresaId',
      ...contextHidden,
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: initialData,
        isEdit: false,
        title: 'Crear en ${state.activeSectionLabel}',
        fieldSchemas: _buildFieldSchemas(state),
        hiddenFields: hiddenFields,
        onUploadImage: _uploadImageToStorage,
      ),
    );

    if (result != null && mounted) {
      final notifier = ref.read(epdDashboardProvider.notifier);
      final payload = _normalizePayloadForSubmit(state, result);
      String? error;

      if (state.activeSection == 'branches') {
        final selectedSellerIds = _parseStringList(
          result['assigned_seller_ids'],
        );
        final createResult = await notifier.createItemWithId(payload);
        error = createResult.error;

        if (error == null) {
          final branchId = createResult.id?.trim() ?? '';
          if (branchId.isNotEmpty) {
            final syncError = await notifier.syncBranchSellerAssignments(
              branchId: branchId,
              sellerIds: selectedSellerIds,
              empresaId: payload['empresaId']?.toString(),
            );
            error = syncError;
          } else {
            error =
                'La sucursal se creó, pero no se obtuvo el ID para asignar vendedores.';
          }
        }
      } else {
        error = await notifier.createItem(payload);
      }

      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento creado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final state = ref.read(epdDashboardProvider);
    final initialData = _buildDialogInitialData(state, row);
    final hiddenFields = [
      ..._hiddenSystemFields,
      if (state.activeSection == 'branches') 'empresaId',
    ];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: initialData,
        isEdit: true,
        title: 'Editar Documento',
        fieldSchemas: _buildFieldSchemas(state),
        hiddenFields: hiddenFields,
        onUploadImage: _uploadImageToStorage,
      ),
    );

    if (result != null && mounted) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: El documento no tiene ID')),
        );
        return;
      }

      final notifier = ref.read(epdDashboardProvider.notifier);
      final payload = _normalizePayloadForSubmit(
        state,
        result,
        existingRow: row,
      );
      String? error = await notifier.updateItem(id, payload);

      if (error == null && state.activeSection == 'branches') {
        final selectedSellerIds = _parseStringList(
          result['assigned_seller_ids'],
        );
        error = await notifier.syncBranchSellerAssignments(
          branchId: id,
          sellerIds: selectedSellerIds,
          empresaId:
              payload['empresaId']?.toString() ?? row['empresaId']?.toString(),
        );
      }

      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento actualizado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '¿Eliminar documento?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esta acción es irreversible. ¿Seguro que deseas eliminar el registro permanentemente?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final error = await ref
          .read(epdDashboardProvider.notifier)
          .deleteItem(id);
      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  /// DiÃ¡logo para ajuste atÃ³mico de stock de inventario.
  /// Llama al endpoint POST /inventario-ajuste que en un Batch:
  ///   1) Actualiza el campo `stock` del documento en `inventory`
  ///   2) Crea un registro de auditorÃ­a en `inventory_transactions`
  Future<void> _showInventoryAdjustDialog(Map<String, dynamic> row) async {
    final cantidadCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final observacionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final productoId =
        row['IdProducto']?.toString() ??
        row['idProducto']?.toString() ??
        row['id']?.toString() ??
        '';
    final sucursalId =
        row['IdSucursal']?.toString() ?? row['idSucursal']?.toString() ?? '';
    final empresaId =
        row['IdEmpresa']?.toString() ??
        row['idEmpresa']?.toString() ??
        row['empresaId']?.toString() ??
        '';
    final nombreProducto =
        row['nombre']?.toString() ?? row['name']?.toString() ?? productoId;
    final stockActual = row['stock']?.toString() ?? '?';

    final confirm = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(28),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.swap_vert_circle_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajustar Stock',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '$nombreProducto - Stock actual: $stockActual',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Cantidad
                Text(
                  'CANTIDAD (positiva = entrada, negativa = salida)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: cantidadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ej: 10 o -5',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa la cantidad';
                    }
                    if (double.tryParse(v.trim()) == null) {
                      return 'Debe ser un número válido';
                    }
                    if (double.parse(v.trim()) == 0) {
                      return 'La cantidad no puede ser cero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Motivo
                Text(
                  'MOTIVO',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: motivoCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ej: Compra, Merma, Ajuste inicial...',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa el motivo del ajuste';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ObservaciÃ³n (opcional)
                Text(
                  'OBSERVACIÓN (opcional)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: observacionCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Detalle adicional...',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Acciones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Aplicar Ajuste',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, {
                            'IdProducto': productoId,
                            'IdSucursal': sucursalId,
                            'IdEmpresa': empresaId,
                            'cantidad': double.parse(cantidadCtrl.text.trim()),
                            'motivo': motivoCtrl.text.trim(),
                            'observacion': observacionCtrl.text.trim(),
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    cantidadCtrl.dispose();
    motivoCtrl.dispose();
    observacionCtrl.dispose();

    if (confirm != null && mounted) {
      final error = await ref
          .read(epdDashboardProvider.notifier)
          .adjustInventory(confirm);
      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ajuste de inventario aplicado con éxito'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      }
    }
  }

  Widget _buildPaginationBar(
    int totalItems,
    int totalPages,
    int start,
    int end,
    bool hasServerMore,
    VoidCallback onLoadMore,
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
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
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
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              _paginationBtn(
                Icons.chevron_right_rounded,
                ((_currentPage + 1) * _pageSize) <
                        ref.read(epdDashboardProvider).data.length ||
                    hasServerMore,
                () {
                  final stateDataLength = ref
                      .read(epdDashboardProvider)
                      .data
                      .length;
                  final nextStartIndex = (_currentPage + 1) * _pageSize;

                  if (nextStartIndex >= stateDataLength && hasServerMore) {
                    onLoadMore();
                  } else if (nextStartIndex < stateDataLength) {
                    setState(() => _currentPage++);
                  }
                },
              ),
              const SizedBox(width: 4),
              _paginationBtn(
                Icons.last_page_rounded,
                false, // Desactivado para evitar bloqueos
                () {},
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

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              final s = ref.read(epdDashboardProvider);
              ref
                  .read(epdDashboardProvider.notifier)
                  .selectSection(s.activeSection);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
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
}
