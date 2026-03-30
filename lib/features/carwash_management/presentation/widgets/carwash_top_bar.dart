import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/models/carwash_dashboard_state.dart';
import '../../domain/entities/carwash_section.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashTopBar extends ConsumerWidget {
  final CarwashDashboardState state;
  final bool hasFilters;
  final bool isMobile;
  final TextEditingController searchController;
  final String? selectedSearchField;
  final ValueChanged<String?> onSearchFieldChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;
  final Widget Function(IconData icon, VoidCallback onTap) iconButtonBuilder;

  const CarwashTopBar({
    super.key,
    required this.state,
    required this.hasFilters,
    required this.isMobile,
    required this.searchController,
    required this.selectedSearchField,
    required this.onSearchFieldChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onClearFilters,
    required this.iconButtonBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = carwashSections.firstWhere(
      (item) => item.id == state.activeSection,
      orElse: () => carwashSections.first,
    );
    final showCreateButton = section.allowCreate;

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
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => iconButtonBuilder(Icons.menu_rounded, () {
                Scaffold.of(ctx).openDrawer();
              }),
            )
          else
            iconButtonBuilder(Icons.arrow_back_rounded, () {
              context.go('/dashboard');
            }),
          SizedBox(width: isMobile ? 8 : 16),
          Icon(
            section.icon,
            size: isMobile ? 20 : 24,
            color: const Color(0xFF0F172A),
          ),
          SizedBox(width: isMobile ? 6 : 12),
          Flexible(
            child: Text(
              state.activeSectionLabel,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 16 : 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.selectedEmpresas.isNotEmpty) ...[
            SizedBox(width: isMobile ? 6 : 12),
            Flexible(child: _SelectedCompaniesBadge(state: state)),
          ],
          SizedBox(width: isMobile ? 6 : 12),
          if (!state.isLoading &&
              state.errorMessage == null &&
              !section.usesCustomView)
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
          if (!isMobile && (state.data.isNotEmpty || state.searchField != null))
            _DesktopSearch(
              state: state,
              searchController: searchController,
              selectedSearchField: selectedSearchField,
              onSearchFieldChanged: onSearchFieldChanged,
              onSearchChanged: onSearchChanged,
            ),
          SizedBox(width: isMobile ? 8 : 12),
          if (hasFilters)
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: Text(
                'Limpiar filtro',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          iconButtonBuilder(Icons.refresh_rounded, () {
            ref
                .read(carwashDashboardProvider.notifier)
                .selectSection(state.activeSection);
          }),
          const SizedBox(width: 12),
          if (showCreateButton)
            if (isMobile)
              IconButton(
                onPressed: state.isLoading ? null : onCreate,
                icon: const Icon(Icons.add_circle_rounded, size: 28),
                color: const Color(0xFF0EA5E9),
                tooltip: 'Crear Documento',
              )
            else
              ElevatedButton.icon(
                onPressed: state.isLoading ? null : onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Crear Documento',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SelectedCompaniesBadge extends ConsumerWidget {
  final CarwashDashboardState state;

  const _SelectedCompaniesBadge({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
                      state.selectedEmpresas.first['name']?.toString() ??
                      state.selectedEmpresas.first['razonSocial']?.toString() ??
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
              ref.read(carwashDashboardProvider.notifier).clearEmpresaContext();
            },
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSearch extends StatelessWidget {
  final CarwashDashboardState state;
  final TextEditingController searchController;
  final String? selectedSearchField;
  final ValueChanged<String?> onSearchFieldChanged;
  final ValueChanged<String> onSearchChanged;

  const _DesktopSearch({
    required this.state,
    required this.searchController,
    required this.selectedSearchField,
    required this.onSearchFieldChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              controller: searchController,
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
              onChanged: onSearchChanged,
              onSubmitted: onSearchChanged,
            ),
          ),
          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSearchField,
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
                onChanged: onSearchFieldChanged,
                items: _buildColumns()
                    .map(
                      (column) => DropdownMenuItem<String>(
                        value: column,
                        child: Text(column),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildColumns() {
    final columns = <String>{};
    for (final row in state.data) {
      columns.addAll(row.keys);
    }

    final list = columns
        .where((column) => !_isRawIdField(column))
        .where(
          (column) => ![
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
          ].contains(column),
        )
        .toList();

    list.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aIsName =
          aLower.contains('nombre') || aLower == 'name' || aLower.contains('razon');
      final bIsName =
          bLower.contains('nombre') || bLower == 'name' || bLower.contains('razon');
      if (aIsName == bIsName) return aLower.compareTo(bLower);
      return aIsName ? -1 : 1;
    });
    return list;
  }

  bool _isRawIdField(String key) {
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
}
