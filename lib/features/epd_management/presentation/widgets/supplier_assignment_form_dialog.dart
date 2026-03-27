import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SupplierAssignmentFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;
  final List<Map<String, dynamic>> supplierOptions;
  final List<Map<String, dynamic>> branchOptions;
  final List<Map<String, dynamic>> productOptions;

  const SupplierAssignmentFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
    required this.supplierOptions,
    required this.branchOptions,
    required this.productOptions,
  });

  @override
  State<SupplierAssignmentFormDialog> createState() =>
      _SupplierAssignmentFormDialogState();
}

class _SupplierAssignmentFormDialogState
    extends State<SupplierAssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _supplierId;
  String? _branchId;
  late bool _isGlobal;
  late bool _isActive;
  late final Set<String> _selectedProductIds;

  @override
  void initState() {
    super.initState();
    _supplierId = _pickExisting(
      (widget.initialData['proveedorId'] ?? '').toString(),
      widget.supplierOptions,
    );

    final rawBranch = (widget.initialData['sucursalId'] ?? '')
        .toString()
        .trim();
    _branchId = _pickExisting(rawBranch, widget.branchOptions);
    _isGlobal = rawBranch.isEmpty || rawBranch.toUpperCase() == 'GLOBAL';

    _isActive = _toFlag(widget.initialData['activo'] ?? 1);

    _selectedProductIds = _extractProductIds(
      widget.initialData,
    ).where(_productExists).toSet();
  }

  String? _pickExisting(String value, List<Map<String, dynamic>> options) {
    if (value.trim().isEmpty) return null;
    final exists = options.any((o) => o['value']?.toString() == value);
    return exists ? value : null;
  }

  bool _toFlag(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue > 0;
    final text = rawValue?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si';
  }

  bool _productExists(String productId) {
    return widget.productOptions.any(
      (o) => o['value']?.toString() == productId,
    );
  }

  List<String> _extractProductIds(Map<String, dynamic> data) {
    final values = <String>[];
    void add(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !values.contains(text)) {
        values.add(text);
      }
    }

    final rawDirect = data['productoIds'] ?? data['productoId'];
    if (rawDirect is Iterable) {
      for (final item in rawDirect) {
        add(item);
      }
    } else {
      add(rawDirect);
    }

    final rawProducts = data['productos'];
    if (rawProducts is Iterable) {
      for (final item in rawProducts) {
        if (item is Map) {
          add(item['productoId'] ?? item['IdProducto']);
        }
      }
    }

    return values;
  }

  InputDecoration _decoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.6),
      ),
    );
  }

  List<DropdownMenuItem<String>> _toItems(List<Map<String, dynamic>> options) {
    return options
        .map(
          (o) => DropdownMenuItem<String>(
            value: o['value']?.toString() ?? '',
            child: Text(o['label']?.toString() ?? ''),
          ),
        )
        .toList();
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un producto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = Map<String, dynamic>.from(widget.initialData)
      ..['proveedorId'] = _supplierId ?? ''
      ..['sucursalId'] = _isGlobal ? null : (_branchId ?? '')
      ..['productoIds'] = _selectedProductIds.toList()
      ..['activo'] = _isActive ? 1 : 0;

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Widget _buildProductsCard() {
    if (widget.productOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          'No hay productos disponibles para la empresa seleccionada.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.productOptions.map((option) {
          final value = option['value']?.toString() ?? '';
          final label = option['label']?.toString() ?? value;
          final isSelected = _selectedProductIds.contains(value);
          return FilterChip(
            label: Text(label, overflow: TextOverflow.ellipsis),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedProductIds.add(value);
                } else {
                  _selectedProductIds.remove(value);
                }
              });
            },
            selectedColor: const Color(0xFFDDE7FF),
            checkmarkColor: const Color(0xFF1E3A8A),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFCBD5E1),
            ),
            labelStyle: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 700;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (twoCols)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel('Proveedor'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _supplierId,
                                      decoration: _decoration(
                                        'Selecciona proveedor',
                                      ),
                                      items: _toItems(widget.supplierOptions),
                                      onChanged: (v) =>
                                          setState(() => _supplierId = v),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Selecciona un proveedor'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel('Alcance'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _isGlobal ? 'GLOBAL' : 'BRANCH',
                                      decoration: _decoration(
                                        'Selecciona alcance',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'GLOBAL',
                                          child: Text(
                                            'Global (todas las sucursales)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'BRANCH',
                                          child: Text('Por sucursal'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _isGlobal = v == 'GLOBAL';
                                          if (_isGlobal) _branchId = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _fieldLabel('Proveedor'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _supplierId,
                            decoration: _decoration('Selecciona proveedor'),
                            items: _toItems(widget.supplierOptions),
                            onChanged: (v) => setState(() => _supplierId = v),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecciona un proveedor'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _fieldLabel('Alcance'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _isGlobal ? 'GLOBAL' : 'BRANCH',
                            decoration: _decoration('Selecciona alcance'),
                            items: const [
                              DropdownMenuItem(
                                value: 'GLOBAL',
                                child: Text('Global (todas las sucursales)'),
                              ),
                              DropdownMenuItem(
                                value: 'BRANCH',
                                child: Text('Por sucursal'),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _isGlobal = v == 'GLOBAL';
                                if (_isGlobal) _branchId = null;
                              });
                            },
                          ),
                        ],
                        if (!_isGlobal) ...[
                          const SizedBox(height: 12),
                          _fieldLabel('Sucursal'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _branchId,
                            decoration: _decoration('Selecciona sucursal'),
                            items: _toItems(widget.branchOptions),
                            onChanged: (v) => setState(() => _branchId = v),
                            validator: (v) {
                              if (_isGlobal) return null;
                              if (v == null || v.isEmpty) {
                                return 'Selecciona una sucursal';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _fieldLabel('Productos asignados'),
                            const SizedBox(width: 8),
                            Text(
                              '(${_selectedProductIds.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildProductsCard(),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: _isActive,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Activo',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Asignacion activa'
                                : 'Asignacion inactiva',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            widget.isEdit ? 'Guardar cambios' : 'Crear',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
