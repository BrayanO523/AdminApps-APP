import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/models/carwash_dashboard_state.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashFilterBar extends ConsumerWidget {
  final CarwashDashboardState state;
  final VoidCallback onClearFilters;
  final bool Function(String key) isRawIdField;

  const CarwashFilterBar({
    super.key,
    required this.state,
    required this.onClearFilters,
    required this.isRawIdField,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = <String>{};
    for (final row in state.data) {
      columns.addAll(row.keys);
    }

    final visibleColumns = columns.where((column) => !isRawIdField(column)).toList()
      ..sort();
    visibleColumns.remove('id');
    visibleColumns.removeWhere(
      (column) => [
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
    );

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleColumns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final column = visibleColumns[index];
          final isActive = state.searchField == column && state.searchValue != null;
          final values = _extractValues(column);

          return Center(
            child: PopupMenuButton<String>(
              tooltip: 'Filtrar por $column',
              onSelected: (value) {
                if (value == '__CLEAR__') {
                  onClearFilters();
                  return;
                }
                ref
                    .read(carwashDashboardProvider.notifier)
                    .applyFilter(column, value);
              },
              constraints: const BoxConstraints(maxHeight: 350, maxWidth: 300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              itemBuilder: (_) => _buildMenuItems(
                column: column,
                values: values,
                isActive: isActive,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          ? '$column: ${_resolveLabel(column, state.searchValue ?? '')}'
                          : column,
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

  List<PopupMenuEntry<String>> _buildMenuItems({
    required String column,
    required List<String> values,
    required bool isActive,
  }) {
    final items = <PopupMenuEntry<String>>[];

    if (isActive) {
      items.add(
        PopupMenuItem(
          value: '__CLEAR__',
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 16, color: Colors.red.shade400),
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

    for (final value in values) {
      final selected = isActive && state.searchValue == value;
      final displayName = _resolveLabel(column, value);
      final label = displayName.length > 40
          ? '${displayName.substring(0, 40)}...'
          : displayName;
      items.add(
        PopupMenuItem(
          value: value,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected
                  ? const Color(0xFF0EA5E9)
                  : const Color(0xFF1E293B),
            ),
          ),
        ),
      );
    }

    return items;
  }

  List<String> _extractValues(String column) {
    final values = <String>{};
    for (final row in state.data) {
      final value = row[column];
      if (value == null) continue;
      if (value is Iterable) {
        for (final item in value) {
          final raw = item?.toString().trim() ?? '';
          if (raw.isNotEmpty) values.add(raw);
        }
      } else {
        final raw = value.toString().trim();
        if (raw.isNotEmpty) values.add(raw);
      }
    }
    return values.toList()..sort();
  }

  String _resolveLabel(String column, String rawValue) {
    if (!state.isResolvableField(column)) return rawValue;
    return state.resolveId(column, rawValue);
  }
}
