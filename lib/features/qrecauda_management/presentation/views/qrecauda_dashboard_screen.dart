import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/qrecauda_section.dart';
import '../config/qrecauda_collection_form_registry.dart';
import '../mappers/qrecauda_collection_payload_mapper.dart';
import '../viewmodels/qrecauda_dashboard_viewmodel.dart';
import '../widgets/qrecauda_sidebar.dart';
import '../../../shared/presentation/widgets/dynamic_data_table.dart';
import '../../../shared/presentation/widgets/dynamic_form_dialog.dart';

class QRecaudaDashboardScreen extends ConsumerStatefulWidget {
  const QRecaudaDashboardScreen({super.key});

  @override
  ConsumerState<QRecaudaDashboardScreen> createState() =>
      _QRecaudaDashboardScreenState();
}

class _QRecaudaDashboardScreenState
    extends ConsumerState<QRecaudaDashboardScreen> {
  final _searchController = TextEditingController();
  String? _selectedSearchField;
  String _localSearchText = '';
  static const int _pageSize = 20;
  int _currentPage = 0;

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
      ref
          .read(qrecaudaDashboardProvider.notifier)
          .selectSection('municipalidades');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Detecta si un campo es un ID crudo para ocultarlo de filtros textuales.
  static bool _isRawIdField(String key) {
    final k = key.trim();
    if (k.toLowerCase() == 'id') return true;
    if (k.endsWith('Id') && k.length > 2) return true;
    if (k.endsWith('_id') && k.length > 3) return true;
    if (k.toLowerCase().startsWith('id_') && k.length > 3) return true;
    if (k.endsWith('ID') && k.length > 2) return true;
    if (k.length > 2 &&
        k.startsWith('Id') &&
        k[2] == k[2].toUpperCase() &&
        k[2] != '_') {
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
    ref.read(qrecaudaDashboardProvider.notifier).applyFilter(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qrecaudaDashboardProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    ref.listen<QRecaudaDashboardState>(qrecaudaDashboardProvider, (
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
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
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
                              isContextSelected: (row) => state
                                  .selectedMunicipalidades
                                  .any((e) => e['id'] == row['id']),
                              onSelectContext:
                                  state.activeSection == 'municipalidades'
                                  ? (row) {
                                      final isSelected = state
                                          .selectedMunicipalidades
                                          .any((e) => e['id'] == row['id']);
                                      ref
                                          .read(
                                            qrecaudaDashboardProvider.notifier,
                                          )
                                          .selectMunicipalidadContext(row);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isSelected
                                                ? 'Municipalidad ${row['nombre'] ?? row['name'] ?? ''} deseleccionada.'
                                                : 'Municipalidad ${row['nombre'] ?? row['name'] ?? ''} seleccionada.',
                                          ),
                                          backgroundColor: isSelected
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFD97706),
                                        ),
                                      );
                                    }
                                  : null,
                              onEdit: (row) => _showEditDialog(row),
                              onDelete: (row) => _showDeleteDialog(row),
                              onFilterToggle: (column, rawValue) {
                                ref
                                    .read(qrecaudaDashboardProvider.notifier)
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
                                .read(qrecaudaDashboardProvider.notifier)
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
            child: QRecaudaSidebar(onItemTap: () => Navigator.pop(context)),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const QRecaudaSidebar(),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    QRecaudaDashboardState state,
    bool hasFilters,
    bool isMobile,
  ) {
    final section = qrecaudaSections.firstWhere(
      (s) => s.id == state.activeSection,
      orElse: () => qrecaudaSections.first,
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
        if (state.selectedMunicipalidades.isNotEmpty) ...[
          SizedBox(width: isMobile ? 6 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 14,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    state.selectedMunicipalidades.length == 1
                        ? (state.selectedMunicipalidades.first['nombre']
                                  ?.toString() ??
                              state.selectedMunicipalidades.first['name']
                                  ?.toString() ??
                              state.selectedMunicipalidades.first['razonSocial']
                                  ?.toString() ??
                              'Municipalidad')
                        : '${state.selectedMunicipalidades.length} Municipalidades',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    ref
                        .read(qrecaudaDashboardProvider.notifier)
                        .clearMunicipalidadContext();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFFB45309),
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
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total: ${state.totalItems}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: hasFilters
                    ? const Color(0xFF92400E)
                    : const Color(0xFFB45309),
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
              .read(qrecaudaDashboardProvider.notifier)
              .selectSection(state.activeSection);
        }),
        const SizedBox(width: 12),
        if (state.activeSection == 'usuarios' && !isMobile)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => _showCreateAdminDialog(),
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              label: Text(
                'Crear Admin',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (isMobile)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.activeSection == 'usuarios')
                IconButton(
                  onPressed: state.isLoading ? null : _showCreateAdminDialog,
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 24,
                  ),
                  color: const Color(0xFF1E3A8A),
                  tooltip: 'Crear Admin',
                ),
              IconButton(
                onPressed: state.isLoading
                    ? null
                    : () => _showCreateDialog(state),
                icon: const Icon(Icons.add_circle_rounded, size: 28),
                color: const Color(0xFFD97706),
                tooltip: 'Crear Documento',
              ),
            ],
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
              backgroundColor: const Color(0xFFD97706),
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

  Widget _buildFilterBar(QRecaudaDashboardState state) {
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
                      .read(qrecaudaDashboardProvider.notifier)
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
                              ? const Color(0xFFD97706)
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
                      ? const Color(0xFFD97706).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFD97706)
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
                          ? const Color(0xFFD97706)
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
                            ? const Color(0xFFD97706)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isActive
                          ? const Color(0xFFD97706)
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

  Future<void> _showCreateDialog(QRecaudaDashboardState state) async {
    final sectionId = state.activeSection;
    final template = state.data.isNotEmpty
        ? state.data.first
        : <String, dynamic>{};

    final initialData = <String, dynamic>{
      ...QRecaudaCollectionFormRegistry.baseFieldsForSection(sectionId),
    };
    for (final key in template.keys) {
      if (key == 'id') continue;
      if (initialData.containsKey(key)) continue;
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
    final fieldSchemas = QRecaudaCollectionFormRegistry.buildFieldSchemas(
      sectionId: sectionId,
      state: state,
    );
    final hiddenFields =
        QRecaudaCollectionFormRegistry.hiddenSystemFieldsForSection(
          sectionId,
          isEdit: false,
        );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: initialData,
        isEdit: false,
        title: 'Crear en ${state.activeSectionLabel}',
        fieldSchemas: fieldSchemas.isEmpty ? null : fieldSchemas,
        hiddenFields: hiddenFields,
      ),
    );

    if (result != null && mounted) {
      final payload = QRecaudaCollectionPayloadMapper.fromFormToApi(
        sectionId: sectionId,
        state: state,
        formData: result,
      );
      final error = await ref
          .read(qrecaudaDashboardProvider.notifier)
          .createItem(payload);
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

  Future<void> _showCreateAdminDialog() async {
    final state = ref.read(qrecaudaDashboardProvider);
    if (state.selectedMunicipalidades.length != 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona exactamente 1 municipalidad de contexto para crear el admin.',
          ),
          backgroundColor: Color(0xFFB45309),
        ),
      );
      return;
    }

    final municipalidad = state.selectedMunicipalidades.first;
    final municipalidadId = municipalidad['id']?.toString().trim() ?? '';
    if (municipalidadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La municipalidad seleccionada no tiene ID valido.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool showPassword = false;
    String? mercadoId;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            'Crear Admin [DEV]',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Municipalidad: ${municipalidad['nombre'] ?? municipalidad['name'] ?? municipalidadId}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setLocalState(() => showPassword = !showPassword),
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: mercadoId,
                  decoration: const InputDecoration(
                    labelText: 'Mercado (opcional)',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin mercado'),
                    ),
                    ...state.mercadoNames.entries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: (value) => mercadoId = value,
                ),
                const SizedBox(height: 8),
                Text(
                  '* Esta accion crea usuario en Auth y documento en usuarios.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final error = await ref
                    .read(qrecaudaDashboardProvider.notifier)
                    .createAdminUser(
                      nombre: nombreCtrl.text,
                      email: emailCtrl.text,
                      password: passCtrl.text,
                      municipalidadId: municipalidadId,
                      mercadoId: mercadoId,
                    );
                if (!ctx.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text('Crear Admin'),
            ),
          ],
        ),
      ),
    );

    nombreCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin creado exitosamente.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final state = ref.read(qrecaudaDashboardProvider);
    final sectionId = state.activeSection;
    final formData = QRecaudaCollectionPayloadMapper.fromApiToForm(
      sectionId: sectionId,
      row: row,
    );
    final fieldSchemas = QRecaudaCollectionFormRegistry.buildFieldSchemas(
      sectionId: sectionId,
      state: state,
    );
    final hiddenFields =
        QRecaudaCollectionFormRegistry.hiddenSystemFieldsForSection(
          sectionId,
          isEdit: true,
        );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: formData,
        isEdit: true,
        title: 'Editar Documento',
        fieldSchemas: fieldSchemas.isEmpty ? null : fieldSchemas,
        hiddenFields: hiddenFields,
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

      final payload = QRecaudaCollectionPayloadMapper.fromFormToApi(
        sectionId: sectionId,
        state: state,
        formData: result,
      );

      final error = await ref
          .read(qrecaudaDashboardProvider.notifier)
          .updateItem(id, payload);
      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> row) async {
    final name =
        row['nombre'] ?? row['name'] ?? row['razonSocial'] ?? 'este documento';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Eliminar Documento',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Estás seguro que deseas eliminar $name? Esta acción no se puede deshacer.',
          style: GoogleFonts.outfit(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return;

      final error = await ref
          .read(qrecaudaDashboardProvider.notifier)
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

  Widget _buildError(String errorMessage) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Ocurrió un error',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final state = ref.read(qrecaudaDashboardProvider);
                ref
                    .read(qrecaudaDashboardProvider.notifier)
                    .selectSection(state.activeSection);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.black.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(
    int totalItems,
    int totalPages,
    int startIdx,
    int endIdx,
    bool loadMoreAvail,
    VoidCallback loadMore,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: const Color(0xFFD97706),
            disabledColor: Colors.grey.shade300,
            tooltip: 'Página anterior',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 16),
          Text(
            '${startIdx + 1} - ${endIdx > totalItems ? totalItems : endIdx} '
            'de ${totalItems}${loadMoreAvail ? '+' : ''} '
            '(${_currentPage + 1} / $totalPages)',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : (loadMoreAvail
                      ? () {
                          loadMore();
                        }
                      : null),
            icon: const Icon(Icons.chevron_right_rounded),
            color: const Color(0xFFD97706),
            disabledColor: Colors.grey.shade300,
            tooltip: 'Página siguiente',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
