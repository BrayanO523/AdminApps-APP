import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/repositories/carwash_repository.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashAccountStatementView extends ConsumerStatefulWidget {
  final String? companyId;

  const CarwashAccountStatementView({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<CarwashAccountStatementView> createState() =>
      _CarwashAccountStatementViewState();
}

class _CarwashAccountStatementViewState
    extends ConsumerState<CarwashAccountStatementView> {
  static const String _webAdminUserId = 'web-admin';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _searchText = '';
  List<_ClientAccountSummary> _accounts = const [];
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(covariant CarwashAccountStatementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _accounts = const [];
          _selectedClientId = null;
          _errorMessage = null;
          _isLoading = false;
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
      _loadCollection(repository, 'clientes', companyId),
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

    final accounts = _buildAccounts(
      clients: results[0].rows,
      invoices: results[1].rows,
      payments: results[2].rows,
    );

    setState(() {
      _accounts = accounts;
      _isLoading = false;
      _selectedClientId = accounts.any((item) => item.clientId == _selectedClientId)
          ? _selectedClientId
          : (accounts.isNotEmpty ? accounts.first.clientId : null);
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

  Future<void> _openGlobalPayment(_ClientAccountSummary account) async {
    final result = await showModalBottomSheet<_PaymentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegisterPaymentSheet(
        account: account,
        pendingInvoices: account.pendingInvoices,
      ),
    );

    if (result == null) return;
    await _registerGlobalPayment(account, result);
  }

  Future<void> _openInvoicePayment(
    _ClientAccountSummary account,
    _InvoiceEntry invoice,
  ) async {
    final result = await showModalBottomSheet<_PaymentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegisterPaymentSheet(
        account: account,
        invoice: invoice,
      ),
    );

    if (result == null) return;
    await _registerInvoicePayment(account, invoice, result);
  }

  Future<void> _registerInvoicePayment(
    _ClientAccountSummary account,
    _InvoiceEntry invoice,
    _PaymentDraft draft,
  ) async {
    final repository = ref.read(carwashRepositoryProvider);
    final now = DateTime.now();
    final paymentId = now.millisecondsSinceEpoch.toString();

    setState(() => _isLoading = true);

    final paymentResult = await repository.createDocument('pagos', {
      'id': paymentId,
      'factura_id': invoice.id,
      'cliente_id': account.clientId,
      'empresa_id': widget.companyId,
      'monto': draft.amount,
      'metodo_pago': draft.paymentMethod,
      'referencia': draft.reference,
      'fecha_creacion': now.toIso8601String(),
      'creado_por': _webAdminUserId,
      'notas': draft.notes,
    });

    final paymentError = paymentResult.fold((failure) => failure.message, (_) => null);
    if (paymentError != null) {
      _finishPaymentWithError(paymentError);
      return;
    }

    final newPaidAmount = invoice.paidAmount + draft.amount;
    final newStatus =
        newPaidAmount >= invoice.total - 0.01 ? 'pagado' : 'parcial';
    final timestamp = _toTimestampMap(now);

    final invoiceResult = await repository.updateDocument('facturas', invoice.id, {
      'estado_pago': newStatus,
      'monto_pagado': newPaidAmount,
      'fecha_pagado': timestamp,
      'updatedBy': _webAdminUserId,
      'updatedAt': timestamp,
    });

    final invoiceError = invoiceResult.fold((failure) => failure.message, (_) => null);
    if (invoiceError != null) {
      _finishPaymentWithError(invoiceError);
      return;
    }

    final newBalance = (account.currentBalance - draft.amount).clamp(
      0.0,
      double.infinity,
    ).toDouble();

    final clientResult = await repository.updateDocument('clientes', account.clientId, {
      'saldo_actual': newBalance,
      'updatedBy': _webAdminUserId,
      'updatedAt': timestamp,
    });

    final clientError = clientResult.fold((failure) => failure.message, (_) => null);
    if (clientError != null) {
      _finishPaymentWithError(clientError);
      return;
    }

    await _finishPaymentSuccess('Abono registrado correctamente');
  }

  Future<void> _registerGlobalPayment(
    _ClientAccountSummary account,
    _PaymentDraft draft,
  ) async {
    final repository = ref.read(carwashRepositoryProvider);
    final pendingInvoices = List<_InvoiceEntry>.from(account.pendingInvoices)
      ..sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    setState(() => _isLoading = true);

    var remainingPayment = draft.amount;
    var totalPaid = 0.0;

    for (final invoice in pendingInvoices) {
      if (remainingPayment <= 0.01) break;

      final pendingBalance = invoice.pendingAmount;
      if (pendingBalance <= 0.0) continue;

      final payAmount = remainingPayment >= pendingBalance
          ? pendingBalance
          : remainingPayment;
      final now = DateTime.now();
      final paymentId = '${now.millisecondsSinceEpoch}_${invoice.invoiceNumber}';

      final paymentResult = await repository.createDocument('pagos', {
        'id': paymentId,
        'factura_id': invoice.id,
        'cliente_id': account.clientId,
        'empresa_id': widget.companyId,
        'monto': payAmount,
        'metodo_pago': draft.paymentMethod,
        'referencia': draft.reference,
        'fecha_creacion': now.toIso8601String(),
        'creado_por': _webAdminUserId,
        'notas': 'Abono Global: ${draft.notes ?? ''}',
      });

      final paymentError = paymentResult.fold((failure) => failure.message, (_) => null);
      if (paymentError != null) {
        _finishPaymentWithError(paymentError);
        return;
      }

      final newPaidAmount = invoice.paidAmount + payAmount;
      final newStatus =
          newPaidAmount >= invoice.total - 0.01 ? 'pagado' : 'parcial';
      final timestamp = _toTimestampMap(now);

      final invoiceResult = await repository.updateDocument('facturas', invoice.id, {
        'estado_pago': newStatus,
        'monto_pagado': newPaidAmount,
        'fecha_pagado': timestamp,
        'updatedBy': _webAdminUserId,
        'updatedAt': timestamp,
      });

      final invoiceError = invoiceResult.fold((failure) => failure.message, (_) => null);
      if (invoiceError != null) {
        _finishPaymentWithError(invoiceError);
        return;
      }

      remainingPayment -= payAmount;
      totalPaid += payAmount;
    }

    if (totalPaid > 0) {
      final now = DateTime.now();
      final timestamp = _toTimestampMap(now);
      final newBalance = (account.currentBalance - totalPaid).clamp(
        0.0,
        double.infinity,
      ).toDouble();

      final clientResult = await repository.updateDocument('clientes', account.clientId, {
        'saldo_actual': newBalance,
        'updatedBy': _webAdminUserId,
        'updatedAt': timestamp,
      });

      final clientError = clientResult.fold((failure) => failure.message, (_) => null);
      if (clientError != null) {
        _finishPaymentWithError(clientError);
        return;
      }
    }

    await _finishPaymentSuccess('Abono global registrado correctamente');
  }

  Future<void> _finishPaymentSuccess(String message) async {
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _finishPaymentWithError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<_ClientAccountSummary> _buildAccounts({
    required List<Map<String, dynamic>> clients,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> payments,
  }) {
    final paymentsByClient = <String, List<_PaymentEntry>>{};
    for (final row in payments) {
      final clientId = _readString(row, ['cliente_id', 'clientId']);
      if (clientId.isEmpty) continue;
      paymentsByClient.putIfAbsent(clientId, () => []);
      paymentsByClient[clientId]!.add(
        _PaymentEntry(
          id: row['id']?.toString() ?? '',
          invoiceId: _readString(row, ['factura_id', 'invoiceId']),
          amount: _readDouble(row, ['monto', 'amount']),
          paymentMethod: _readString(row, ['metodo_pago', 'paymentMethod']),
          reference: _readNullableString(row, ['referencia', 'reference']),
          notes: _readNullableString(row, ['notas', 'notes']),
          createdAt: _readDate(row, ['fecha_creacion', 'createdAt']),
        ),
      );
    }

    final invoicesByClient = <String, List<_InvoiceEntry>>{};
    for (final row in invoices) {
      final clientId = _readString(row, ['cliente_id', 'clientId']);
      if (clientId.isEmpty) continue;

      final paymentCondition = _readString(
        row,
        ['condicion_pago', 'paymentCondition'],
      ).toLowerCase();
      if (paymentCondition != 'credito') continue;

      final total = _readDouble(row, ['total', 'totalAmount']);
      final paid = _readDouble(row, ['monto_pagado', 'paidAmount']);
      final pending = (total - paid).clamp(0.0, double.infinity).toDouble();
      if (pending <= 0.009) continue;

      final dueDate = _readDate(row, ['fecha_vencimiento', 'dueDate']);
      final status = _resolveInvoiceStatus(
        _readString(row, ['estado_pago', 'paymentStatus']),
        dueDate,
        pending,
      );

      invoicesByClient.putIfAbsent(clientId, () => []);
      invoicesByClient[clientId]!.add(
        _InvoiceEntry(
          id: row['id']?.toString() ?? '',
          invoiceNumber: _readString(row, ['numero_factura', 'invoiceNumber']),
          createdAt: _readDate(row, ['fecha_creacion', 'createdAt']),
          dueDate: dueDate,
          total: total,
          paidAmount: paid,
          pendingAmount: pending,
          paymentStatus: status,
          documentType: _readString(row, ['tipo_documento', 'documentType']),
        ),
      );
    }

    final accounts = <_ClientAccountSummary>[];
    for (final row in clients) {
      final clientId = row['id']?.toString() ?? '';
      if (clientId.isEmpty) continue;

      final pendingInvoices = List<_InvoiceEntry>.from(
        invoicesByClient[clientId] ?? const [],
      )..sort((a, b) {
          final aDate = a.dueDate ?? a.createdAt ?? DateTime(2100);
          final bDate = b.dueDate ?? b.createdAt ?? DateTime(2100);
          return aDate.compareTo(bDate);
        });

      final clientPayments = List<_PaymentEntry>.from(
        paymentsByClient[clientId] ?? const [],
      )..sort((a, b) => (b.createdAt ?? DateTime(1900)).compareTo(
            a.createdAt ?? DateTime(1900),
          ));

      final creditActive = _readBool(row, ['credito_activo', 'creditEnabled']);
      final currentBalance = _readDouble(row, ['saldo_actual', 'currentBalance']);
      final creditLimit = _readDouble(row, ['limite_credito', 'creditLimit']);
      final totalDebt = pendingInvoices.fold<double>(
        0,
        (sum, item) => sum + item.pendingAmount,
      );

      if (!creditActive && pendingInvoices.isEmpty && currentBalance <= 0) {
        continue;
      }

      accounts.add(
        _ClientAccountSummary(
          clientId: clientId,
          clientName: _readString(
            row,
            ['nombre_completo', 'fullName', 'name'],
          ),
          clientRtn: _readNullableString(row, ['rtn']),
          phone: _readNullableString(row, ['telefono', 'phone']),
          creditActive: creditActive,
          creditLimit: creditLimit,
          currentBalance: currentBalance,
          totalDebt: totalDebt,
          pendingInvoices: pendingInvoices,
          payments: clientPayments,
        ),
      );
    }

    accounts.sort((a, b) {
      final debtCompare = b.totalDebt.compareTo(a.totalDebt);
      if (debtCompare != 0) return debtCompare;
      return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
    });

    return accounts;
  }

  String _resolveInvoiceStatus(
    String rawStatus,
    DateTime? dueDate,
    double pendingAmount,
  ) {
    if (pendingAmount <= 0.009) return 'pagado';
    if (dueDate != null && dueDate.isBefore(DateTime.now())) return 'vencido';
    if (rawStatus == 'parcial') return 'parcial';
    return 'pendiente';
  }

  List<_ClientAccountSummary> get _filteredAccounts {
    if (_searchText.trim().isEmpty) return _accounts;
    final query = _searchText.toLowerCase();
    return _accounts.where((account) {
      return account.clientName.toLowerCase().contains(query) ||
          (account.clientRtn?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      return const _EmptyState(
        icon: Icons.business_center_rounded,
        title: 'Selecciona una empresa',
        subtitle:
            'El estado de cuenta necesita una empresa activa para cargar clientes, facturas y pagos.',
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar el estado de cuenta',
        subtitle: _errorMessage!,
        actionLabel: 'Reintentar',
        onAction: _loadData,
      );
    }

    final accounts = _filteredAccounts;
    final selected = _selectedClientId == null
        ? null
        : accounts.cast<_ClientAccountSummary?>().firstWhere(
              (item) => item?.clientId == _selectedClientId,
              orElse: () => accounts.isNotEmpty ? accounts.first : null,
            );
    final totalDebt = accounts.fold<double>(
      0,
      (sum, item) => sum + item.totalDebt,
    );
    final overdueInvoices = accounts.fold<int>(
      0,
      (sum, item) =>
          sum + item.pendingInvoices.where((invoice) => invoice.isOverdue).length,
    );

    if (accounts.isEmpty) {
      return _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No hay clientes con crédito o deuda',
        subtitle:
            'Cuando existan facturas a crédito o clientes con saldo, aparecerán aquí.',
        actionLabel: 'Recargar',
        onAction: _loadData,
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 20, 8, isMobile ? 8 : 20, 12),
      child: Column(
        children: [
          _SummaryStrip(
            totalClients: accounts.length,
            totalDebt: totalDebt,
            overdueInvoices: overdueInvoices,
            searchController: _searchController,
            onSearchChanged: (value) {
              setState(() {
                _searchText = value;
                if (_selectedClientId != null &&
                    !_filteredAccounts.any(
                      (item) => item.clientId == _selectedClientId,
                    )) {
                  _selectedClientId = _filteredAccounts.isNotEmpty
                      ? _filteredAccounts.first.clientId
                      : null;
                }
              });
            },
            onRefresh: _loadData,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isMobile
                ? _MobileAccountView(
                    accounts: accounts,
                    selectedClientId: _selectedClientId,
                    onSelectClient: (clientId) {
                      setState(() => _selectedClientId = clientId);
                    },
                    onGlobalPayment: _openGlobalPayment,
                    onInvoicePayment: _openInvoicePayment,
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 340,
                        child: _ClientListPane(
                          accounts: accounts,
                          selectedClientId: _selectedClientId,
                          onSelectClient: (clientId) {
                            setState(() => _selectedClientId = clientId);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: selected == null
                            ? const _EmptyDetailState()
                            : _AccountDetailPane(
                                account: selected,
                                onGlobalPayment: _openGlobalPayment,
                                onInvoicePayment: _openInvoicePayment,
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return '';
  }

  static String? _readNullableString(
    Map<String, dynamic> row,
    List<String> keys,
  ) {
    final value = _readString(row, keys);
    return value.isEmpty ? null : value;
  }

  static double _readDouble(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static bool _readBool(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return false;
  }

  static DateTime? _readDate(Map<String, dynamic> row, List<String> keys) {
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

  static Map<String, dynamic> _toTimestampMap(DateTime date) {
    final milliseconds = date.millisecondsSinceEpoch;
    return {
      '_seconds': milliseconds ~/ 1000,
      '_nanoseconds': (milliseconds % 1000) * 1000000,
    };
  }
}

class _SummaryStrip extends StatelessWidget {
  final int totalClients;
  final double totalDebt;
  final int overdueInvoices;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  const _SummaryStrip({
    required this.totalClients,
    required this.totalDebt,
    required this.overdueInvoices,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricChip(
                      label: 'Clientes',
                      value: totalClients.toString(),
                      color: const Color(0xFF0EA5E9),
                    ),
                    _MetricChip(
                      label: 'Deuda total',
                      value: currency.format(totalDebt),
                      color: const Color(0xFFEF4444),
                    ),
                    _MetricChip(
                      label: 'Facturas vencidas',
                      value: overdueInvoices.toString(),
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Recargar estado de cuenta',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar cliente o RTN...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
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
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientListPane extends StatelessWidget {
  final List<_ClientAccountSummary> accounts;
  final String? selectedClientId;
  final ValueChanged<String> onSelectClient;

  const _ClientListPane({
    required this.accounts,
    required this.selectedClientId,
    required this.onSelectClient,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final account = accounts[index];
          final isSelected = account.clientId == selectedClientId;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelectClient(account.clientId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.clientName,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if ((account.clientRtn ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'RTN: ${account.clientRtn}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'Pendiente',
                          value: currency.format(account.totalDebt),
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          label: 'Facturas',
                          value: account.pendingInvoices.length.toString(),
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileAccountView extends StatelessWidget {
  final List<_ClientAccountSummary> accounts;
  final String? selectedClientId;
  final ValueChanged<String> onSelectClient;
  final Future<void> Function(_ClientAccountSummary account) onGlobalPayment;
  final Future<void> Function(
    _ClientAccountSummary account,
    _InvoiceEntry invoice,
  )
  onInvoicePayment;

  const _MobileAccountView({
    required this.accounts,
    required this.selectedClientId,
    required this.onSelectClient,
    required this.onGlobalPayment,
    required this.onInvoicePayment,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedClientId == null
        ? accounts.first
        : accounts.firstWhere(
            (item) => item.clientId == selectedClientId,
            orElse: () => accounts.first,
          );

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: _ClientListPane(
            accounts: accounts,
            selectedClientId: selectedClientId,
            onSelectClient: onSelectClient,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _AccountDetailPane(
            account: selected,
            onGlobalPayment: onGlobalPayment,
            onInvoicePayment: onInvoicePayment,
          ),
        ),
      ],
    );
  }
}

class _AccountDetailPane extends StatelessWidget {
  final _ClientAccountSummary account;
  final Future<void> Function(_ClientAccountSummary account) onGlobalPayment;
  final Future<void> Function(
    _ClientAccountSummary account,
    _InvoiceEntry invoice,
  )
  onInvoicePayment;

  const _AccountDetailPane({
    required this.account,
    required this.onGlobalPayment,
    required this.onInvoicePayment,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text(
                    account.clientName.isEmpty
                        ? '?'
                        : account.clientName[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0369A1),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.clientName,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if ((account.clientRtn ?? '').isNotEmpty)
                            _InfoPill(
                              icon: Icons.badge_outlined,
                              label: 'RTN ${account.clientRtn}',
                            ),
                          if ((account.phone ?? '').isNotEmpty)
                            _InfoPill(
                              icon: Icons.phone_outlined,
                              label: account.phone!,
                            ),
                          _InfoPill(
                            icon: Icons.credit_score_rounded,
                            label: account.creditActive
                                ? 'Crédito activo'
                                : 'Crédito inactivo',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailCard(
                  title: 'Saldo actual',
                  value: currency.format(account.currentBalance),
                  color: const Color(0xFFEF4444),
                ),
                _DetailCard(
                  title: 'Límite de crédito',
                  value: currency.format(account.creditLimit),
                  color: const Color(0xFF0EA5E9),
                ),
                _DetailCard(
                  title: 'Disponible',
                  value: currency.format(account.availableCredit),
                  color: const Color(0xFF10B981),
                ),
                _DetailCard(
                  title: 'Facturas pendientes',
                  value: account.pendingInvoices.length.toString(),
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: account.totalDebt <= 0
                    ? null
                    : () => onGlobalPayment(account),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Registrar Abono Global'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Facturas pendientes',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            if (account.pendingInvoices.isEmpty)
              const _EmptyInline(
                text: 'El cliente no tiene facturas pendientes.',
              )
            else
              ...account.pendingInvoices.map(
                (invoice) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InvoiceTile(
                    invoice: invoice,
                    onPay: () => onInvoicePayment(account, invoice),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Historial de pagos',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            if (account.payments.isEmpty)
              const _EmptyInline(
                text: 'No hay pagos registrados para este cliente.',
              )
            else
              ...account.payments.take(10).map(
                (payment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentTile(payment: payment),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _DetailCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final _InvoiceEntry invoice;
  final VoidCallback onPay;

  const _InvoiceTile({
    required this.invoice,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );
    final formatter = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: invoice.isOverdue
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNumber.isEmpty
                      ? 'Factura sin número'
                      : invoice.invoiceNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              _StatusBadge(status: invoice.paymentStatus),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (invoice.createdAt != null)
                Text(
                  'Emisión: ${formatter.format(invoice.createdAt!)}',
                  style: _mutedTextStyle,
                ),
              if (invoice.dueDate != null)
                Text(
                  'Vence: ${formatter.format(invoice.dueDate!)}',
                  style: _mutedTextStyle.copyWith(
                    color: invoice.isOverdue
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF64748B),
                    fontWeight: invoice.isOverdue
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              if (invoice.documentType.isNotEmpty)
                Text(
                  'Tipo: ${invoice.documentType}',
                  style: _mutedTextStyle,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AmountColumn(
                  label: 'Total',
                  value: currency.format(invoice.total),
                ),
              ),
              Expanded(
                child: _AmountColumn(
                  label: 'Pagado',
                  value: currency.format(invoice.paidAmount),
                ),
              ),
              Expanded(
                child: _AmountColumn(
                  label: 'Pendiente',
                  value: currency.format(invoice.pendingAmount),
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: invoice.pendingAmount <= 0 ? null : onPay,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Abonar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final _PaymentEntry payment;

  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'L. ',
      decimalDigits: 2,
    );
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.createdAt != null
                      ? formatter.format(payment.createdAt!)
                      : 'Sin fecha',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.paymentMethod.toUpperCase(),
                  style: _mutedTextStyle,
                ),
                if ((payment.reference ?? '').isNotEmpty)
                  Text('Ref: ${payment.reference}', style: _mutedTextStyle),
                if ((payment.notes ?? '').isNotEmpty)
                  Text(payment.notes!, style: _mutedTextStyle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currency.format(payment.amount),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _AmountColumn({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _mutedTextStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;

    switch (status) {
      case 'vencido':
        background = const Color(0xFFFEE2E2);
        foreground = const Color(0xFFB91C1C);
        break;
      case 'parcial':
        background = const Color(0xFFFEF3C7);
        foreground = const Color(0xFFB45309);
        break;
      case 'pagado':
        background = const Color(0xFFDCFCE7);
        foreground = const Color(0xFF15803D);
        break;
      default:
        background = const Color(0xFFE0F2FE);
        foreground = const Color(0xFF0369A1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _RegisterPaymentSheet extends StatefulWidget {
  final _ClientAccountSummary account;
  final _InvoiceEntry? invoice;
  final List<_InvoiceEntry>? pendingInvoices;

  const _RegisterPaymentSheet({
    required this.account,
    this.invoice,
    this.pendingInvoices,
  });

  @override
  State<_RegisterPaymentSheet> createState() => _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends State<_RegisterPaymentSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'efectivo';
  String? _amountError;
  late double _remainingBalance;
  List<_PaymentPreviewLine> _preview = const [];

  bool get _isGlobal => widget.invoice == null;

  @override
  void initState() {
    super.initState();
    if (_isGlobal) {
      _remainingBalance = widget.account.totalDebt;
      _amountController.text = '';
    } else {
      _remainingBalance = widget.invoice!.pendingAmount;
      _amountController.text = _remainingBalance.toStringAsFixed(2);
    }
    _amountController.addListener(_validateAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_validateAmount);
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      setState(() => _amountError = 'Requerido');
      return;
    }

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Monto inválido');
      return;
    }

    if (amount > _remainingBalance + 0.01) {
      setState(() => _amountError = 'El monto excede el saldo pendiente');
      return;
    }

    if (_amountError != null) {
      setState(() => _amountError = null);
    }

    if (_isGlobal) {
      _calculatePreview(amount);
    }
  }

  void _calculatePreview(double paymentAmount) {
    final invoices = List<_InvoiceEntry>.from(widget.pendingInvoices ?? const [])
      ..sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    if (paymentAmount <= 0) {
      setState(() => _preview = const []);
      return;
    }

    double remaining = paymentAmount;
    final preview = <_PaymentPreviewLine>[];

    for (final invoice in invoices) {
      if (remaining <= 0.001) break;
      final pending = invoice.pendingAmount;
      if (pending <= 0) continue;

      final payAmount = remaining >= pending ? pending : remaining;
      preview.add(
        _PaymentPreviewLine(
          invoiceNumber: invoice.invoiceNumber,
          documentType: invoice.documentType,
          originalPending: pending,
          payment: payAmount,
          newBalance: pending - payAmount,
        ),
      );
      remaining -= payAmount;
    }

    setState(() => _preview = preview);
  }

  void _submit() {
    _validateAmount();
    if (_amountError != null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;

    Navigator.of(context).pop(
      _PaymentDraft(
        amount: amount,
        paymentMethod: _paymentMethod,
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isGlobal ? 'Registrar Abono Global' : 'Registrar Abono';
    final subtitle = _isGlobal
        ? widget.account.clientName
        : widget.invoice!.invoiceNumber;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(subtitle, style: _mutedTextStyle),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isGlobal
                                  ? 'DEUDA TOTAL PENDIENTE'
                                  : 'SALDO PENDIENTE FACTURA',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'L. ${_remainingBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isGlobal
                                  ? 'Se abonará a las facturas más antiguas primero.'
                                  : 'Total factura: L. ${widget.invoice!.total.toStringAsFixed(2)}',
                              style: _mutedTextStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Monto a abonar',
                          prefixText: 'L. ',
                          errorText: _amountError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Método de pago',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'efectivo',
                            child: Text('Efectivo'),
                          ),
                          DropdownMenuItem(
                            value: 'transferencia',
                            child: Text('Transferencia'),
                          ),
                          DropdownMenuItem(
                            value: 'tarjeta',
                            child: Text('Tarjeta'),
                          ),
                          DropdownMenuItem(
                            value: 'cheque',
                            child: Text('Cheque'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _paymentMethod = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          labelText: 'Referencia',
                          hintText: 'N° cheque, transferencia, etc.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_preview.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Distribución del abono (FIFO)',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.2),
                              2: FlexColumnWidth(1.2),
                              3: FlexColumnWidth(1.2),
                            },
                            children: [
                              const TableRow(
                                children: [
                                  _HeaderCell('Factura'),
                                  _HeaderCell('Saldo'),
                                  _HeaderCell('Abono'),
                                  _HeaderCell('Resto'),
                                ],
                              ),
                              ..._preview.map(
                                (line) => TableRow(
                                  children: [
                                    _ValueCell(
                                      '${line.invoiceNumber}\n${line.documentType}',
                                      alignLeft: true,
                                    ),
                                    _ValueCell(
                                      line.originalPending.toStringAsFixed(2),
                                    ),
                                    _ValueCell(
                                      line.payment.toStringAsFixed(2),
                                      color: const Color(0xFF15803D),
                                    ),
                                    _ValueCell(
                                      line.newBalance <= 0.01
                                          ? 'OK'
                                          : line.newBalance.toStringAsFixed(2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _amountError != null ? null : _submit,
                        icon: const Icon(Icons.payments_rounded),
                        label: const Text('Registrar Pago'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String text;
  final bool alignLeft;
  final Color? color;

  const _ValueCell(
    this.text, {
    this.alignLeft = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: alignLeft ? TextAlign.left : TextAlign.right,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
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
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
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

class _EmptyInline extends StatelessWidget {
  final String text;

  const _EmptyInline({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text, style: _mutedTextStyle),
    );
  }
}

class _EmptyDetailState extends StatelessWidget {
  const _EmptyDetailState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.person_search_rounded,
      title: 'Selecciona un cliente',
      subtitle:
          'El detalle del estado de cuenta se mostrará cuando elijas un cliente del listado.',
    );
  }
}

final TextStyle _mutedTextStyle = GoogleFonts.outfit(
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

class _ClientAccountSummary {
  final String clientId;
  final String clientName;
  final String? clientRtn;
  final String? phone;
  final bool creditActive;
  final double creditLimit;
  final double currentBalance;
  final double totalDebt;
  final List<_InvoiceEntry> pendingInvoices;
  final List<_PaymentEntry> payments;

  const _ClientAccountSummary({
    required this.clientId,
    required this.clientName,
    required this.clientRtn,
    required this.phone,
    required this.creditActive,
    required this.creditLimit,
    required this.currentBalance,
    required this.totalDebt,
    required this.pendingInvoices,
    required this.payments,
  });

  double get availableCredit {
    final value = creditLimit - currentBalance;
    return value < 0 ? 0 : value;
  }
}

class _InvoiceEntry {
  final String id;
  final String invoiceNumber;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final double total;
  final double paidAmount;
  final double pendingAmount;
  final String paymentStatus;
  final String documentType;

  const _InvoiceEntry({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.dueDate,
    required this.total,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    required this.documentType,
  });

  bool get isOverdue => paymentStatus == 'vencido';
}

class _PaymentEntry {
  final String id;
  final String invoiceId;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime? createdAt;

  const _PaymentEntry({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.notes,
    required this.createdAt,
  });
}

class _PaymentDraft {
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? notes;

  const _PaymentDraft({
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.notes,
  });
}

class _PaymentPreviewLine {
  final String invoiceNumber;
  final String documentType;
  final double originalPending;
  final double payment;
  final double newBalance;

  const _PaymentPreviewLine({
    required this.invoiceNumber,
    required this.documentType,
    required this.originalPending,
    required this.payment,
    required this.newBalance,
  });
}
