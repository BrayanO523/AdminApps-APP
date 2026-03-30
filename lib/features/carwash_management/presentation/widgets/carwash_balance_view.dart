import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/repositories/carwash_repository.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashBalanceView extends ConsumerStatefulWidget {
  final String? companyId;

  const CarwashBalanceView({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<CarwashBalanceView> createState() => _CarwashBalanceViewState();
}

class _CarwashBalanceViewState extends ConsumerState<CarwashBalanceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _searchText = '';
  List<_BalanceInvoice> _invoices = const [];
  List<_BalancePayment> _payments = const [];
  _BalanceRangePreset _rangePreset = _BalanceRangePreset.thisMonth;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(covariant CarwashBalanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _invoices = const [];
          _payments = const [];
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repository = ref.read(carwashRepositoryProvider);
    final results = await Future.wait([
      _loadCollection(repository, 'facturas', companyId),
      _loadCollection(repository, 'pagos', companyId),
    ]);

    if (!mounted) return;

    final error = results
        .map((item) => item.errorMessage)
        .firstWhere((msg) => msg != null && msg.isNotEmpty, orElse: () => null);

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _invoices = results[0].rows.map(_BalanceInvoice.fromRow).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(1900)).compareTo(
              a.createdAt ?? DateTime(1900),
            ));
      _payments = results[1].rows.map(_BalancePayment.fromRow).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(1900)).compareTo(
              a.createdAt ?? DateTime(1900),
            ));
    });
  }

  Future<_LoadCollectionResult> _loadCollection(
    CarwashRepository repository,
    String collection,
    String companyId,
  ) async {
    final result = await repository.getCollection(
      collection,
      limit: 500,
      searchField: 'empresa_id',
      searchValue: companyId,
      empresaId: companyId,
    );

    return result.fold(
      (failure) => _LoadCollectionResult(
        rows: const [],
        errorMessage: failure.message,
      ),
      (response) => _LoadCollectionResult(rows: response.data),
    );
  }

  List<_BalanceInvoice> get _filteredInvoices {
    final scopedInvoices = _dateFilteredInvoices;
    if (_searchText.trim().isEmpty) return scopedInvoices;
    final query = _searchText.toLowerCase();
    return scopedInvoices.where((invoice) {
      return invoice.clientName.toLowerCase().contains(query) ||
          invoice.invoiceNumber.toLowerCase().contains(query);
    }).toList();
  }

  List<_BalanceInvoice> get _dateFilteredInvoices {
    final range = _effectiveDateRange;
    if (range == null) return _invoices;
    return _invoices.where((invoice) {
      final createdAt = invoice.createdAt;
      if (createdAt == null) return false;
      return !createdAt.isBefore(range.start) && !createdAt.isAfter(range.end);
    }).toList();
  }

  List<_BalancePayment> get _dateFilteredPayments {
    final range = _effectiveDateRange;
    if (range == null) return _payments;
    return _payments.where((payment) {
      final createdAt = payment.createdAt;
      if (createdAt == null) return false;
      return !createdAt.isBefore(range.start) && !createdAt.isAfter(range.end);
    }).toList();
  }

  DateTimeRange? get _effectiveDateRange {
    final now = DateTime.now();
    switch (_rangePreset) {
      case _BalanceRangePreset.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case _BalanceRangePreset.thisWeek:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: start,
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case _BalanceRangePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case _BalanceRangePreset.custom:
        if (_customRange == null) return null;
        return DateTimeRange(
          start: DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          ),
          end: DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
            999,
          ),
        );
      case _BalanceRangePreset.all:
        return null;
    }
  }

  List<_ReceivableSummary> get _receivables {
    final groups = <String, List<_BalanceInvoice>>{};

    for (final invoice in _dateFilteredInvoices) {
      if (invoice.paymentCondition != 'credito') continue;
      if (!{'pendiente', 'parcial', 'vencido'}.contains(invoice.paymentStatus)) {
        continue;
      }
      if (invoice.pendingAmount <= 0.009) continue;
      groups.putIfAbsent(invoice.clientId, () => []);
      groups[invoice.clientId]!.add(invoice);
    }

    final items = groups.entries.map((entry) {
      final invoices = entry.value
        ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(
              b.dueDate ?? DateTime(2100),
            ));
      final first = invoices.first;
      final totalDebt = invoices.fold<double>(
        0,
        (sum, item) => sum + item.pendingAmount,
      );

      return _ReceivableSummary(
        clientId: entry.key,
        clientName: first.clientName,
        clientRtn: first.clientRtn,
        totalDebt: totalDebt,
        invoiceCount: invoices.length,
        hasOverdue: invoices.any((invoice) => invoice.isOverdue),
        oldestDueDate: invoices
            .where((invoice) => invoice.dueDate != null)
            .map((invoice) => invoice.dueDate!)
            .fold<DateTime?>(null, (prev, next) {
              if (prev == null) return next;
              return next.isBefore(prev) ? next : prev;
            }),
      );
    }).toList();

    items.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
    return items;
  }

  int get _pendingCreditInvoiceCount => _dateFilteredInvoices
      .where((invoice) => invoice.paymentCondition == 'credito')
      .where(
        (invoice) => {'pendiente', 'parcial', 'vencido'}.contains(
          invoice.paymentStatus,
        ),
      )
      .where((invoice) => invoice.pendingAmount > 0.009)
      .length;

  int get _overdueInvoiceCount =>
      _dateFilteredInvoices.where((invoice) => invoice.isOverdue).length;

  double get _cashSales => _dateFilteredInvoices
      .where((invoice) => invoice.paymentCondition == 'contado')
      .fold<double>(0, (sum, item) => sum + item.total);

  double get _creditCollections => _dateFilteredPayments.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );

  double get _totalIncome => _cashSales + _creditCollections;
  double get _totalPendingDebt => _receivables.fold<double>(
        0,
        (sum, item) => sum + item.totalDebt,
      );
  double get _creditInvoiced => _dateFilteredInvoices
      .where((invoice) => invoice.paymentCondition == 'credito')
      .fold<double>(0, (sum, item) => sum + item.total);

  int get _paidInvoiceCount =>
      _dateFilteredInvoices
          .where((invoice) => invoice.paymentStatus == 'pagado')
          .length;

  int get _partialInvoiceCount =>
      _dateFilteredInvoices
          .where((invoice) => invoice.paymentStatus == 'parcial')
          .length;

  int get _pendingInvoiceCount =>
      _dateFilteredInvoices
          .where((invoice) => invoice.paymentStatus == 'pendiente')
          .length;

  double get _averageTicket {
    if (_dateFilteredInvoices.isEmpty) return 0;
    final total =
        _dateFilteredInvoices.fold<double>(0, (sum, item) => sum + item.total);
    return total / _dateFilteredInvoices.length;
  }

  List<_DailyMetric> get _last7Days {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      final dayKey = DateTime(day.year, day.month, day.day);

      final cashInvoices = _dateFilteredInvoices.where((invoice) {
        final created = invoice.createdAt;
        if (created == null || invoice.paymentCondition != 'contado') return false;
        return DateTime(created.year, created.month, created.day) == dayKey;
      });

      final dayPayments = _dateFilteredPayments.where((payment) {
        final created = payment.createdAt;
        if (created == null) return false;
        return DateTime(created.year, created.month, created.day) == dayKey;
      });

      final total = cashInvoices.fold<double>(0, (sum, item) => sum + item.total) +
          dayPayments.fold<double>(0, (sum, item) => sum + item.amount);

      return _DailyMetric(
        label: DateFormat('dd/MM').format(day),
        amount: total,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      return const _BillingEmptyState(
        icon: Icons.business_center_rounded,
        title: 'Selecciona una empresa',
        subtitle:
            'El balance necesita una empresa activa para consultar facturas y pagos.',
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _BillingEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar el balance',
        subtitle: _errorMessage!,
        actionLabel: 'Reintentar',
        onAction: _loadData,
      );
    }

    final dashboardState = ref.watch(carwashDashboardProvider);
    final selectedCompany = dashboardState.selectedEmpresas.isEmpty
        ? null
        : dashboardState.selectedEmpresas.first;
    final companyName = _readString(
      selectedCompany ?? const <String, dynamic>{},
      const ['nombre', 'name'],
    );
    final rangeLabel = _selectedRangeLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchText = value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar cliente o número de factura...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _loadData,
                        tooltip: 'Recargar',
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _receivables.isEmpty
                            ? null
                            : () => _exportCompanyReceivablesPdf(companyName),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Cobranza PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _dateFilteredInvoices.isEmpty
                            ? null
                            : () => _exportFullBalancePdf(companyName),
                        icon: const Icon(Icons.analytics_rounded),
                        label: const Text('Reporte completo'),
                      ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildRangeChip(
                                label: 'Hoy',
                                preset: _BalanceRangePreset.today,
                              ),
                              _buildRangeChip(
                                label: 'Semana',
                                preset: _BalanceRangePreset.thisWeek,
                              ),
                              _buildRangeChip(
                                label: 'Mes',
                                preset: _BalanceRangePreset.thisMonth,
                              ),
                              _buildRangeChip(
                                label: 'Personalizado',
                                preset: _BalanceRangePreset.custom,
                                onSelected: _pickCustomRange,
                              ),
                              _buildRangeChip(
                                label: 'Todo',
                                preset: _BalanceRangePreset.all,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(rangeLabel, style: _mutedStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0EA5E9),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0EA5E9),
                  tabs: const [
                    Tab(text: 'Historial'),
                    Tab(text: 'Balance'),
                    Tab(text: 'Cuentas por Cobrar'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _HistoryTab(invoices: _filteredInvoices),
                _BalanceTab(
                  invoices: _dateFilteredInvoices,
                  receivables: _receivables,
                  totalIncome: _totalIncome,
                  cashSales: _cashSales,
                  creditCollections: _creditCollections,
                  creditInvoiced: _creditInvoiced,
                  totalInvoices: _dateFilteredInvoices.length,
                  paidInvoiceCount: _paidInvoiceCount,
                  partialInvoiceCount: _partialInvoiceCount,
                  pendingInvoiceCount: _pendingInvoiceCount,
                  overdueInvoiceCount: _overdueInvoiceCount,
                  averageTicket: _averageTicket,
                  last7Days: _last7Days,
                ),
                _ReceivablesTab(receivables: _receivables),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCompanyReceivablesPdf(String companyName) async {
    final receivables = _receivables;
    if (receivables.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cuentas por cobrar para exportar.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final effectiveCompanyName = companyName.trim().isEmpty
        ? 'Empresa'
        : companyName.trim();

    final pdf = pw.Document();
    final groupedInvoices = <String, List<_BalanceInvoice>>{};
    for (final invoice in _dateFilteredInvoices) {
      if (invoice.paymentCondition != 'credito') continue;
      if (invoice.pendingAmount <= 0.009) continue;
      if (!{'pendiente', 'parcial', 'vencido'}.contains(invoice.paymentStatus)) {
        continue;
      }
      groupedInvoices.putIfAbsent(invoice.clientId, () => []);
      groupedInvoices[invoice.clientId]!.add(invoice);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE DE CUENTAS POR COBRAR',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      effectiveCompanyName,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Fecha: ${dateFormatter.format(now)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPdfMetricCard(
                  title: 'Total pendiente global',
                  value: currency.format(_totalPendingDebt),
                  color: PdfColors.red600,
                ),
                _buildPdfMetricCard(
                  title: 'Total cobrado',
                  value: currency.format(_creditCollections),
                  color: PdfColors.green600,
                ),
                _buildPdfMetricCard(
                  title: 'Facturas credito pendientes',
                  value: _pendingCreditInvoiceCount.toString(),
                  color: PdfColors.orange600,
                ),
                _buildPdfMetricCard(
                  title: 'Clientes con saldo',
                  value: receivables.length.toString(),
                  color: PdfColors.blue600,
                ),
                _buildPdfMetricCard(
                  title: 'Facturas vencidas',
                  value: _overdueInvoiceCount.toString(),
                  color: PdfColors.red800,
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Detalle por cliente',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 10),
            ...receivables.map((summary) {
              final invoices = (groupedInvoices[summary.clientId] ?? const [])
                ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(
                      b.dueDate ?? DateTime(2100),
                    ));

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                summary.clientName.isEmpty
                                    ? 'Cliente sin nombre'
                                    : summary.clientName,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (summary.clientRtn.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: pw.Text(
                                    'RTN: ${summary.clientRtn}',
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        pw.Text(
                          currency.format(summary.totalDebt),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '${summary.invoiceCount} facturas pendientes${summary.hasOverdue ? ' - Tiene vencidas' : ''}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(2.3),
                        1: pw.FlexColumnWidth(1.5),
                        2: pw.FlexColumnWidth(1.2),
                        3: pw.FlexColumnWidth(1.2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            _buildPdfTableHeader('Factura'),
                            _buildPdfTableHeader('Vence'),
                            _buildPdfTableHeader('Pendiente'),
                            _buildPdfTableHeader('Estado'),
                          ],
                        ),
                        ...invoices.map(
                          (invoice) => pw.TableRow(
                            children: [
                              _buildPdfTableCell(
                                invoice.invoiceNumber.isEmpty
                                    ? invoice.id
                                    : invoice.invoiceNumber,
                              ),
                              _buildPdfTableCell(
                                invoice.dueDate == null
                                    ? '-'
                                    : dateFormatter.format(invoice.dueDate!),
                              ),
                              _buildPdfTableCell(
                                currency.format(invoice.pendingAmount),
                                align: pw.TextAlign.right,
                              ),
                              _buildPdfTableCell(
                                invoice.isOverdue ? 'Vencida' : 'Pendiente',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'CuentasPorCobrar_${effectiveCompanyName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  Future<void> _exportFullBalancePdf(String companyName) async {
    if (_dateFilteredInvoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay facturas para exportar.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final companyLabel = companyName.trim().isEmpty ? 'Empresa' : companyName;
    final recentInvoices = _dateFilteredInvoices.take(20).toList();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPORTE FINANCIERO COMPLETO',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    companyLabel,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Generado: ${dateFormatter.format(now)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPdfMetricCard(
                title: 'Ingresos totales',
                value: currency.format(_totalIncome),
                color: PdfColors.blue600,
              ),
              _buildPdfMetricCard(
                title: 'Ventas contado',
                value: currency.format(_cashSales),
                color: PdfColors.green600,
              ),
              _buildPdfMetricCard(
                title: 'Cobros credito',
                value: currency.format(_creditCollections),
                color: PdfColors.orange600,
              ),
              _buildPdfMetricCard(
                title: 'Facturado a credito',
                value: currency.format(_creditInvoiced),
                color: PdfColors.deepPurple600,
              ),
              _buildPdfMetricCard(
                title: 'Facturas emitidas',
                value: _dateFilteredInvoices.length.toString(),
                color: PdfColors.blueGrey700,
              ),
              _buildPdfMetricCard(
                title: 'Ticket promedio',
                value: currency.format(_averageTicket),
                color: PdfColors.teal700,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Resumen de facturas',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildPdfTableHeader('Concepto'),
                  _buildPdfTableHeader('Cantidad'),
                  _buildPdfTableHeader('Monto'),
                ],
              ),
              _buildSummaryRow(
                'Ventas contado',
                _dateFilteredInvoices
                    .where((invoice) => invoice.paymentCondition == 'contado')
                    .length
                    .toString(),
                currency.format(_cashSales),
              ),
              _buildSummaryRow(
                'Facturas credito',
                _dateFilteredInvoices
                    .where((invoice) => invoice.paymentCondition == 'credito')
                    .length
                    .toString(),
                currency.format(_creditInvoiced),
              ),
              _buildSummaryRow(
                'Facturas pagadas',
                _paidInvoiceCount.toString(),
                '-',
              ),
              _buildSummaryRow(
                'Facturas parciales',
                _partialInvoiceCount.toString(),
                '-',
              ),
              _buildSummaryRow(
                'Facturas pendientes',
                _pendingInvoiceCount.toString(),
                currency.format(_totalPendingDebt),
              ),
              _buildSummaryRow(
                'Facturas vencidas',
                _overdueInvoiceCount.toString(),
                '-',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Ingresos ultimos 7 dias',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildPdfTableHeader('Dia'),
                  _buildPdfTableHeader('Ingreso'),
                ],
              ),
              ..._last7Days.map(
                (item) => pw.TableRow(
                  children: [
                    _buildPdfTableCell(item.label),
                    _buildPdfTableCell(
                      currency.format(item.amount),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Ultimas facturas',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.1),
              1: pw.FlexColumnWidth(2.0),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.1),
              4: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildPdfTableHeader('Factura'),
                  _buildPdfTableHeader('Cliente'),
                  _buildPdfTableHeader('Condicion'),
                  _buildPdfTableHeader('Estado'),
                  _buildPdfTableHeader('Total'),
                ],
              ),
              ...recentInvoices.map(
                (invoice) => pw.TableRow(
                  children: [
                    _buildPdfTableCell(
                      invoice.invoiceNumber.isEmpty
                          ? invoice.id
                          : invoice.invoiceNumber,
                    ),
                    _buildPdfTableCell(invoice.clientName),
                    _buildPdfTableCell(invoice.paymentCondition),
                    _buildPdfTableCell(
                      invoice.isOverdue ? 'vencido' : invoice.paymentStatus,
                    ),
                    _buildPdfTableCell(
                      currency.format(invoice.total),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_receivables.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Resumen de cuentas por cobrar',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfTableHeader('Clientes con saldo'),
                    _buildPdfTableHeader('Pendiente global'),
                    _buildPdfTableHeader('Facturas vencidas'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildPdfTableCell(_receivables.length.toString()),
                    _buildPdfTableCell(
                      currency.format(_totalPendingDebt),
                      align: pw.TextAlign.right,
                    ),
                    _buildPdfTableCell(_overdueInvoiceCount.toString()),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'ReporteCompleto_${companyLabel.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  String get _selectedRangeLabel {
    final range = _effectiveDateRange;
    switch (_rangePreset) {
      case _BalanceRangePreset.today:
        return 'Rango: hoy';
      case _BalanceRangePreset.thisWeek:
        return 'Rango: esta semana';
      case _BalanceRangePreset.thisMonth:
        return 'Rango: este mes';
      case _BalanceRangePreset.custom:
        if (range == null) return 'Rango personalizado';
        final formatter = DateFormat('dd/MM/yyyy');
        return 'Rango: ${formatter.format(range.start)} - ${formatter.format(range.end)}';
      case _BalanceRangePreset.all:
        return 'Rango: todo el historial';
    }
  }

  Widget _buildRangeChip({
    required String label,
    required _BalanceRangePreset preset,
    Future<void> Function()? onSelected,
  }) {
    final selected = _rangePreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        if (preset == _BalanceRangePreset.custom) {
          await (onSelected ?? _pickCustomRange).call();
          return;
        }
        setState(() {
          _rangePreset = preset;
        });
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialRange = _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Selecciona el rango',
      cancelText: 'Cancelar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _rangePreset = _BalanceRangePreset.custom;
    });
  }
}

enum _BalanceRangePreset {
  today,
  thisWeek,
  thisMonth,
  custom,
  all,
}

class _HistoryTab extends StatelessWidget {
  final List<_BalanceInvoice> invoices;

  const _HistoryTab({required this.invoices});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const _BillingEmptyState(
        icon: Icons.history_rounded,
        title: 'No hay facturas para mostrar',
        subtitle: 'El historial aparecerá cuando existan documentos emitidos.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _InvoiceHistoryCard(invoice: invoices[index]),
    );
  }
}

class _BalanceTab extends StatelessWidget {
  final List<_BalanceInvoice> invoices;
  final List<_ReceivableSummary> receivables;
  final double totalIncome;
  final double cashSales;
  final double creditCollections;
  final double creditInvoiced;
  final int totalInvoices;
  final int paidInvoiceCount;
  final int partialInvoiceCount;
  final int pendingInvoiceCount;
  final int overdueInvoiceCount;
  final double averageTicket;
  final List<_DailyMetric> last7Days;

  const _BalanceTab({
    required this.invoices,
    required this.receivables,
    required this.totalIncome,
    required this.cashSales,
    required this.creditCollections,
    required this.creditInvoiced,
    required this.totalInvoices,
    required this.paidInvoiceCount,
    required this.partialInvoiceCount,
    required this.pendingInvoiceCount,
    required this.overdueInvoiceCount,
    required this.averageTicket,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Ingreso total',
              value: currency.format(totalIncome),
              color: const Color(0xFF0EA5E9),
              icon: Icons.attach_money_rounded,
            ),
            _MetricCard(
              title: 'Ventas contado',
              value: currency.format(cashSales),
              color: const Color(0xFF10B981),
              icon: Icons.point_of_sale_rounded,
            ),
            _MetricCard(
              title: 'Cobros crédito',
              value: currency.format(creditCollections),
              color: const Color(0xFFF59E0B),
              icon: Icons.payments_rounded,
            ),
            _MetricCard(
              title: 'Facturas',
              value: totalInvoices.toString(),
              color: const Color(0xFF8B5CF6),
              icon: Icons.receipt_long_rounded,
            ),
            _MetricCard(
              title: 'Ticket promedio',
              value: currency.format(averageTicket),
              color: const Color(0xFF0F766E),
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de facturas',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MiniMetricChip(
                    label: 'Facturado contado',
                    value: currency.format(cashSales),
                    color: const Color(0xFF10B981),
                  ),
                  _MiniMetricChip(
                    label: 'Facturado credito',
                    value: currency.format(creditInvoiced),
                    color: const Color(0xFF8B5CF6),
                  ),
                  _MiniMetricChip(
                    label: 'Pagadas',
                    value: paidInvoiceCount.toString(),
                    color: const Color(0xFF16A34A),
                  ),
                  _MiniMetricChip(
                    label: 'Parciales',
                    value: partialInvoiceCount.toString(),
                    color: const Color(0xFFF59E0B),
                  ),
                  _MiniMetricChip(
                    label: 'Pendientes',
                    value: pendingInvoiceCount.toString(),
                    color: const Color(0xFF0EA5E9),
                  ),
                  _MiniMetricChip(
                    label: 'Vencidas',
                    value: overdueInvoiceCount.toString(),
                    color: const Color(0xFFDC2626),
                  ),
                  _MiniMetricChip(
                    label: 'Clientes con saldo',
                    value: receivables.length.toString(),
                    color: const Color(0xFF475569),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresos últimos 7 días',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...last7Days.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(item.label, style: _mutedStyle),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _progress(item.amount, last7Days),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF0EA5E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: Text(
                          currency.format(item.amount),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ultimas facturas',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              if (invoices.isEmpty)
                Text(
                  'No hay facturas emitidas.',
                  style: _mutedStyle,
                )
              else
                ...invoices.take(8).map(
                  (invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.invoiceNumber.isEmpty
                                    ? invoice.id
                                    : invoice.invoiceNumber,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(invoice.clientName, style: _mutedStyle),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SmallBadge(
                          label: invoice.paymentCondition,
                          color: invoice.paymentCondition == 'credito'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        _SmallBadge(
                          label: invoice.isOverdue
                              ? 'vencido'
                              : invoice.paymentStatus,
                          color: invoice.isOverdue
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0EA5E9),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Text(
                            currency.format(invoice.total),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  double _progress(double amount, List<_DailyMetric> days) {
    final maxAmount = days.fold<double>(0, (max, item) {
      return item.amount > max ? item.amount : max;
    });
    if (maxAmount <= 0) return 0;
    return amount / maxAmount;
  }
}

class _ReceivablesTab extends ConsumerWidget {
  final List<_ReceivableSummary> receivables;

  const _ReceivablesTab({required this.receivables});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (receivables.isEmpty) {
      return const _BillingEmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No hay cuentas por cobrar',
        subtitle: 'Las facturas a crédito pendientes aparecerán aquí.',
      );
    }

    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: receivables.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = receivables[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE0F2FE),
                child: Text(
                  item.clientName.isEmpty ? '?' : item.clientName[0].toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.clientName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.invoiceCount} facturas pendientes',
                      style: _mutedStyle,
                    ),
                    if (item.hasOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tiene facturas vencidas',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(item.totalDebt),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(carwashDashboardProvider.notifier)
                          .selectSection('estadoCuenta');
                    },
                    child: const Text('Ver estado'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(title, style: _mutedStyle),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceHistoryCard extends StatelessWidget {
  final _BalanceInvoice invoice;

  const _InvoiceHistoryCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber.isEmpty
                      ? 'Documento sin número'
                      : invoice.invoiceNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(invoice.clientName, style: _mutedStyle),
                const SizedBox(height: 4),
                Text(
                  invoice.createdAt != null
                      ? formatter.format(invoice.createdAt!)
                      : 'Sin fecha',
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(invoice.total),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _SmallBadge(
                    label: invoice.paymentCondition,
                    color: invoice.paymentCondition == 'credito'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                  ),
                  _SmallBadge(
                    label: invoice.paymentStatus,
                    color: invoice.isOverdue
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0EA5E9),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BillingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _BillingEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: _mutedStyle,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final TextStyle _mutedStyle = GoogleFonts.outfit(
  fontSize: 12,
  color: const Color(0xFF64748B),
  fontWeight: FontWeight.w500,
);

class _LoadCollectionResult {
  final List<Map<String, dynamic>> rows;
  final String? errorMessage;

  const _LoadCollectionResult({
    required this.rows,
    this.errorMessage,
  });
}

class _BalanceInvoice {
  final String id;
  final String clientId;
  final String clientName;
  final String clientRtn;
  final String invoiceNumber;
  final double total;
  final double paidAmount;
  final String paymentCondition;
  final String paymentStatus;
  final DateTime? dueDate;
  final DateTime? createdAt;

  const _BalanceInvoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientRtn,
    required this.invoiceNumber,
    required this.total,
    required this.paidAmount,
    required this.paymentCondition,
    required this.paymentStatus,
    required this.dueDate,
    required this.createdAt,
  });

  factory _BalanceInvoice.fromRow(Map<String, dynamic> row) {
    return _BalanceInvoice(
      id: row['id']?.toString() ?? '',
      clientId: _readString(row, ['cliente_id', 'clientId']),
      clientName: _readString(row, ['cliente_nombre', 'clientName']),
      clientRtn: _readString(row, ['cliente_rtn', 'clientRtn', 'rtn']),
      invoiceNumber: _readString(row, ['numero_factura', 'invoiceNumber']),
      total: _readDouble(row, ['total', 'totalAmount']),
      paidAmount: _readDouble(row, ['monto_pagado', 'paidAmount']),
      paymentCondition: _readString(
        row,
        ['condicion_pago', 'paymentCondition'],
      ).toLowerCase(),
      paymentStatus: _readString(
        row,
        ['estado_pago', 'paymentStatus'],
      ).toLowerCase(),
      dueDate: _readDate(row, ['fecha_vencimiento', 'dueDate']),
      createdAt: _readDate(row, ['fecha_creacion', 'createdAt']),
    );
  }

  double get pendingAmount => (total - paidAmount).clamp(0.0, double.infinity).toDouble();

  bool get isOverdue {
    if (paymentStatus == 'vencido') return true;
    if (dueDate == null) return false;
    return pendingAmount > 0.009 && dueDate!.isBefore(DateTime.now());
  }
}

class _BalancePayment {
  final String id;
  final double amount;
  final DateTime? createdAt;

  const _BalancePayment({
    required this.id,
    required this.amount,
    required this.createdAt,
  });

  factory _BalancePayment.fromRow(Map<String, dynamic> row) {
    return _BalancePayment(
      id: row['id']?.toString() ?? '',
      amount: _readDouble(row, ['monto', 'amount']),
      createdAt: _readDate(row, ['fecha_creacion', 'createdAt']),
    );
  }
}

class _ReceivableSummary {
  final String clientId;
  final String clientName;
  final String clientRtn;
  final double totalDebt;
  final int invoiceCount;
  final bool hasOverdue;
  final DateTime? oldestDueDate;

  const _ReceivableSummary({
    required this.clientId,
    required this.clientName,
    required this.clientRtn,
    required this.totalDebt,
    required this.invoiceCount,
    required this.hasOverdue,
    required this.oldestDueDate,
  });
}

class _DailyMetric {
  final String label;
  final double amount;

  const _DailyMetric({
    required this.label,
    required this.amount,
  });
}

String _readString(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null) continue;
    final str = value.toString().trim();
    if (str.isNotEmpty) return str;
  }
  return '';
}

double _readDouble(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return 0;
}

DateTime? _readDate(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null) continue;
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is Map &&
        value['_seconds'] is num &&
        value['_nanoseconds'] is num) {
      final seconds = value['_seconds'] as num;
      return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
    }
  }
  return null;
}

pw.TableRow _buildSummaryRow(String label, String count, String amount) {
  return pw.TableRow(
    children: [
      _buildPdfTableCell(label),
      _buildPdfTableCell(count, align: pw.TextAlign.center),
      _buildPdfTableCell(amount, align: pw.TextAlign.right),
    ],
  );
}

pw.Widget _buildPdfMetricCard({
  required String title,
  required String value,
  required PdfColor color,
}) {
  return pw.Container(
    width: 160,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: color),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.blueGrey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfTableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _buildPdfTableCell(
  String text, {
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      textAlign: align,
      style: const pw.TextStyle(fontSize: 9),
    ),
  );
}
