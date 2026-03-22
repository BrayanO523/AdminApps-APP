import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _localSearchText = '';
  static const int _pageSize = 20;
  int _currentPage = 0;

  /// Filtra los datos localmente por texto (case-insensitive contains).
  List<Map<String, dynamic>> _applyLocalFilter(
    List<Map<String, dynamic>> data,
  ) {
    if (_localSearchText.isEmpty || _selectedSearchField == null) return data;
    final query = _localSearchText.toLowerCase();
    final field = _selectedSearchField!;
    return data.where((row) {
      final val = row[field];
      if (val == null) return false;
      if (val is Iterable) {
        return val.any((item) => item.toString().toLowerCase().contains(query));
      }
      return val.toString().toLowerCase().contains(query);
    }).toList();
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
    // Empieza con 'Id' + mayúscula (IdSucursal, IdUsuario, IdEmpresa…)
    if (k.length > 2 &&
        k.startsWith('Id') &&
        k[2] == k[2].toUpperCase() &&
        k[2] != '_')
      return true;
    return false;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _localSearchText = '';
      _selectedSearchField = null;
    });
    // Si hay una empresa seleccionada y no estamos en la sección de companies,
    // re-aplicar el filtro de empresaId en lugar de limpiar todo.
    final state = ref.read(epdDashboardProvider);
    if (state.selectedEmpresas.isNotEmpty &&
        state.activeSection != 'companies') {
      final empresasIdStr = state.selectedEmpresas
          .map((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .join(',');
      ref
          .read(epdDashboardProvider.notifier)
          .applyFilter(
            'empresaId',
            empresasIdStr.isNotEmpty ? empresasIdStr : null,
          );
    } else {
      ref.read(epdDashboardProvider.notifier).applyFilter(null, null);
    }
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
          _localSearchText = '';
          _selectedSearchField = null;
        });
      }
    });

    final hasFilters = state.searchField != null && state.searchValue != null;
    final isLocalFiltered = _localSearchText.isNotEmpty;
    final filteredData = _applyLocalFilter(state.data);

    final totalItemsCount = isLocalFiltered
        ? filteredData.length
        : (state.totalItems > 0 ? state.totalItems : filteredData.length);
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
                              // Botón extra para ajuste atómico de stock
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
        // Búsqueda Textual — Solo desktop
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
                    onChanged: (value) {
                      setState(() => _localSearchText = value);
                    },
                    onSubmitted: (value) {
                      setState(() => _localSearchText = value);
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
            onPressed: state.isLoading ? null : () => _showCreateDialog(state),
            icon: const Icon(Icons.add_circle_rounded, size: 28),
            color: const Color(0xFF8B5CF6),
            tooltip: 'Crear Documento',
          )
        else
          ElevatedButton.icon(
            onPressed: state.isLoading ? null : () => _showCreateDialog(state),
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
    // Excluir campos de ID y técnicos del filtro visible al usuario
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

  Map<String, DynamicFormFieldSchema> _buildFieldSchemas(EpdDashboardState state) {
    switch (state.activeSection) {
      // ── Sucursales ────────────────────────────────────────────────────────
      case 'branches':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'allowed_categories': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            options: state.getDropdownOptions('categories'),
            label: 'Categorías Permitidas',
          ),
        };

      // ── Usuarios ──────────────────────────────────────────────────────────
      case 'users':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
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
          'IdSucursalesAsignadas': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('branches'),
            label: 'Sucursales Asignadas',
          ),
        };

      // ── Categorías ────────────────────────────────────────────────────────
      case 'categories':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'color': DynamicFormFieldSchema(
            type: DynamicFormFieldType.colorPicker,
            label: 'Color de Categoría',
          ),
        };

      // ── Productos ─────────────────────────────────────────────────────────
      case 'products':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'IdCategoria': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('categories'),
            label: 'Categoría',
          ),
          'fotoUrl': DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Producto',
          ),
          'ModoVventa': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': 'UNIDAD', 'label': 'Por Unidad'},
              {'value': 'LB', 'label': 'Por Libra'},
              {'value': 'AMBOS', 'label': 'Ambos'},
            ],
            label: 'Modo de Venta',
          ),
          'is_promo': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '0', 'label': 'No es Promoción'},
              {'value': '1', 'label': 'Sí es Promoción'},
            ],
            label: '¿En Promoción?',
          ),
        };

      // ── Combos ────────────────────────────────────────────────────────────
      case 'combos':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'sucursales_asignadas': DynamicFormFieldSchema(
            type: DynamicFormFieldType.multiselectDropdown,
            options: state.getDropdownOptions('branches'),
            label: 'Sucursales Disponibles',
          ),
          'fotoUrl': DynamicFormFieldSchema(
            type: DynamicFormFieldType.imageUpload,
            label: 'Foto del Combo',
          ),
        };

      // ── Clientes ──────────────────────────────────────────────────────────
      case 'clients':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
        };

      // ── Proveedores ───────────────────────────────────────────────────────
      case 'suppliers':
        return {
          'empresaId': DynamicFormFieldSchema(
            type: DynamicFormFieldType.dropdown,
            options: state.getDropdownOptions('companies'),
            label: 'Empresa',
          ),
          'esGlobal': DynamicFormFieldSchema(
            type: DynamicFormFieldType.radioSelect,
            options: const [
              {'value': '0', 'label': 'Proveedor Local'},
              {'value': '1', 'label': 'Proveedor Global'},
            ],
            label: '¿Alcance del Proveedor?',
          ),
        };

      // ── Asignaciones de Proveedores ───────────────────────────────────────
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
        };

      default:
        return {};
    }
  } // fin de _buildFieldSchemas

  // ── Lista global de campos de sistema que el admin NUNCA debe ver ni tocar ──
  static const _hiddenSystemFields = [
    // SQLite offline-only
    'creado_offline', 'modificado_offline', 'SYNC_STATUS',
    // Timestamps gestionados por el backend
    'last_modified', 'last_updated_cloud', 'fechacreacion',
    'fecha_creacion_registro',
    // Auditoría interna
    'creado_por', 'modificado_por', 'idusuario', 'Idvendedor',
    // Banderas y contadores internos del motor móvil
    'activo', 'Activo', 'estado', 'Favorito', 'OrdenFavorito',
    'contador_ventas', 'isTemplate', 'source_template_id',
    'sync_status', 'control_inventario', 'clientes_enabled',
    'pesos_rapidos_enabled', 'adminId',
    // IDs canónicos autogenerados por el backend al crear
    'IdProducto', 'IdCategoria', 'IdCombo', 'IdInventario',
    'IdTransaccion', 'IdVenta', 'IdCliente', 'IdUsuario',
    // Autogenerados (no debe llenar el admin)
    'CodigoSucursal',
    // Campos de usuario que no aplican en el formulario
    'selected_categories',
    // Legacy ID (se rellena automáticamente en backend desde IdSucursalesAsignadas)
    'IdSucursal',
  ];

  /// Devuelve los campos base requeridos por cada colección, para que el formulario
  /// de creación funcione aunque la tabla esté completamente vacía.
  Map<String, dynamic> _getBaseFieldsForSection(String section) {
    switch (section) {
      // ── Empresas ──────────────────────────────────────────────────────────
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

      // ── Sucursales (CodigoSucursal autogenerado por backend) ─────────────
      case 'branches':
        return {
          'Nombre': '',
          'direccion_referencia': '',
          'telefono_contacto': '',
          'empresaId': '',
          'adminId': '',
          'allowed_categories': '[]',
          'control_inventario': 1,
          'clientes_enabled': 1,
          'pesos_rapidos_enabled': 0,
          'sync_status': 1,
          'activo': 1,
        };

      // ── Usuarios ──────────────────────────────────────────────────────────
      case 'users':
        return {
          'NombreCompleto': '',
          'CodigoUsuario': '',
          'pin': '',
          'rol': 'VENDEDOR',
          'empresaId': '',
          // IdSucursal y selected_categories están en _hiddenSystemFields;
          // el backend rellena IdSucursal desde IdSucursalesAsignadas[0].
          'IdSucursal': '',
          'IdSucursalesAsignadas': '[]',
          'selected_categories': '[]',
          'activo': 1,
        };

      // ── Clientes ──────────────────────────────────────────────────────────
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

      // ── Categorías ────────────────────────────────────────────────────────
      case 'categories':
        return {
          'NombreCategoria': '',
          'descripcion': '',
          'color': '#3498DB',
          'empresaId': '',
          'activo': 1,
        };

      // ── Productos ─────────────────────────────────────────────────────────
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
          // Campos del motor móvil (ocultos, valores por defecto)
          'Favorito': 0,
          'OrdenFavorito': 0,
          'contador_ventas': 0,
          'Activo': 1,
          'sync_status': 1,
        };

      // ── Combos ────────────────────────────────────────────────────────────
      case 'combos':
        return {
          'NombreCombo': '',
          'descripcion': '',
          'precio': 0.0,
          'fotoUrl': '',
          'sucursales_asignadas': '[]',
          'empresaId': '',
          'activo': 1,
          'sync_status': 1,
        };

      // ── Proveedores ───────────────────────────────────────────────────────
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

      // ── Asignaciones de Proveedores ───────────────────────────────────────
      case 'supplier_assignments':
        return {
          'IdProveedor': '',
          'IdSucursal': '',
          'motivo': '',
          'empresaId': '',
          'activo': 1,
        };

      // Inventario, ventas, mermas, traslados → Solo lectura
      case 'inventory':
      case 'inventory_transactions':
      case 'inventory_transfers':
      case 'sales':
      case 'waste_reports':
      case 'catalog_templates':
      case 'category_templates':
        return {}; // Sin formulario de creación

      default:
        return {};
    }
  }

  Future<void> _showCreateDialog(EpdDashboardState state) async {
    // Plantilla base por sección (robusta, no depende de state.data.first)
    final initialData = _getBaseFieldsForSection(state.activeSection);

    // Inyectar automáticamente el contexto activo (empresa seleccionada, filtros de búsqueda)
    final contextHidden = <String>[];

    // Si hay una sola empresa seleccionada, se inyecta como empresaId
    if (state.selectedEmpresas.length == 1) {
      final empresaId = state.selectedEmpresas.first['value']?.toString()
          ?? state.selectedEmpresas.first['id']?.toString() ?? '';
      if (empresaId.isNotEmpty) {
        initialData['empresaId'] = empresaId;
        contextHidden.add('empresaId');
      }
    }

    // Si hay un filtro de búsqueda activo, también se inyecta y oculta
    if (state.searchField != null && state.searchValue != null && state.searchValue!.isNotEmpty) {
      initialData[state.searchField!] = state.searchValue!;
      contextHidden.add(state.searchField!);
    }

    // Lista combinada de ocultos: sistema + contexto ya inyectado
    final hiddenFields = [..._hiddenSystemFields, ...contextHidden];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: initialData,
        isEdit: false,
        title: 'Crear en ${state.activeSectionLabel}',
        fieldSchemas: _buildFieldSchemas(state),
        hiddenFields: hiddenFields,
      ),
    );

    if (result != null && mounted) {
      final error = await ref
          .read(epdDashboardProvider.notifier)
          .createItem(result);
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: row,
        isEdit: true,
        title: 'Editar Documento',
        fieldSchemas: _buildFieldSchemas(state),
        hiddenFields: _hiddenSystemFields,
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

      final error = await ref
          .read(epdDashboardProvider.notifier)
          .updateItem(id, result);
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

  /// Diálogo para ajuste atómico de stock de inventario.
  /// Llama al endpoint POST /inventario-ajuste que en un Batch:
  ///   1) Actualiza el campo `stock` del documento en `inventory`
  ///   2) Crea un registro de auditoría en `inventory_transactions`
  Future<void> _showInventoryAdjustDialog(Map<String, dynamic> row) async {
    final cantidadCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final observacionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final productoId = row['IdProducto']?.toString() ??
        row['idProducto']?.toString() ??
        row['id']?.toString() ??
        '';
    final sucursalId = row['IdSucursal']?.toString() ??
        row['idSucursal']?.toString() ??
        '';
    final empresaId = row['IdEmpresa']?.toString() ??
        row['idEmpresa']?.toString() ??
        row['empresaId']?.toString() ??
        '';
    final nombreProducto = row['nombre']?.toString() ??
        row['name']?.toString() ??
        productoId;
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
                            '$nombreProducto • Stock actual: $stockActual',
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

                // Observación (opcional)
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
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
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
                            'cantidad': double.parse(
                              cantidadCtrl.text.trim(),
                            ),
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
