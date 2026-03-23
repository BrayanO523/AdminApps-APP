import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/resolvable_state.dart';

/// TextStyles cacheados — se crean UNA sola vez, no en cada build.
class _Styles {
  _Styles._();
  static final header = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF475569),
    letterSpacing: 0.3,
  );
  static final cell = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF1E293B),
  );
  static final cellMuted = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF94A3B8),
  );
  static final boolText = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF1E293B),
    fontWeight: FontWeight.w500,
  );
  static final badgeBlue = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF0369A1),
    fontWeight: FontWeight.w500,
  );
  static final badgeGreenFiltered = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF166534),
    fontWeight: FontWeight.w500,
  );
  static final chipLabel = GoogleFonts.outfit(
    fontSize: 12,
    color: const Color(0xFF166534),
    fontWeight: FontWeight.w500,
  );
  static final viewBtn = GoogleFonts.outfit(
    fontSize: 12,
    color: const Color(0xFF475569),
    fontWeight: FontWeight.w500,
  );
  static final dialogTitle = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF0F172A),
  );
  static final dialogSub = GoogleFonts.outfit(
    fontSize: 12,
    color: const Color(0xFF94A3B8),
  );
  static final dialogKey = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF475569),
  );
  static final dialogVal = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF0369A1),
  );
  static final emptyTitle = GoogleFonts.outfit(
    fontSize: 15,
    color: const Color(0xFF94A3B8),
  );
  static final dateText = GoogleFonts.outfit(
    fontSize: 13,
    color: const Color(0xFF475569),
  );
}

/// Tabla dinámica optimizada con styles cacheados y rebuilds mínimos.
class DynamicDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ResolvableState dashboardState;
  final Map<String, String> activeFilters;
  final void Function(String column, String rawValue)? onFilterToggle;
  final void Function(Map<String, dynamic> row)? onEdit;
  final void Function(Map<String, dynamic> row)? onDelete;
  final void Function(Map<String, dynamic> row)? onSelectContext;
  final bool Function(Map<String, dynamic> row)? isContextSelected;
  /// Acción extra opcional por fila (p. ej. "Ajustar Stock" para inventory).
  final void Function(Map<String, dynamic> row)? onExtraAction;
  final IconData? extraActionIcon;
  final Color? extraActionColor;
  final String? extraActionTooltip;

  const DynamicDataTable({
    super.key,
    required this.data,
    required this.dashboardState,
    this.activeFilters = const {},
    this.onFilterToggle,
    this.onEdit,
    this.onDelete,
    this.onSelectContext,
    this.isContextSelected,
    this.onExtraAction,
    this.extraActionIcon,
    this.extraActionColor,
    this.extraActionTooltip,
  });

  @override
  State<DynamicDataTable> createState() => _DynamicDataTableState();
}

