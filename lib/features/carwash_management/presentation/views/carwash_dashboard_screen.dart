import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/carwash_section.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';
import '../widgets/carwash_sidebar.dart';
import '../../../shared/presentation/widgets/dynamic_data_table.dart';
import '../../../shared/presentation/widgets/dynamic_form_dialog.dart';

class CarwashDashboardScreen extends ConsumerStatefulWidget {
  const CarwashDashboardScreen({super.key});

  @override
  ConsumerState<CarwashDashboardScreen> createState() =>
      _CarwashDashboardScreenState();
}

class _CarwashDashboardScreenState
    extends ConsumerState<CarwashDashboardScreen> {
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
      ref.read(carwashDashboardProvider.notifier).selectSection('empresas');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Igual que en DynamicDataTable: detecta si un campo es un ID de referencia crudo.
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
    // Si hay una empresa seleccionada y no estamos en la sección de empresas,
    // re-aplicar el filtro de empresaId en lugar de limpiar todo.
    final state = ref.read(carwashDashboardProvider);
    if (state.selectedEmpresas.isNotEmpty &&
        state.activeSection != 'empresas') {
      final empresasIdStr = state.selectedEmpresas
          .map((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .join(',');
      ref
          .read(carwashDashboardProvider.notifier)
          .applyFilter(
            'empresa_id',
            empresasIdStr.isNotEmpty ? empresasIdStr : null,
          );
    } else {
      ref.read(carwashDashboardProvider.notifier).applyFilter(null, null);
    }
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
                  child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
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
                              isContextSelected: (row) =>
                                  state.selectedEmpresas.any(
                                    (e) =>
                                        e['id']?.toString() ==
                                        row['id']?.toString(),
                                  ),
                              onSelectContext: state.activeSection == 'empresas'
                                  ? (row) {
                                      final isSelected = state.selectedEmpresas
                                          .any(
                                            (e) =>
                                                e['id']?.toString() ==
                                                row['id']?.toString(),
                                          );
                                      ref
                                          .read(
                                            carwashDashboardProvider.notifier,
                                          )
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
                                              : const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  : null,
                              onEdit: (row) => _showEditDialog(row),
                              onDelete: (row) => _showDeleteDialog(row),
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
                          () {
                            ref
                                .read(carwashDashboardProvider.notifier)
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

  Widget _buildTopBar(
    CarwashDashboardState state,
    bool hasFilters,
    bool isMobile,
  ) {
    final section = carwashSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => carwashSections.first,
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
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 14,
                  color: Color(0xFF16A34A),
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
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    ref
                        .read(carwashDashboardProvider.notifier)
                        .clearEmpresaContext();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF16A34A),
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
                  : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total: ${state.totalItems}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: hasFilters
                    ? const Color(0xFF92400E)
                    : const Color(0xFF0369A1),
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
                // Separador
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                // Dropdown de Columnas para el buscador
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
              .read(carwashDashboardProvider.notifier)
              .selectSection(state.activeSection);
        }),
        const SizedBox(width: 12),
        if (isMobile)
          IconButton(
            onPressed: state.isLoading ? null : () => _showCreateDialog(state),
            icon: const Icon(Icons.add_circle_rounded, size: 28),
            color: const Color(0xFF0EA5E9),
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
              backgroundColor: const Color(0xFF0EA5E9),
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

  Widget _buildFilterBar(CarwashDashboardState state) {
    // Extraer columnas únicas de los datos
    final columnas = <String>{};
    for (final row in state.data) {
      columnas.addAll(row.keys);
    }
    // Excluir campos de ID y campos técnicos del filtro visible
    final listaColumnas = columnas.where((col) => !_isRawIdField(col)).toList()
      ..sort();
    listaColumnas.remove('id');
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
                      .read(carwashDashboardProvider.notifier)
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
                              ? const Color(0xFF0EA5E9)
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
                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF0EA5E9)
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
                          ? const Color(0xFF0EA5E9)
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
                            ? const Color(0xFF0EA5E9)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isActive
                          ? const Color(0xFF0EA5E9)
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

  Future<void> _showCreateDialog(CarwashDashboardState state) async {
    // Tomamos la primera fila como plantilla si existe, si no, mapa vacío
    final template = state.data.isNotEmpty
        ? state.data.first
        : <String, dynamic>{};
    final initialData = <String, dynamic>{};
    for (final key in template.keys) {
      if (key == 'id') continue;
      // Solo inferir nulos para primitivas
      if (template[key] is int) {
        initialData[key] = 0;
      } else if (template[key] is double) {
        initialData[key] = 0.0;
      } else if (template[key] is bool) {
        initialData[key] = false;
      } else if (template[key] is String) {
        initialData[key] = '';
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: initialData,
        isEdit: false,
        title: 'Crear en ${state.activeSectionLabel}',
      ),
    );

    if (result != null && mounted) {
      final error = await ref
          .read(carwashDashboardProvider.notifier)
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: row,
        isEdit: true,
        title: 'Editar Documento',
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
          .read(carwashDashboardProvider.notifier)
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
          .read(carwashDashboardProvider.notifier)
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
                        ref.read(carwashDashboardProvider).data.length ||
                    hasServerMore,
                () {
                  final stateDataLength = ref
                      .read(carwashDashboardProvider)
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
                false, // Desactivado para evitar bloqueos si la API no reporta la longitud exacta localmente
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
              final s = ref.read(carwashDashboardProvider);
              ref
                  .read(carwashDashboardProvider.notifier)
                  .selectSection(s.activeSection);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
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
