import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/di/network_provider.dart';

import '../../domain/entities/epd_section.dart';
import '../../data/services/epd_catalog_excel_service.dart';
import '../config/epd_collection_form_registry.dart';
import '../mappers/epd_collection_payload_mapper.dart';
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
  bool _isApplyingExpenseTemplates = false;
  bool _isCatalogImportBusy = false;

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

      throw Exception('La API no devolvio una URL valida de imagen.');
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
    // Empieza con 'Id' + mayÃƒÆ’Ã‚Âºscula (IdSucursal, IdUsuario, IdEmpresa...)
    if (k.length > 2 &&
        k.startsWith('Id') &&
        k[2] == k[2].toUpperCase() &&
        k[2] != '_')
      return true;
    return false;
  }

  static const Set<String> _technicalFilterFields = {
    'createdat',
    'updatedat',
    'created_at',
    'updated_at',
    'creadoen',
    'actualizadoen',
    'sync_status',
    'syncstatus',
    'last_update_cloud',
    'last_updated_cloud',
    'lastupdatecloud',
    'last_modified',
    'creado_offline',
    'modificado_offline',
    'creado_por',
    'modificado_por',
    'fecha_creacion',
    'fecha_creacion_registro',
    'fecha_actualizacion',
    'items',
    'combo_items_editor',
  };

  bool _isSearchableField(String column) {
    final normalized = column.trim();
    if (normalized.isEmpty) return false;
    if (_isRawIdField(normalized)) return false;
    return !_technicalFilterFields.contains(normalized.toLowerCase());
  }

  static const Set<String> _mutableSections = {
    'companies',
    'branches',
    'users',
    'clients',
    'categories',
    'products',
    'combos',
    'expense_categories',
    'expense_category_templates',
    'expenses',
    'suppliers',
    'supplier_assignments',
    'catalog_templates',
    'category_templates',
  };

  bool _isCreateDisabled(String sectionId) =>
      !_mutableSections.contains(sectionId);

  bool _isEditEnabled(String sectionId) => _mutableSections.contains(sectionId);

  Future<void> _withExpenseTemplateApplyLock(
    Future<void> Function() action,
  ) async {
    if (_isApplyingExpenseTemplates || !mounted) return;
    setState(() => _isApplyingExpenseTemplates = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isApplyingExpenseTemplates = false);
      }
    }
  }

  String? _getSingleSelectedEmpresaId(EpdDashboardState state) {
    if (state.selectedEmpresas.length != 1) return null;
    final selected = state.selectedEmpresas.first;
    for (final key in const ['empresaId', 'IdEmpresa', 'id', 'value']) {
      final value = selected[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _handleCatalogExcelAction(
    EpdDashboardState state,
    String action,
  ) async {
    if (_isCatalogImportBusy) return;

    final empresaId = _getSingleSelectedEmpresaId(state);
    if (empresaId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes seleccionar exactamente 1 empresa para usar Catalogo Excel.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCatalogImportBusy = true);
    try {
      if (action == 'download_template') {
        await EpdCatalogExcelService.downloadTemplate();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plantilla Excel descargada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      if (action == 'import_excel') {
        final excelPayload =
            await EpdCatalogExcelService.pickAndParseImportFile();
        if (excelPayload == null) {
          return;
        }
        final dataSource = ref.read(epdDataSourceProvider);
        final previewResult = await dataSource.previewCatalogImport(
          empresaId: empresaId,
          templateVersion: excelPayload.templateVersion,
          categories: excelPayload.categories,
          products: excelPayload.products,
        );

        final previewData = previewResult.fold(
          (failure) => null,
          (data) => data,
        );
        if (previewData == null) {
          final error = previewResult.fold(
            (failure) => failure.message,
            (_) => '',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          return;
        }

        final previewModel = _CatalogImportPreviewModel.fromMap(previewData);
        if (!mounted) return;

        final decisions = await _showCatalogImportPreviewDialog(previewModel);
        if (decisions == null) return;

        final commitResult = await dataSource.commitCatalogImport(
          empresaId: empresaId,
          templateVersion: excelPayload.templateVersion,
          draftToken: previewModel.draftToken,
          categories: excelPayload.categories,
          products: excelPayload.products,
          conflictDecisions: decisions.conflictDecisions,
          invalidPolicy: decisions.invalidPolicy,
        );

        final commitData = commitResult.fold((failure) => null, (data) => data);
        if (commitData == null) {
          final error = commitResult.fold(
            (failure) => failure.message,
            (_) => '',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          return;
        }

        if (!mounted) return;
        final success = commitData['success'] == true;
        if (!success) {
          final message =
              commitData['message']?.toString() ??
              'No se guardaron los datos del archivo.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
          return;
        }

        final createdCounts =
            (commitData['createdCounts'] as Map?)?.cast<String, dynamic>() ??
            const {};
        final updatedCounts =
            (commitData['updatedCounts'] as Map?)?.cast<String, dynamic>() ??
            const {};
        final skippedCounts =
            (commitData['skippedCounts'] as Map?)?.cast<String, dynamic>() ??
            const {};
        final skippedTotal =
            ((skippedCounts['categories'] ?? 0) as num).toInt() +
            ((skippedCounts['products'] ?? 0) as num).toInt();
        final summaryText =
            'Importacion completada. '
            'Categorias +${createdCounts['categories'] ?? 0}/~${updatedCounts['categories'] ?? 0}, '
            'Productos +${createdCounts['products'] ?? 0}/~${updatedCounts['products'] ?? 0}, '
            'Omitidos $skippedTotal.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(summaryText), backgroundColor: Colors.green),
        );

        await ref
            .read(epdDashboardProvider.notifier)
            .refreshAfterExternalImport();
      }
    } on EpdCatalogExcelException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error procesando Catalogo Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCatalogImportBusy = false);
      }
    }
  }

  Future<_CatalogImportDialogResult?> _showCatalogImportPreviewDialog(
    _CatalogImportPreviewModel preview,
  ) async {
    final decisions = <String, String>{};
    for (final row in preview.conflictRows) {
      decisions[row.rowKey] = 'keep_existing';
    }
    var invalidPolicy = preview.invalidRows.isNotEmpty
        ? 'abort_all'
        : 'save_valid_only';

    return showDialog<_CatalogImportDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
        final surfaceMuted = isDark
            ? const Color(0xFF111827)
            : const Color(0xFFF8FAFC);
        final borderColor = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);
        final textPrimary = isDark
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0F172A);
        final textSecondary = isDark
            ? const Color(0xFFCBD5E1)
            : const Color(0xFF475569);

        Widget metricCard({
          required String label,
          required int value,
          required Color accent,
        }) {
          return Container(
            constraints: const BoxConstraints(minWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return Dialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 980,
                  maxHeight: 760,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.table_view_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Preview de Importacion de Catalogo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Revisa conflictos y filas invalidas antes de confirmar.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          metricCard(
                            label: 'Categorias (total)',
                            value: preview.categoriesSummary.total,
                            accent: const Color(0xFF3B82F6),
                          ),
                          metricCard(
                            label: 'Categorias nuevas',
                            value: preview.categoriesSummary.newItems,
                            accent: const Color(0xFF16A34A),
                          ),
                          metricCard(
                            label: 'Conflictos cat.',
                            value: preview.categoriesSummary.conflicts,
                            accent: const Color(0xFFF59E0B),
                          ),
                          metricCard(
                            label: 'Invalidas cat.',
                            value: preview.categoriesSummary.invalid,
                            accent: const Color(0xFFDC2626),
                          ),
                          metricCard(
                            label: 'Productos (total)',
                            value: preview.productsSummary.total,
                            accent: const Color(0xFF3B82F6),
                          ),
                          metricCard(
                            label: 'Productos nuevos',
                            value: preview.productsSummary.newItems,
                            accent: const Color(0xFF16A34A),
                          ),
                          metricCard(
                            label: 'Conflictos prod.',
                            value: preview.productsSummary.conflicts,
                            accent: const Color(0xFFF59E0B),
                          ),
                          metricCard(
                            label: 'Invalidos prod.',
                            value: preview.productsSummary.invalid,
                            accent: const Color(0xFFDC2626),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (preview.conflictRows.isNotEmpty) ...[
                                  Text(
                                    'Conflictos detectados',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...preview.conflictRows.map((row) {
                                    final currentDecision =
                                        decisions[row.rowKey] ??
                                        'keep_existing';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.35),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '[${row.sheetLabel}] fila ${row.rowNumber} - ${row.displayName}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          DropdownButton<String>(
                                            value: currentDecision,
                                            dropdownColor: surface,
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setInnerState(() {
                                                decisions[row.rowKey] = value;
                                              });
                                            },
                                            items: [
                                              DropdownMenuItem(
                                                value: 'keep_existing',
                                                child: Text(
                                                  'Conservar existente',
                                                  style: GoogleFonts.outfit(
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'overwrite',
                                                child: Text(
                                                  'Sobrescribir',
                                                  style: GoogleFonts.outfit(
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF16A34A,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF16A34A,
                                        ).withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: Text(
                                      'No hay conflictos detectados.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (preview.invalidRows.isNotEmpty) ...[
                                  Text(
                                    'Filas invalidas',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...preview.invalidRows.map((row) {
                                    final errors = row.errors.join(' | ');
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFDC2626,
                                        ).withValues(alpha: 0.10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFDC2626,
                                          ).withValues(alpha: 0.35),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '[${row.sheetLabel}] fila ${row.rowNumber} - ${row.displayName}\n$errors',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: textPrimary,
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Politica para filas invalidas:',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  RadioListTile<String>(
                                    value: 'save_valid_only',
                                    groupValue: invalidPolicy,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: const Color(0xFF2563EB),
                                    title: Text(
                                      'Guardar solo filas validas',
                                      style: GoogleFonts.outfit(
                                        color: textPrimary,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setInnerState(
                                        () => invalidPolicy = value,
                                      );
                                    },
                                  ),
                                  RadioListTile<String>(
                                    value: 'abort_all',
                                    groupValue: invalidPolicy,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: const Color(0xFF2563EB),
                                    title: Text(
                                      'No guardar nada',
                                      style: GoogleFonts.outfit(
                                        color: textPrimary,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setInnerState(
                                        () => invalidPolicy = value,
                                      );
                                    },
                                  ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF16A34A,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF16A34A,
                                        ).withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: Text(
                                      'No hay filas invalidas. Se puede confirmar la importacion.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.outfit(
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(
                                context,
                                _CatalogImportDialogResult(
                                  conflictDecisions: decisions,
                                  invalidPolicy: invalidPolicy,
                                ),
                              );
                            },
                            child: Text(
                              'Confirmar Importacion',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
                              // BotÃƒÆ’Ã‚Â³n extra para ajuste atÃƒÆ’Ã‚Â³mico de stock
                              onExtraAction: state.activeSection == 'inventory'
                                  ? (row) {
                                      unawaited(
                                        _showInventoryAdjustDialog(row),
                                      );
                                    }
                                  : state.activeSection ==
                                        'expense_category_templates'
                                  ? (row) {
                                      unawaited(
                                        _showApplyExpenseTemplateDialog(
                                          state,
                                          row,
                                        ),
                                      );
                                    }
                                  : null,
                              extraActionIcon:
                                  state.activeSection == 'inventory'
                                  ? Icons.swap_vert_circle_rounded
                                  : Icons.publish_rounded,
                              extraActionColor:
                                  state.activeSection == 'inventory'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF7C3AED),
                              extraActionTooltip:
                                  state.activeSection == 'inventory'
                                  ? 'Ajustar Stock'
                                  : 'Aplicar a Empresa',
                              onEdit: _isEditEnabled(state.activeSection)
                                  ? (row) => _showEditDialog(row)
                                  : null,
                              onDelete: _isEditEnabled(state.activeSection)
                                  ? (row) => _showDeleteDialog(row)
                                  : null,
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
    final isExpenseTemplateSection =
        state.activeSection == 'expense_category_templates';
    final canApplyExpenseTemplates =
        isExpenseTemplateSection &&
        !state.isLoading &&
        !_isApplyingExpenseTemplates;
    final canCreate =
        !_isCreateDisabled(state.activeSection) && !state.isLoading;
    final canUseCatalogExcel =
        !state.isLoading &&
        !_isCatalogImportBusy &&
        _getSingleSelectedEmpresaId(state) != null;
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
        // BÃƒÆ’Ã‚Âºsqueda textual - solo desktop
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
                        final list = cols.where(_isSearchableField).toList();
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
        PopupMenuButton<String>(
          enabled: canUseCatalogExcel,
          onSelected: (value) {
            unawaited(_handleCatalogExcelAction(state, value));
          },
          tooltip: canUseCatalogExcel
              ? 'Catalogo Excel'
              : 'Selecciona 1 empresa para habilitar Catalogo Excel',
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'download_template',
              child: Text('Descargar plantilla'),
            ),
            PopupMenuItem(value: 'import_excel', child: Text('Importar Excel')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: canUseCatalogExcel
                  ? Colors.white
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canUseCatalogExcel
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCatalogImportBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.table_view_rounded,
                    size: 16,
                    color: canUseCatalogExcel
                        ? const Color(0xFF334155)
                        : const Color(0xFF94A3B8),
                  ),
                const SizedBox(width: 8),
                Text(
                  isMobile ? 'Excel' : 'Catalogo Excel',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canUseCatalogExcel
                        ? const Color(0xFF334155)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: canUseCatalogExcel
                      ? const Color(0xFF334155)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (isMobile)
          if (isExpenseTemplateSection)
            IconButton(
              onPressed: canApplyExpenseTemplates
                  ? () {
                      unawaited(_showApplyAllExpenseTemplatesDialog(state));
                    }
                  : null,
              icon: const Icon(Icons.publish_rounded, size: 24),
              color: const Color(0xFF7C3AED),
              tooltip: 'Aplicar todas las plantillas',
            ),
        if (isMobile)
          IconButton(
            onPressed: canCreate ? () => _showCreateDialog(state) : null,
            icon: const Icon(Icons.add_circle_rounded, size: 28),
            color: const Color(0xFF8B5CF6),
            tooltip: canCreate
                ? 'Crear Documento'
                : 'Creacion deshabilitada para esta seccion',
          )
        else if (isExpenseTemplateSection) ...[
          OutlinedButton.icon(
            onPressed: canApplyExpenseTemplates
                ? () {
                    unawaited(_showApplyAllExpenseTemplatesDialog(state));
                  }
                : null,
            icon: const Icon(Icons.publish_rounded, size: 16),
            label: Text(
              'Aplicar Plantillas',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFF7C3AED)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (!isMobile)
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
    // Excluir campos de ID y tÃƒÆ’Ã‚Â©cnicos del filtro visible al usuario
    final listaColumnas = columnas.where(_isSearchableField).toList()..sort();

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
  ) => EpdCollectionFormRegistry.buildFieldSchemas(
    sectionId: state.activeSection,
    state: state,
  );

  List<String> _hiddenSystemFieldsForSection(String sectionId) =>
      EpdCollectionFormRegistry.hiddenSystemFieldsForSection(sectionId);

  /// Devuelve los campos base requeridos por cada coleccion para formularios de creacion.
  Map<String, dynamic> _getBaseFieldsForSection(String section) =>
      EpdCollectionFormRegistry.baseFields(section);

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
    final payload = EpdCollectionPayloadMapper.fromFormToApi(
      sectionId: state.activeSection,
      state: state,
      formData: result,
    );

    if (state.activeSection == 'branches') {
      // Solo para UI de sucursales; no debe persistirse en el documento branch.
      payload.remove('assigned_seller_ids');
      payload.remove('Idvendedor');
      payload.remove('seller_id');
      return payload;
    }

    if (state.activeSection != 'combos') return payload;

    // Normalizar alias legacy -> esquema canÃƒÆ’Ã‚Â³nico de combos usado por la app mÃƒÆ’Ã‚Â³vil.
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

    final editedItems = _parseMapList(payload.remove('combo_items_editor'));
    final selectedProductIds = editedItems.isNotEmpty
        ? _extractComboProductIds(editedItems)
        : _parseStringList(payload.remove('productos_combo'));
    final existingItems = _parseMapList(existingRow?['items']);
    final comboId =
        existingRow?['idCombo']?.toString() ??
        existingRow?['IdCombo']?.toString() ??
        payload['idCombo']?.toString() ??
        payload['IdCombo']?.toString() ??
        existingRow?['id']?.toString() ??
        payload['id']?.toString() ??
        '';

    if (editedItems.isNotEmpty) {
      final existingByProduct = <String, Map<String, dynamic>>{};
      for (final item in existingItems) {
        final productId = (item['productoId'] ?? item['productId'] ?? '')
            .toString()
            .trim();
        if (productId.isNotEmpty && !existingByProduct.containsKey(productId)) {
          existingByProduct[productId] = item;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      payload['items'] = List<Map<String, dynamic>>.generate(
        editedItems.length,
        (index) {
          final edited = editedItems[index];
          final productId = (edited['productoId'] ?? edited['productId'] ?? '')
              .toString()
              .trim();
          final existing = existingByProduct[productId];

          final idComboItem =
              (edited['idComboItem'] ?? existing?['idComboItem'] ?? '')
                  .toString()
                  .trim();
          final itemComboId = (edited['comboId'] ?? existing?['comboId'] ?? '')
              .toString()
              .trim();
          final itemVariantId =
              (edited['variantId'] ?? existing?['variantId'] ?? '').toString();
          final itemTipoUnidad =
              (edited['tipounidad'] ??
                      edited['tipoUnidad'] ??
                      existing?['tipounidad'] ??
                      '')
                  .toString()
                  .trim();
          final cantidadRaw = edited['cantidad'] ?? edited['quantity'];
          final cantidad = cantidadRaw is num
              ? cantidadRaw
              : num.tryParse(cantidadRaw?.toString() ?? '') ?? 1;

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
        },
      );
    } else {
      payload['items'] = _buildComboItemsPayload(
        productIds: selectedProductIds,
        comboId: comboId,
        existingItems: existingItems,
      );
    }

    return payload;
  }

  Map<String, dynamic> _buildDialogInitialData(
    EpdDashboardState state,
    Map<String, dynamic> row,
  ) {
    final mappedInitial = EpdCollectionPayloadMapper.fromApiToForm(
      sectionId: state.activeSection,
      row: row,
    );

    if (state.activeSection == 'branches') {
      final initialData = Map<String, dynamic>.from(mappedInitial);
      initialData['assigned_seller_ids'] = _getAssignedSellerIdsForBranch(
        state,
        row,
      );
      return initialData;
    }

    if (state.activeSection != 'combos') {
      return Map<String, dynamic>.from(mappedInitial);
    }

    final initialData = Map<String, dynamic>.from(mappedInitial);
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
    initialData['combo_items_editor'] = _parseMapList(row['items']);
    return initialData;
  }

  Map<String, dynamic> _buildUnifiedFormData({
    required EpdDashboardState state,
    required Map<String, dynamic> sourceData,
    required List<String> hiddenFields,
  }) {
    final order = EpdCollectionFormRegistry.formFieldOrder(state.activeSection);
    if (order.isEmpty) {
      return Map<String, dynamic>.from(sourceData);
    }

    final hiddenSet = <String>{...hiddenFields, 'id'};
    final prepared = <String, dynamic>{};

    for (final key in order) {
      if (sourceData.containsKey(key)) {
        prepared[key] = sourceData[key];
      }
    }

    for (final key in hiddenSet) {
      if (sourceData.containsKey(key) && !prepared.containsKey(key)) {
        prepared[key] = sourceData[key];
      }
    }

    // Preserve row/document identifiers and context keys for correct payload mapping.
    for (final key in const ['id', 'empresaId', 'adminId']) {
      if (sourceData.containsKey(key) && !prepared.containsKey(key)) {
        prepared[key] = sourceData[key];
      }
    }

    return prepared;
  }

  Future<Map<String, dynamic>?> _showSectionFormDialog({
    required EpdDashboardState state,
    required Map<String, dynamic> initialData,
    required bool isEdit,
    required String title,
    required List<String> hiddenFields,
  }) {
    final preparedInitialData = _buildUnifiedFormData(
      state: state,
      sourceData: initialData,
      hiddenFields: hiddenFields,
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DynamicFormDialog(
        initialData: preparedInitialData,
        isEdit: isEdit,
        title: title,
        fieldSchemas: _buildFieldSchemas(state),
        hiddenFields: hiddenFields,
        onUploadImage: _uploadImageToStorage,
      ),
    );
  }

  Future<void> _showCreateDialog(EpdDashboardState state) async {
    var currentState = state;

    if (_isCreateDisabled(currentState.activeSection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La creacion esta deshabilitada para esta seccion.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ref.read(epdDashboardProvider.notifier).refreshDependencies();
    if (!mounted) return;
    currentState = ref.read(epdDashboardProvider);

    if (currentState.activeSection == 'branches' &&
        currentState.selectedEmpresas.length != 1) {
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

    // Plantilla base por secciÃƒÆ’Ã‚Â³n (robusta, no depende de state.data.first)
    final initialData = _getBaseFieldsForSection(currentState.activeSection);

    // Inyectar automÃƒÆ’Ã‚Â¡ticamente el contexto activo (empresa seleccionada, filtros de bÃƒÆ’Ã‚Âºsqueda)
    final contextHidden = <String>[];
    final isGlobalTemplateSection =
        currentState.activeSection == 'expense_category_templates' ||
        currentState.activeSection == 'category_templates' ||
        currentState.activeSection == 'catalog_templates';

    // Si hay una sola empresa seleccionada, se inyecta como empresaId
    if (!isGlobalTemplateSection && currentState.selectedEmpresas.length == 1) {
      final selected = currentState.selectedEmpresas.first;
      final empresaId =
          selected['value']?.toString() ??
          selected['id']?.toString() ??
          selected['IdEmpresa']?.toString() ??
          selected['empresaId']?.toString() ??
          '';
      if (empresaId.isNotEmpty) {
        initialData['empresaId'] = empresaId;
        contextHidden.add('empresaId');
      }
    }

    // Si hay un filtro de bÃƒÆ’Ã‚Âºsqueda activo, tambiÃƒÆ’Ã‚Â©n se inyecta y oculta
    if (!isGlobalTemplateSection &&
        currentState.searchField != null &&
        currentState.searchValue != null &&
        currentState.searchValue!.isNotEmpty) {
      initialData[currentState.searchField!] = currentState.searchValue!;
      contextHidden.add(currentState.searchField!);
    }

    // Lista combinada de ocultos: sistema + contexto ya inyectado.
    final hiddenFields = [
      ..._hiddenSystemFieldsForSection(currentState.activeSection),
      if (currentState.activeSection == 'branches') 'empresaId',
      ...contextHidden,
    ];

    final result = await _showSectionFormDialog(
      state: currentState,
      initialData: initialData,
      isEdit: false,
      title: 'Crear en ${currentState.activeSectionLabel}',
      hiddenFields: hiddenFields,
    );

    if (result != null && mounted) {
      final notifier = ref.read(epdDashboardProvider.notifier);
      final payload = _normalizePayloadForSubmit(currentState, result);
      String? error;

      if (currentState.activeSection == 'branches') {
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
                'La sucursal se creo, pero no se obtuvo el ID para asignar vendedores.';
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
              content: Text('Documento creado con exito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final notifier = ref.read(epdDashboardProvider.notifier);
    await notifier.refreshDependencies();
    if (!mounted) return;

    final state = ref.read(epdDashboardProvider);
    final initialData = _buildDialogInitialData(state, row);
    final hiddenFields = [
      ..._hiddenSystemFieldsForSection(state.activeSection),
      if (state.activeSection == 'branches') 'empresaId',
    ];
    final result = await _showSectionFormDialog(
      state: state,
      initialData: initialData,
      isEdit: true,
      title: 'Editar Documento',
      hiddenFields: hiddenFields,
    );

    if (result != null && mounted) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: El documento no tiene ID')),
        );
        return;
      }

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
          'Eliminar documento?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esta accion es irreversible. Seguro que deseas eliminar el registro permanentemente?',
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

  /// DiÃƒÆ’Ã‚Â¡logo para ajuste atÃƒÆ’Ã‚Â³mico de stock de inventario.
  /// Llama al endpoint POST /inventario-ajuste que en un Batch:
  ///   1) Actualiza el campo `stock` del documento en `inventory`
  ///   2) Crea un registro de auditorÃƒÆ’Ã‚Â­a en `inventory_transactions`
  Future<({String empresaId, String empresaLabel})?>
  _pickEmpresaForExpenseTemplateApply(
    EpdDashboardState state, {
    required String title,
    required String subtitle,
  }) async {
    final companyOptions = state.getDropdownOptions('companies');
    if (companyOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay empresas disponibles para aplicar la plantilla.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    String? preselectedEmpresaId;
    if (state.selectedEmpresas.length == 1) {
      final selected = state.selectedEmpresas.first;
      preselectedEmpresaId =
          selected['id']?.toString().trim().isNotEmpty == true
          ? selected['id']?.toString().trim()
          : selected['value']?.toString().trim();
    }
    preselectedEmpresaId ??=
        companyOptions.first['value']?.toString().trim().isNotEmpty == true
        ? companyOptions.first['value'].toString().trim()
        : null;

    final formKey = GlobalKey<FormState>();
    String? selectedEmpresaId = preselectedEmpresaId;

    final pickedEmpresaId = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: selectedEmpresaId,
                    items: companyOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option['value']?.toString(),
                            child: Text(
                              option['label']?.toString() ??
                                  option['value']?.toString() ??
                                  '',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setInner(() => selectedEmpresaId = value),
                    decoration: InputDecoration(
                      labelText: 'Empresa destino',
                      labelStyle: GoogleFonts.outfit(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Selecciona una empresa';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.outfit(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          Navigator.pop(ctx, selectedEmpresaId?.trim());
                        },
                        icon: const Icon(Icons.publish_rounded, size: 16),
                        label: Text(
                          'Aplicar',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final empresaId = pickedEmpresaId?.trim() ?? '';
    if (empresaId.isEmpty) return null;

    String companyLabel = empresaId;
    for (final option in companyOptions) {
      final optionValue = option['value']?.toString() ?? '';
      if (optionValue == empresaId) {
        companyLabel = option['label']?.toString() ?? empresaId;
        break;
      }
    }

    return (empresaId: empresaId, empresaLabel: companyLabel);
  }

  Future<void> _showApplyAllExpenseTemplatesDialog(
    EpdDashboardState state,
  ) async {
    try {
      await _withExpenseTemplateApplyLock(() async {
        final picked = await _pickEmpresaForExpenseTemplateApply(
          state,
          title: 'Aplicar Todas las Plantillas',
          subtitle:
              'Se aplicarán todos los tipos de gasto plantilla a la empresa seleccionada.',
        );
        if (picked == null || !mounted) return;

        final error = await ref
            .read(epdDashboardProvider.notifier)
            .applyAllExpenseCategoryTemplatesToCompany(
              empresaId: picked.empresaId,
            );

        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plantillas de tipo de gasto aplicadas a "${picked.empresaLabel}".',
            ),
            backgroundColor: Colors.green,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al aplicar plantillas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showApplyExpenseTemplateDialog(
    EpdDashboardState state,
    Map<String, dynamic> row,
  ) async {
    try {
      await _withExpenseTemplateApplyLock(() async {
        final templateId = (row['id'] ?? '').toString().trim();
        if (templateId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo identificar la plantilla seleccionada.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final templateName =
            (row['name'] ?? row['nombre'] ?? '').toString().trim().isEmpty
            ? templateId
            : (row['name'] ?? row['nombre']).toString().trim();

        final picked = await _pickEmpresaForExpenseTemplateApply(
          state,
          title: 'Aplicar Plantilla de Tipo de Gasto',
          subtitle: 'Plantilla: $templateName',
        );
        if (picked == null || !mounted) return;

        final error = await ref
            .read(epdDashboardProvider.notifier)
            .applyExpenseCategoryTemplateToCompany(
              templateId: templateId,
              empresaId: picked.empresaId,
            );

        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plantilla "$templateName" aplicada a la empresa "${picked.empresaLabel}".',
            ),
            backgroundColor: Colors.green,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar plantilla: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                      return 'Debe ser un numero valido';
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

                // ObservaciÃƒÆ’Ã‚Â³n (opcional)
                Text(
                  'OBSERVACION (opcional)',
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
              content: Text('Ajuste de inventario aplicado con exito'),
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

class _CatalogImportSummary {
  final int total;
  final int newItems;
  final int conflicts;
  final int invalid;

  const _CatalogImportSummary({
    required this.total,
    required this.newItems,
    required this.conflicts,
    required this.invalid,
  });

  factory _CatalogImportSummary.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value) => (value is num) ? value.toInt() : 0;
    return _CatalogImportSummary(
      total: toInt(map['total']),
      newItems: toInt(map['new']),
      conflicts: toInt(map['conflict']),
      invalid: toInt(map['invalid']),
    );
  }
}

class _CatalogImportPreviewRow {
  final String rowKey;
  final int rowNumber;
  final String sheet;
  final String displayName;
  final String status;
  final List<String> errors;

  const _CatalogImportPreviewRow({
    required this.rowKey,
    required this.rowNumber,
    required this.sheet,
    required this.displayName,
    required this.status,
    required this.errors,
  });

  String get sheetLabel => sheet == 'categories' ? 'Categorias' : 'Productos';
  bool get isConflict => status == 'conflict';
  bool get isInvalid => status == 'invalid';

  factory _CatalogImportPreviewRow.fromMap(
    Map<String, dynamic> map,
    String sheet,
  ) {
    int toInt(dynamic value) => (value is num) ? value.toInt() : 0;
    final displayName = sheet == 'categories'
        ? (map['NombreCategoria']?.toString() ?? '')
        : (map['NombreProducto']?.toString() ?? '');
    final errorsRaw = map['errors'];
    final errors = errorsRaw is List
        ? errorsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return _CatalogImportPreviewRow(
      rowKey: map['rowKey']?.toString() ?? '',
      rowNumber: toInt(map['rowNumber']),
      sheet: sheet,
      displayName: displayName.trim().isEmpty ? 'Sin nombre' : displayName,
      status: map['status']?.toString() ?? 'new',
      errors: errors,
    );
  }
}

class _CatalogImportPreviewModel {
  final String draftToken;
  final _CatalogImportSummary categoriesSummary;
  final _CatalogImportSummary productsSummary;
  final List<_CatalogImportPreviewRow> rows;

  const _CatalogImportPreviewModel({
    required this.draftToken,
    required this.categoriesSummary,
    required this.productsSummary,
    required this.rows,
  });

  List<_CatalogImportPreviewRow> get conflictRows =>
      rows.where((r) => r.isConflict).toList();

  List<_CatalogImportPreviewRow> get invalidRows =>
      rows.where((r) => r.isInvalid).toList();

  factory _CatalogImportPreviewModel.fromMap(Map<String, dynamic> map) {
    final summaryMap =
        (map['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final categoriesMap =
        (summaryMap['categories'] as Map?)?.cast<String, dynamic>() ?? const {};
    final productsMap =
        (summaryMap['products'] as Map?)?.cast<String, dynamic>() ?? const {};

    final rows = <_CatalogImportPreviewRow>[];
    final categoriesRows = map['categories'];
    if (categoriesRows is List) {
      for (final raw in categoriesRows) {
        if (raw is Map<String, dynamic>) {
          rows.add(_CatalogImportPreviewRow.fromMap(raw, 'categories'));
        } else if (raw is Map) {
          rows.add(
            _CatalogImportPreviewRow.fromMap(
              raw.map((k, v) => MapEntry(k.toString(), v)),
              'categories',
            ),
          );
        }
      }
    }

    final productRows = map['products'];
    if (productRows is List) {
      for (final raw in productRows) {
        if (raw is Map<String, dynamic>) {
          rows.add(_CatalogImportPreviewRow.fromMap(raw, 'products'));
        } else if (raw is Map) {
          rows.add(
            _CatalogImportPreviewRow.fromMap(
              raw.map((k, v) => MapEntry(k.toString(), v)),
              'products',
            ),
          );
        }
      }
    }

    return _CatalogImportPreviewModel(
      draftToken: map['draftToken']?.toString() ?? '',
      categoriesSummary: _CatalogImportSummary.fromMap(categoriesMap),
      productsSummary: _CatalogImportSummary.fromMap(productsMap),
      rows: rows,
    );
  }
}

class _CatalogImportDialogResult {
  final Map<String, String> conflictDecisions;
  final String invalidPolicy;

  const _CatalogImportDialogResult({
    required this.conflictDecisions,
    required this.invalidPolicy,
  });
}