class _DynamicDataTableState extends State<DynamicDataTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _horizontalController = ScrollController();

  // Cache de columnas para evitar recalcular en cada build
  List<String>? _cachedColumns;
  int _lastDataHash = 0;

  /// Workaround para un assert intermitente de SelectionContainer en Flutter Web.
  Widget _withSafeSelection(Widget child) {
    if (kIsWeb) return child;
    return SelectionArea(child: child);
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  List<String> _getColumns() {
    // Generar un hash basado en las llaves del primer documento + la longitud
    final firstRowKeys = widget.data.isNotEmpty
        ? widget.data.first.keys.join(',')
        : '';
    final currentHash = Object.hash(widget.data.length, firstRowKeys);

    if (_cachedColumns != null && _lastDataHash == currentHash) {
      return _cachedColumns!;
    }

    _cachedColumns = _extractColumns(widget.data);
    _lastDataHash = currentHash;
    return _cachedColumns!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text('No hay datos para mostrar', style: _Styles.emptyTitle),
          ],
        ),
      );
    }

    final columns = _getColumns();
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // ── Vista Móvil: Cards ──
    if (isMobile) {
      return _buildMobileCards(columns);
    }

    // ── Vista Desktop: DataTable ──
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SizedBox(
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: _withSafeSelection(
                    DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF1F5F9),
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return const Color(0xFFF0F9FF);
                        }
                        return Colors.white;
                      }),
                      dividerThickness: 1,
                      columnSpacing: 24,
                      horizontalMargin: 20,
                      headingRowHeight: 48,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: double.infinity,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                      columns: [
                        if (widget.onEdit != null ||
                            widget.onDelete != null ||
                            widget.onSelectContext != null)
                          DataColumn(
                            label: Text('ACCIONES', style: _Styles.header),
                          ),
                        ...columns.map((col) {
                          return DataColumn(
                            label: Text(
                              _formatColumnName(col),
                              style: _Styles.header,
                            ),
                            onSort: (i, asc) {
                              setState(() {
                                _sortColumnIndex = i;
                                _sortAscending = asc;
                              });
                            },
                          );
                        }),
                      ],
                      rows: _buildRows(columns),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Vista de Cards para pantallas móviles.
  Widget _buildMobileCards(List<String> columns) {
    final data = List<Map<String, dynamic>>.from(widget.data);
    // Máximo de campos visibles sin expandir
    const previewCount = 4;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = data[index];
        // Campos a mostrar (excluyendo 'id' del preview pero mostrándolo como header)
        final fieldsToShow = columns.where((c) => c != 'id').toList();
        final hasMore = fieldsToShow.length > previewCount;

        return _MobileCard(
          row: row,
          columns: fieldsToShow,
          previewCount: previewCount,
          hasMore: hasMore,
          idValue: row['id']?.toString(),
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onSelectContext: widget.onSelectContext,
          isContextSelected: widget.isContextSelected,
          buildCell: _buildCell,
          formatColumnName: _formatColumnName,
        );
      },
    );
  }

  List<DataRow> _buildRows(List<String> columns) {
    final data = List<Map<String, dynamic>>.from(widget.data);

    final actionOffset = (widget.onEdit != null || widget.onDelete != null)
        ? 1
        : 0;

    if (_sortColumnIndex != null) {
      final colIndex = _sortColumnIndex! - actionOffset;
      if (colIndex >= 0 && colIndex < columns.length) {
        final key = columns[colIndex];
        data.sort((a, b) {
          final va = _displayStr(key, a[key]);
          final vb = _displayStr(key, b[key]);
          return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
        });
      }
    }

    return List.generate(data.length, (i) {
      final row = data[i];
      return DataRow(
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFFF0F9FF);
          }
          return i.isEven ? Colors.white : const Color(0xFFFAFBFC);
        }),
        cells: [
          if (widget.onEdit != null ||
              widget.onDelete != null ||
              widget.onSelectContext != null ||
              widget.onExtraAction != null)
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onSelectContext != null) ...[
                    Builder(
                      builder: (context) {
                        final isSelected =
                            widget.isContextSelected?.call(row) ?? false;
                        return IconButton(
                          icon: Icon(Icons.check_circle_rounded, size: 20),
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade400,
                          tooltip: isSelected
                              ? 'Contexto Seleccionado'
                              : 'Seleccionar contexto',
                          onPressed: () => widget.onSelectContext!(row),
                        );
                      },
                    ),
                  ],
                  if (widget.onExtraAction != null)
                    IconButton(
                      icon: Icon(
                        widget.extraActionIcon ?? Icons.tune_rounded,
                        size: 18,
                      ),
                      color: widget.extraActionColor ??
                          const Color(0xFF059669),
                      tooltip: widget.extraActionTooltip ?? 'Acción',
                      onPressed: () => widget.onExtraAction!(row),
                    ),
                  if (widget.onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: const Color(0xFF0EA5E9),
                      tooltip: 'Editar documento',
                      onPressed: () => widget.onEdit!(row),
                    ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: Colors.red.shade400,
                      tooltip: 'Eliminar documento',
                      onPressed: () => widget.onDelete!(row),
                    ),
                ],
              ),
            ),
          ...List.generate(columns.length, (j) {
            return DataCell(_buildCell(columns[j], row[columns[j]]));
          }),
        ],
      );
    });
  }

  String _displayStr(String field, dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    return widget.dashboardState.isResolvableField(field)
        ? widget.dashboardState.resolveId(field, s)
        : s;
  }

  /// Mapeo de tipos de transacciones a etiquetas legibles.
  static const _transactionTypes = {
    'in_stock': 'Entrada',
    'out_sale': 'Venta',
    'out_damage': 'Merma',
    'in_return': 'Devolución',
    'transfer_in': 'Traslado Entrada',
    'transfer_out': 'Traslado Salida',
    'adjustment': 'Ajuste',
    'initial': 'Inventario Inicial',
  };

  Widget _buildCell(String field, dynamic value) {
    if (value == null) return Text('—', style: _Styles.cellMuted);

    if (value is Map) {
      if (value.containsKey('_seconds') && value.containsKey('_nanoseconds')) {
        return _timestampCell(value);
      }
      return _mapButton(field, value);
    }
    if (value is List) return _listCell(field, value);
    if (value is bool) return _boolCell(value);

    final str = value.toString();
    final fieldLower = field.toLowerCase();

    // Indicador visual de Color (hex)
    if (fieldLower == 'color' &&
        (str.startsWith('0x') || str.startsWith('#'))) {
      return _colorCell(str);
    }

    // Mapeo de tipo de transacción
    if (fieldLower == 'type' || fieldLower == 'tipo') {
      final label = _transactionTypes[str];
      if (label != null) {
        return Text(label, style: _Styles.cell);
      }
    }

    // ID resolvible → badge clickable
    if (widget.dashboardState.isResolvableField(field)) {
      final name = widget.dashboardState.resolveId(field, str);
      if (name != str) {
        final isFiltered = widget.activeFilters[field] == str;
        return _idBadge(field, str, name, isFiltered);
      }
    }

    // Detectar JSON array stringificado (p.ej. "[\"id1\",\"id2\"]")
    if (str.startsWith('[') && str.endsWith(']')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return _jsonArrayCell(field, decoded);
        }
      } catch (_) {
        // No es JSON válido: se trata como string normal
      }
    }

    // Detectar URLs (imágenes, links)
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return _imageCell(str);
    }

    return Text(str, style: _Styles.cell, softWrap: true);
  }

  /// Renderiza un JSON array stringificado como badge clickeable.
  Widget _jsonArrayCell(String field, List<dynamic> items) {
    if (items.isEmpty) return Text('—', style: _Styles.cellMuted);
    return Tooltip(
      message: items.map((e) => e.toString()).join(', '),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showVariantsDialog(field, items),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
                size: 13,
                color: Color(0xFF0EA5E9),
              ),
              const SizedBox(width: 5),
              Text(
                '${items.length} elemento${items.length == 1 ? '' : 's'}',
                style: _Styles.badgeBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renderiza un indicador visual de color con el código hex.
  Widget _colorCell(String hexStr) {
    Color color;
    try {
      if (hexStr.startsWith('#')) {
        final hex = hexStr.replaceFirst('#', '');
        color = Color(int.parse('FF$hex', radix: 16));
      } else {
        color = Color(int.parse(hexStr));
      }
    } catch (_) {
      return Text(hexStr, style: _Styles.cell);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 8),
        Text(hexStr, style: _Styles.cellMuted),
      ],
    );
  }

  Widget _imageCell(String url) {
    return Tooltip(
      message: 'Ver imagen completa',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showFullImage(context, url),
          child: Container(
            height: 36,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boolCell(bool value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: value ? const Color(0xFF10B981) : Colors.red.shade400,
        ),
        const SizedBox(width: 6),
        Text(value ? 'Sí' : 'No', style: _Styles.boolText),
      ],
    );
  }

  /// Convierte un Firestore Timestamp Map a fecha legible.
  Widget _timestampCell(Map<dynamic, dynamic> tsMap) {
    try {
      final seconds = tsMap['_seconds'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      final formatted =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(formatted, style: _Styles.dateText),
        ],
      );
    } catch (_) {
      return Text(tsMap.toString(), style: _Styles.cell);
    }
  }

  Widget _idBadge(String field, String rawId, String name, bool isFiltered) {
    return Tooltip(
      message: isFiltered
          ? 'Click para quitar filtro'
          : 'Click para filtrar por "$name"',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onFilterToggle?.call(field, rawId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isFiltered
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isFiltered
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFBAE6FD),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFiltered)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    size: 12,
                    color: Color(0xFF16A34A),
                  ),
                ),
              Text(
                name,
                style: isFiltered
                    ? _Styles.badgeGreenFiltered
                    : _Styles.badgeBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapButton(String field, Map<dynamic, dynamic> map) {
    if (map.isEmpty) return Text('—', style: _Styles.cellMuted);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showMapDialog(field, map),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text('Ver ${map.length} items', style: _Styles.viewBtn),
          ],
        ),
      ),
    );
  }

  void _showMapDialog(String fieldName, Map<dynamic, dynamic> map) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.list_alt_rounded,
                        size: 18,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatColumnName(fieldName),
                            style: _Styles.dialogTitle,
                          ),
                          Text(
                            '${map.length} elementos',
                            style: _Styles.dialogSub,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: _withSafeSelection(
                  ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    itemCount: map.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final entry = map.entries.elementAt(i);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? const Color(0xFFF8FAFC)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${entry.key}',
                                style: _Styles.dialogKey,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${entry.value}',
                                  style: _Styles.dialogVal,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVariantsDialog(String fieldName, List<dynamic> items) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.view_list_rounded,
                        size: 18,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatColumnName(fieldName),
                            style: _Styles.dialogTitle,
                          ),
                          Text(
                            '${items.length} elementos',
                            style: _Styles.dialogSub,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Content ──
              Flexible(
                child: _withSafeSelection(
                  ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is Map) {
                        return _variantCard(i, item);
                      }
                      // Fallback for non-map items
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(item.toString(), style: _Styles.cell),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogCtx) => Stack(
        children: [
          // Imagen con zoom/pan
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar la imagen',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botón cerrar
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantCard(int index, Map<dynamic, dynamic> variant) {
    // Buscar si hay una URL de imagen y si es una variante
    String? imageUrl;
    bool isVariant = false;

    for (final key in variant.keys) {
      final lower = key.toString().toLowerCase();

      // Chequeo de variante
      if (lower == 'variantid' ||
          lower == 'variant_id' ||
          lower == 'variant id') {
        final val = variant[key]?.toString().trim() ?? '';
        if (val.isNotEmpty && val != '—' && val != '-') {
          isVariant = true;
        }
      }

      // Chequeo de foto
      if (lower.contains('photo') ||
          lower.contains('image') ||
          lower.contains('img') ||
          lower.contains('logo')) {
        final val = variant[key]?.toString() ?? '';
        if (val.startsWith('http')) {
          imageUrl = val;
        }
      }
    }

    final titlePrefix = isVariant ? 'Variante' : 'Producto';
    final colorPrefix = isVariant
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF8B5CF6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorPrefix,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$titlePrefix ${index + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          // ── Image preview si existe (clickable para ver completa) ──
          if (imageUrl != null)
            GestureDetector(
              onTap: () => _showFullImage(context, imageUrl!),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Color(0xFF94A3B8),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      // Overlay con ícono de expandir
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ── Campos key-value ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              children: variant.entries.map((entry) {
                final key = entry.key.toString();
                final value = entry.value?.toString() ?? '—';
                final isUrl = value.startsWith('http');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          _formatColumnName(key),
                          style: _Styles.dialogKey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isUrl
                            ? Text(
                                value,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF0369A1),
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  value,
                                  style: _Styles.dialogVal,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCell(String field, List<dynamic> list) {
    if (list.isEmpty) return Text('—', style: _Styles.cellMuted);

    if (list.any((item) => item is Map)) {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showVariantsDialog(field, list),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.view_list_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text('Ver ${list.length} items', style: _Styles.viewBtn),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: list.map((item) {
        final rawStr = item.toString().trim();
        final display = widget.dashboardState.isResolvableField(field)
            ? widget.dashboardState.resolveId(field, rawStr)
            : rawStr;
        return Tooltip(
          message: 'Filtrar por "$display"',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onFilterToggle?.call(field, rawStr),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(display, style: _Styles.chipLabel),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Columnas técnicas ocultas — no se muestran en la tabla.
  static const _hiddenColumns = {
    'id',
    'createdAt',
    'createdBy',
    'updatedAt',
    'updatedBy',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
    'creadoEn',
    'creadoPor',
    'actualizadoEn',
    'actualizadoPor',
    'sync_status',
    'last_update_cloud',
    'lastUpdateCloud',
    'inventory_id',
    'id_venta',
    'creado_offline',
    'creado_por',
    'fecha_creacion',
    'last_updated_cloud',
    // IDs de referencia interna (carwash)
    'adminId',
    'IdUsuario',
    'IdSucursalesAsignadas',
    'empresaId',
    'empresa_id',
    'sucursalId',
    'clienteId',
    'tipoLavadoId',
    'categoriaId',
    'CategoryId',
    // IDs de referencia interna (EPD)
    'companyId',
    'branchId',
    'branch_id',
    'branch_origin_id',
    'branch_destination_id',
    'seller_id',
    'user_id',
    'product_id',
    'supplier_id',
    'category_id',
    'categoryId',
    'client_id',
  };

  /// Mapeo de nombres técnicos de columna → etiquetas legibles en español.
  static const _columnLabels = {
    // Carwash
    'empresaId': 'Empresa',
    'empresa_id': 'Empresa',
    'sucursalId': 'Sucursal',
    'clienteId': 'Cliente',
    'tipoLavadoId': 'Tipo de Lavado',
    'categoriaId': 'Categoría',
    'CodigoUsuario': 'Código Usuario',
    'IdSucursalesAsignadas': 'Sucursales Asignadas',
    'IdUsuario': 'ID Usuario',
    'NombreCompleto': 'Nombre Completo',
    'NombreCategoria': 'Categoría',
    'OrdenVisual': 'Orden Visual',
    'nombreComercial': 'Nombre Comercial',
    'razonSocial': 'Razón Social',
    'adminId': 'Administrador',
    'activo': 'Activo',
    // EPD
    'companyId': 'Empresa',
    'branchId': 'Sucursal',
    'branch_id': 'Sucursal',
    'branch_origin_id': 'Sucursal Origen',
    'branch_destination_id': 'Sucursal Destino',
    'seller_id': 'Vendedor',
    'user_id': 'Usuario',
    'product_id': 'Producto',
    'product_name': 'Nombre Producto',
    'supplier_id': 'Proveedor',
    'supplier_name': 'Nombre Proveedor',
    'category_id': 'Categoría',
    'categoryId': 'Categoría',
    'client_name': 'Nombre Cliente',
    'client_id': 'Cliente',
    'sale_date': 'Fecha de Venta',
    'total_amount': 'Monto Total',
    'payment_method': 'Método de Pago',
    'quantity': 'Cantidad',
    'unit_price': 'Precio Unitario',
    'current_stock': 'Stock Actual',
    'min_stock': 'Stock Mínimo',
    'max_stock': 'Stock Máximo',
    'transaction_date': 'Fecha Transacción',
    'transfer_date': 'Fecha Traslado',
    'waste_date': 'Fecha Merma',
    'type': 'Tipo',
    'reason': 'Motivo',
    'notes': 'Notas',
    'status': 'Estado',
  };

  /// Detecta si un campo es un ID de referencia puro (que no aporta al usuario final).
  static bool _isRawIdField(String key) {
    final k = key.trim();
    // Exactamente 'id' (case-insensitive)
    if (k.toLowerCase() == 'id') return true;
    // Termina en 'Id' (camelCase: empresaId, sucursalId…)
    if (k.endsWith('Id') && k.length > 2) return true;
    // Termina en '_id' (snake_case: product_id, branch_id…)
    if (k.endsWith('_id') && k.length > 3) return true;
    // Empieza con 'id_' (id_venta, id_usuario…)
    if (k.toLowerCase().startsWith('id_') && k.length > 3) return true;
    // Todo en mayúsculas terminado en 'ID' (categoryID, productID…)
    if (k.endsWith('ID') && k.length > 2) return true;
    // Empieza con 'Id' + mayúscula (IdSucursal, IdUsuario, IdEmpresa…)
    if (k.length > 2 &&
        k.startsWith('Id') &&
        k[2] == k[2].toUpperCase() &&
        k[2] != '_')
      return true;
    return false;
  }

  List<String> _extractColumns(List<Map<String, dynamic>> data) {
    final allKeys = <String>{};
    for (final row in data) {
      allKeys.addAll(row.keys);
    }
    allKeys.removeWhere((key) {
      final lowerKey = key.toLowerCase();
      // Ocultar columnas explícitamente listadas
      if (_hiddenColumns.any((hidden) => hidden.toLowerCase() == lowerKey)) {
        return true;
      }
      // Ocultar automáticamente cualquier campo que sea un ID de referencia crudo
      if (_isRawIdField(key)) return true;
      return false;
    });
    final sorted = allKeys.toList();

    sorted.sort((a, b) {
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

    return sorted;
  }

  String _formatColumnName(String key) {
    // Primero buscar en el mapeo de etiquetas
    final label = _columnLabels[key];
    if (label != null) return label;
    // Fallback: convertir camelCase/snake_case a título
    final result = key
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return result[0].toUpperCase() + result.substring(1);
  }
}

/// Card para vista móvil — muestra un documento con campos apilados verticalmente.
class _MobileCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<String> columns;
  final int previewCount;
  final bool hasMore;
  final String? idValue;
  final void Function(Map<String, dynamic> row)? onEdit;
  final void Function(Map<String, dynamic> row)? onDelete;
  final void Function(Map<String, dynamic> row)? onSelectContext;
  final bool Function(Map<String, dynamic> row)? isContextSelected;
  final Widget Function(String field, dynamic value) buildCell;
  final String Function(String key) formatColumnName;

  const _MobileCard({
    required this.row,
    required this.columns,
    required this.previewCount,
    required this.hasMore,
    this.idValue,
    this.onEdit,
    this.onDelete,
    this.onSelectContext,
    this.isContextSelected,
    required this.buildCell,
    required this.formatColumnName,
  });

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleCols = _expanded
        ? widget.columns
        : widget.columns.take(widget.previewCount).toList();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header con acciones (ID oculto al usuario final) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                if (widget.onSelectContext != null)
                  Builder(
                    builder: (context) {
                      final isSelected =
                          widget.isContextSelected?.call(widget.row) ?? false;
                      return SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                          ),
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade400,
                          padding: EdgeInsets.zero,
                          tooltip: isSelected
                              ? 'Contexto Seleccionado'
                              : 'Seleccionar',
                          onPressed: () => widget.onSelectContext!(widget.row),
                        ),
                      );
                    },
                  ),
                if (widget.onEdit != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      color: const Color(0xFF0EA5E9),
                      padding: EdgeInsets.zero,
                      tooltip: 'Editar',
                      onPressed: () => widget.onEdit!(widget.row),
                    ),
                  ),
                if (widget.onDelete != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      color: Colors.red.shade400,
                      padding: EdgeInsets.zero,
                      tooltip: 'Eliminar',
                      onPressed: () => widget.onDelete!(widget.row),
                    ),
                  ),
              ],
            ),
          ),

          // ── Campos del documento ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: visibleCols.map((col) {
                final value = widget.row[col];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          widget.formatColumnName(col),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: widget.buildCell(col, value)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Botón expandir/colapsar ──
          if (widget.hasMore)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Ver menos'
                          : 'Ver ${widget.columns.length - widget.previewCount} campos más',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
