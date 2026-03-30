import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/repositories/carwash_repository.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashInvoiceView extends ConsumerStatefulWidget {
  final String? companyId;

  const CarwashInvoiceView({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<CarwashInvoiceView> createState() => _CarwashInvoiceViewState();
}

class _CarwashInvoiceViewState extends ConsumerState<CarwashInvoiceView>
    with SingleTickerProviderStateMixin {
  static const String _webAdminUserId = 'web-admin';

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rtnController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String _searchText = '';

  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _vehicles = const [];
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _washTypes = const [];
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _fiscalConfigs = const [];
  List<Map<String, dynamic>> _invoices = const [];

  String? _selectedBranchId;
  String? _selectedVehicleId;
  String _selectedDocType = 'invoice';
  String _paymentCondition = 'contado';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  List<_InvoiceDraftItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(covariant CarwashInvoiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rtnController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _branches = const [];
          _vehicles = const [];
          _clients = const [];
          _washTypes = const [];
          _products = const [];
          _fiscalConfigs = const [];
          _invoices = const [];
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
      _loadCollection(repository, 'sucursales', companyId),
      _loadCollection(repository, 'vehiculos', companyId),
      _loadCollection(repository, 'clientes', companyId),
      _loadCollection(repository, 'tiposLavados', companyId),
      _loadCollection(repository, 'productos', companyId),
      _loadCollection(repository, 'facturacion', companyId),
      _loadCollection(repository, 'facturas', companyId),
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

    final branches = results[0].rows;
    final selectedBranchId = _selectedBranchId != null &&
            branches.any((row) => row['id']?.toString() == _selectedBranchId)
        ? _selectedBranchId
        : (branches.isNotEmpty ? branches.first['id']?.toString() : null);

    setState(() {
      _branches = branches;
      _vehicles = results[1].rows;
      _clients = results[2].rows;
      _washTypes = results[3].rows;
      _products = results[4].rows;
      _fiscalConfigs = results[5].rows;
      _invoices = results[6].rows;
      _selectedBranchId = selectedBranchId;
      _isLoading = false;
    });

    _syncSelectedVehicle();
  }

  Future<_LoadRows> _loadCollection(
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
      (failure) => _LoadRows(const [], failure.message),
      (response) => _LoadRows(response.data, null),
    );
  }

  List<Map<String, dynamic>> get _branchVehicles {
    return _vehicles.where((vehicle) {
      final branchId = vehicle['sucursal_id']?.toString();
      final status = (vehicle['estado']?.toString() ?? '').toLowerCase();
      return branchId == _selectedBranchId && status == 'washed';
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    final invoices = _invoices.toList()
      ..sort((a, b) => (_readDate(b, ['fecha_creacion']) ?? DateTime(1900))
          .compareTo(_readDate(a, ['fecha_creacion']) ?? DateTime(1900)));

    if (_searchText.trim().isEmpty) return invoices;
    final query = _searchText.toLowerCase();
    return invoices.where((row) {
      final clientName = _readString(row, ['cliente_nombre']).toLowerCase();
      final number = _readString(row, ['numero_factura']).toLowerCase();
      return clientName.contains(query) || number.contains(query);
    }).toList();
  }

  Map<String, dynamic>? get _selectedVehicle {
    if (_selectedVehicleId == null) return null;
    for (final vehicle in _branchVehicles) {
      if (vehicle['id']?.toString() == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedClient {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return null;
    final clientId = vehicle['cliente_id']?.toString();
    if (clientId == null || clientId.isEmpty) return null;
    for (final client in _clients) {
      if (client['id']?.toString() == clientId) return client;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedBranch {
    if (_selectedBranchId == null) return null;
    for (final branch in _branches) {
      if (branch['id']?.toString() == _selectedBranchId) return branch;
    }
    return null;
  }

  Map<String, dynamic>? get _activeFiscalConfig {
    if (_selectedBranchId == null) return null;
    for (final row in _fiscalConfigs) {
      final branchId = row['sucursal_id']?.toString();
      final active = row['activo'] == true || row['activo']?.toString() == 'true';
      if (branchId == _selectedBranchId && active) return row;
    }
    return null;
  }

  void _syncSelectedVehicle() {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      final nextVehicle = _branchVehicles.isNotEmpty
          ? _branchVehicles.first['id']?.toString()
          : null;
      if (nextVehicle != _selectedVehicleId || _items.isNotEmpty) {
        setState(() {
          _selectedVehicleId = nextVehicle;
          _items = const [];
        });
        if (nextVehicle != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelectedVehicle());
        }
      }
      return;
    }

    final client = _selectedClient;
    if (client != null) {
      _rtnController.text = _readString(client, ['rtn']);
      _addressController.text = _readString(client, ['direccion']);
      final creditDays = _readInt(client, ['dias_credito'], fallback: 30);
      _dueDate = DateTime.now().add(Duration(days: creditDays > 0 ? creditDays : 30));
    }

    setState(() {
      _items = _buildServiceItems(vehicle);
    });
  }

  List<_InvoiceDraftItem> _buildServiceItems(Map<String, dynamic> vehicle) {
    final services = vehicle['servicios'];
    if (services is! List) return const [];
    final vehicleType = _readString(vehicle, ['tipo_vehiculo']);
    final items = <_InvoiceDraftItem>[];

    for (final serviceIdRaw in services) {
      final serviceId = serviceIdRaw.toString();
      final washType = _washTypes.cast<Map<String, dynamic>?>().firstWhere(
            (row) => row?['id']?.toString() == serviceId,
            orElse: () => null,
          );
      if (washType == null) continue;

      final prices = washType['precios'];
      double price = 0;
      if (prices is Map) {
        final dynamic selectedPrice =
            prices[vehicleType] ?? prices[vehicleType.toLowerCase()];
        if (selectedPrice is num) {
          price = selectedPrice.toDouble();
        } else if (selectedPrice != null) {
          price = double.tryParse(selectedPrice.toString()) ?? 0;
        }
      }
      if (price <= 0) continue;

      items.add(
        _InvoiceDraftItem(
          description: _readString(washType, ['nombre']),
          quantity: 1,
          unitPrice: price,
          taxType: '15',
          sourceId: serviceId,
          sourceType: 'servicio',
        ),
      );
    }

    return items;
  }

  void _addProduct(Map<String, dynamic> product) {
    final price = _readDouble(product, ['precio']);
    setState(() {
      _items = [
        ..._items,
        _InvoiceDraftItem(
          description: _readString(product, ['nombre']),
          quantity: 1,
          unitPrice: price,
          taxType: '15',
          sourceId: product['id']?.toString(),
          sourceType: 'producto',
        ),
      ];
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  double get _subtotal => _items.fold<double>(0, (sum, item) => sum + item.total);
  double get _isv15 => _selectedDocType == 'receipt' ? 0.0 : _subtotal * 0.15;
  double get _total => _subtotal + _isv15;

  Future<void> _emitInvoice() async {
    final companyId = widget.companyId;
    final vehicle = _selectedVehicle;
    final client = _selectedClient;
    final branch = _selectedBranch;
    if (companyId == null ||
        vehicle == null ||
        client == null ||
        branch == null ||
        _items.isEmpty) {
      _showMessage('Completa sucursal, vehículo, cliente e items.', isError: true);
      return;
    }

    final repository = ref.read(carwashRepositoryProvider);
    final now = DateTime.now();
    final fiscalConfig = _activeFiscalConfig;

    String invoiceNumber = 'REC-${now.millisecondsSinceEpoch}';
    int? sequenceNumber;

    if (_selectedDocType == 'invoice') {
      if (fiscalConfig == null || _readString(fiscalConfig, ['cai']).isEmpty) {
        _showMessage('Configuración incompleta (CAI).', isError: true);
        return;
      }

      final deadline = _readDate(fiscalConfig, ['fecha_limite']);
      if (deadline != null && now.isAfter(deadline)) {
        _showMessage('CAI vencido para esta sucursal.', isError: true);
        return;
      }

      final currentSequence = _readInt(fiscalConfig, ['secuencia_actual']);
      final rangeMax = _readInt(fiscalConfig, ['rango_max']);
      if (rangeMax > 0 && currentSequence > rangeMax) {
        _showMessage('Rango fiscal agotado.', isError: true);
        return;
      }

      final establishment = _readString(branch, ['numero_establecimiento'])
          .padLeft(3, '0');
      final emissionPoint =
          _readString(fiscalConfig, ['punto_emision']).padLeft(3, '0');
      final docTypeCode =
          _readString(fiscalConfig, ['tipo_documento']).padLeft(2, '0');
      sequenceNumber = currentSequence;
      invoiceNumber =
          '$establishment-$emissionPoint-$docTypeCode-${currentSequence.toString().padLeft(8, '0')}';
    }

    if (_paymentCondition == 'credito') {
      final creditEnabled = _readBool(client, ['credito_activo']);
      if (!creditEnabled) {
        _showMessage('El cliente no tiene crédito habilitado.', isError: true);
        return;
      }

      final limit = _readDouble(client, ['limite_credito']);
      final currentBalance = _readDouble(client, ['saldo_actual']);
      if (limit > 0 && currentBalance + _total > limit) {
        _showMessage('La venta excede el límite de crédito.', isError: true);
        return;
      }
    }

    setState(() => _isProcessing = true);

    final invoiceId = now.millisecondsSinceEpoch.toString();
    final invoicePayload = {
      'id': invoiceId,
      'empresa_id': companyId,
      'sucursal_id': branch['id']?.toString(),
      'cliente_id': client['id']?.toString(),
      'vehiculo_id': vehicle['id']?.toString(),
      'cliente_nombre': _readString(client, ['nombre_completo']),
      'cliente_rtn': _rtnController.text.trim(),
      'numero_factura': invoiceNumber,
      'items': _items.map((item) => item.toMap()).toList(),
      'subtotal': _subtotal,
      'descuento_total': 0.0,
      'monto_exento': 0.0,
      'gravado_15': _subtotal,
      'gravado_18': 0.0,
      'isv_15': _isv15,
      'isv_18': 0.0,
      'total': _total,
      'fecha_creacion': _timestamp(now),
      'tipo_documento': _selectedDocType,
      'cai': fiscalConfig?['cai'],
      'fecha_limite_cai': fiscalConfig != null
          ? _timestamp(_readDate(fiscalConfig, ['fecha_limite']) ?? now)
          : null,
      'rango_min': fiscalConfig?['rango_min'],
      'rango_max': fiscalConfig?['rango_max'],
      'numero_secuencia': sequenceNumber,
      'condicion_pago': _paymentCondition,
      'estado_pago': _paymentCondition == 'credito' ? 'pendiente' : 'pagado',
      'fecha_vencimiento':
          _paymentCondition == 'credito' ? _timestamp(_dueDate) : null,
      'monto_pagado': _paymentCondition == 'credito' ? 0.0 : _total,
      'fecha_pagado':
          _paymentCondition == 'contado' ? _timestamp(now) : null,
      'createdBy': _webAdminUserId,
    };

    final createResult = await repository.createDocument('facturas', invoicePayload);
    final createError = createResult.fold((failure) => failure.message, (_) => null);
    if (createError != null) {
      _finishInvoiceError(createError);
      return;
    }

    if (_selectedDocType == 'invoice' && fiscalConfig != null) {
      final updateConfigResult = await repository.updateDocument(
        'facturacion',
        fiscalConfig['id']?.toString() ?? '',
        {
          'secuencia_actual': (sequenceNumber ?? 0) + 1,
          'updatedBy': _webAdminUserId,
          'updatedAt': _timestamp(now),
        },
      );
      final updateConfigError =
          updateConfigResult.fold((failure) => failure.message, (_) => null);
      if (updateConfigError != null) {
        _finishInvoiceError(updateConfigError);
        return;
      }
    }

    final vehicleUpdate = await repository.updateDocument(
      'vehiculos',
      vehicle['id']?.toString() ?? '',
      {
        'estado': 'finished',
        'updatedBy': _webAdminUserId,
        'updatedAt': _timestamp(now),
      },
    );
    final vehicleError = vehicleUpdate.fold((failure) => failure.message, (_) => null);
    if (vehicleError != null) {
      _finishInvoiceError(vehicleError);
      return;
    }

    final shouldUpdateClient =
        _paymentCondition == 'credito' ||
        _rtnController.text.trim() != _readString(client, ['rtn']) ||
        _addressController.text.trim() != _readString(client, ['direccion']);

    if (shouldUpdateClient) {
      final newBalance = _paymentCondition == 'credito'
          ? (_readDouble(client, ['saldo_actual']) + _total).toDouble()
          : _readDouble(client, ['saldo_actual']);
      final clientUpdate = await repository.updateDocument(
        'clientes',
        client['id']?.toString() ?? '',
        {
          'saldo_actual': newBalance,
          'updatedBy': _webAdminUserId,
          'updatedAt': _timestamp(now),
          if (_rtnController.text.trim().isNotEmpty) 'rtn': _rtnController.text.trim(),
          if (_addressController.text.trim().isNotEmpty)
            'direccion': _addressController.text.trim(),
        },
      );
      final clientError = clientUpdate.fold((failure) => failure.message, (_) => null);
      if (clientError != null) {
        _finishInvoiceError(clientError);
        return;
      }
    }

    await _loadData();
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _selectedVehicleId = null;
      _items = const [];
    });
    _showMessage('Factura emitida correctamente.');
  }

  void _finishInvoiceError(String message) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showMessage(message, isError: true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      return const _InvoiceEmptyState(
        icon: Icons.business_center_rounded,
        title: 'Selecciona una empresa',
        subtitle:
            'La emisión de facturas necesita una empresa activa para cargar sucursales, vehículos y configuración fiscal.',
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _InvoiceEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar facturación',
        subtitle: _errorMessage!,
        actionLabel: 'Reintentar',
        onAction: _loadData,
      );
    }

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
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0EA5E9),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0EA5E9),
              tabs: const [
                Tab(text: 'Emitir'),
                Tab(text: 'Historial'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmitTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmitTab() {
    final client = _selectedClient;
    final branch = _selectedBranch;
    final fiscalConfig = _activeFiscalConfig;
    final canInvoice =
        fiscalConfig != null && _readString(fiscalConfig, ['cai']).isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _FormCard(
          title: 'Contexto',
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: _inputDecoration('Sucursal'),
              items: _branches
                  .map(
                    (row) => DropdownMenuItem<String>(
                      value: row['id']?.toString(),
                      child: Text(_readString(row, ['nombre'])),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBranchId = value;
                  _selectedVehicleId = null;
                });
                _syncSelectedVehicle();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedVehicleId,
              decoration: _inputDecoration('Vehículo listo para facturar'),
              items: _branchVehicles
                  .map(
                    (row) => DropdownMenuItem<String>(
                      value: row['id']?.toString(),
                      child: Text(
                        '${_readString(row, ['nombre_cliente'])} • ${_readString(row, ['tipo_vehiculo'])}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedVehicleId = value);
                _syncSelectedVehicle();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'Documento',
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDocType,
              decoration: _inputDecoration('Tipo de documento'),
              items: [
                DropdownMenuItem(
                  value: 'invoice',
                  enabled: canInvoice,
                  child: Text(
                    canInvoice ? 'Factura' : 'Factura (sin CAI activo)',
                  ),
                ),
                const DropdownMenuItem(
                  value: 'receipt',
                  child: Text('Recibo'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedDocType = value);
              },
            ),
            if (!canInvoice) ...[
              const SizedBox(height: 10),
              Text(
                'Esta sucursal no tiene CAI activo. Solo se puede emitir recibo.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (branch != null && fiscalConfig != null) ...[
              const SizedBox(height: 10),
              Text(
                'Establecimiento: ${_readString(branch, ['numero_establecimiento']).padLeft(3, '0')} • Punto: ${_readString(fiscalConfig, ['punto_emision']).padLeft(3, '0')} • CAI: ${_readString(fiscalConfig, ['cai'])}',
                style: _mutedStyle,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'Cliente',
          children: [
            Text(
              client == null
                  ? 'Selecciona un vehículo.'
                  : _readString(client, ['nombre_completo']),
              style: _strongStyle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rtnController,
              decoration: _inputDecoration('RTN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: _inputDecoration('Dirección'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'Items',
          children: [
            if (_items.isEmpty)
              Text('No hay items cargados.', style: _mutedStyle)
            else
              ..._items.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DraftItemTile(
                    item: entry.value,
                    onDelete: () {
                      setState(() {
                        final mutable = _items.toList();
                        mutable.removeAt(entry.key);
                        _items = mutable;
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: null,
              decoration: _inputDecoration('Agregar producto'),
              items: _products
                  .where((row) {
                    final active =
                        row['activo'] == true || row['activo']?.toString() == 'true';
                    if (!active) return false;
                    final branchIds = row['sucursal_ids'];
                    if (_selectedBranchId == null) return true;
                    if (branchIds is List && branchIds.isNotEmpty) {
                      return branchIds
                          .map((item) => item.toString())
                          .contains(_selectedBranchId);
                    }
                    return true;
                  })
                  .map(
                    (row) => DropdownMenuItem<String>(
                      value: row['id']?.toString(),
                      child: Text(
                        '${_readString(row, ['nombre'])} • L. ${_readDouble(row, ['precio']).toStringAsFixed(2)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final product = _products.cast<Map<String, dynamic>?>().firstWhere(
                      (row) => row?['id']?.toString() == value,
                      orElse: () => null,
                    );
                if (product != null) _addProduct(product);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'Pago',
          children: [
            DropdownButtonFormField<String>(
              value: _paymentCondition,
              decoration: _inputDecoration('Condición de pago'),
              items: const [
                DropdownMenuItem(value: 'contado', child: Text('Contado')),
                DropdownMenuItem(value: 'credito', child: Text('Crédito')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _paymentCondition = value);
              },
            ),
            if (_paymentCondition == 'credito') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vence: ${DateFormat('dd/MM/yyyy').format(_dueDate)}',
                      style: _strongStyle,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Cambiar fecha'),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'Totales',
          children: [
            _totalRow('Subtotal', _subtotal),
            _totalRow('ISV 15%', _isv15),
            const Divider(),
            _totalRow('Total', _total, highlight: true),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _emitInvoice,
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_rounded),
          label: Text(
            _isProcessing
                ? 'Procesando...'
                : 'Emitir ${_selectedDocType == 'invoice' ? 'Factura' : 'Recibo'}',
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final invoices = _filteredInvoices;
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          decoration: _inputDecoration('Buscar cliente o número de factura'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: invoices.isEmpty
              ? const _InvoiceEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No hay facturas emitidas',
                  subtitle: 'Los documentos emitidos aparecerán aquí.',
                )
              : ListView.separated(
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = invoices[index];
                    final total = _readDouble(row, ['total']);
                    final date = _readDate(row, ['fecha_creacion']);
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
                                  _readString(row, ['numero_factura']),
                                  style: _strongStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _readString(row, ['cliente_nombre']),
                                  style: _mutedStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date != null
                                      ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                                      : 'Sin fecha',
                                  style: _mutedStyle,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'L. ${total.toStringAsFixed(2)}',
                            style: _strongStyle,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: highlight ? _strongStyle : _mutedStyle),
          Text(
            'L. ${value.toStringAsFixed(2)}',
            style: highlight ? _strongStyle : _mutedStyle,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  static String _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final stringValue = value.toString().trim();
      if (stringValue.isNotEmpty) return stringValue;
    }
    return '';
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

  static int _readInt(
    Map<String, dynamic> row,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
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

  static Map<String, dynamic> _timestamp(DateTime value) {
    final ms = value.millisecondsSinceEpoch;
    return {
      '_seconds': ms ~/ 1000,
      '_nanoseconds': (ms % 1000) * 1000000,
    };
  }
}

class _DraftItemTile extends StatelessWidget {
  final _InvoiceDraftItem item;
  final VoidCallback onDelete;

  const _DraftItemTile({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: _strongStyle),
                const SizedBox(height: 4),
                Text(
                  '${item.sourceType.toUpperCase()} • ${item.quantity.toStringAsFixed(0)} x L. ${item.unitPrice.toStringAsFixed(2)}',
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'L. ${item.total.toStringAsFixed(2)}',
            style: _strongStyle,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _strongStyle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InvoiceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InvoiceEmptyState({
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
            Text(subtitle, style: _mutedStyle, textAlign: TextAlign.center),
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

class _LoadRows {
  final List<Map<String, dynamic>> rows;
  final String? errorMessage;

  const _LoadRows(this.rows, this.errorMessage);
}

class _InvoiceDraftItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double discount;
  final String taxType;
  final String? sourceId;
  final String sourceType;

  const _InvoiceDraftItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.taxType = '15',
    this.sourceId,
    required this.sourceType,
  });

  double get total => (unitPrice * quantity) - discount;

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'total': total,
      'taxType': taxType,
    };
  }
}

final TextStyle _mutedStyle = GoogleFonts.outfit(
  fontSize: 12,
  color: const Color(0xFF64748B),
  fontWeight: FontWeight.w500,
);

final TextStyle _strongStyle = GoogleFonts.outfit(
  fontSize: 15,
  color: const Color(0xFF0F172A),
  fontWeight: FontWeight.w700,
);
