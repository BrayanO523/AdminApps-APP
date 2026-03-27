import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ComboFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;
  final List<Map<String, dynamic>> productOptions;
  final List<Map<String, dynamic>> branchOptions;
  final Future<String> Function(List<int> bytes, String storagePath)?
  onUploadImage;

  const ComboFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
    required this.productOptions,
    required this.branchOptions,
    this.onUploadImage,
  });

  @override
  State<ComboFormDialog> createState() => _ComboFormDialogState();
}

class _ComboFormDialogState extends State<ComboFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _imageUrlCtrl;

  final Set<String> _selectedBranchIds = {};
  final List<_ComboItemDraft> _items = [];
  final Map<String, String> _productNameById = {};

  String? _productToAdd;
  bool _isActive = true;
  bool _isUploading = false;
  Uint8List? _pendingImageBytes;

  String _normalizeComboUnit(String? rawUnit) {
    final normalized = (rawUnit ?? '').trim().toUpperCase();
    if (normalized == 'LIBRA' || normalized == 'LB' || normalized == 'PESO') {
      return 'LIBRA';
    }
    if (normalized == 'UNIDAD' || normalized == 'UNIT' || normalized == 'U') {
      return 'UNIDAD';
    }
    return 'UNIDAD';
  }

  @override
  void initState() {
    super.initState();

    for (final option in widget.productOptions) {
      final id = option['value']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      _productNameById[id] = option['label']?.toString() ?? id;
    }

    _nameCtrl = TextEditingController(
      text:
          (widget.initialData['nombre'] ??
                  widget.initialData['NombreCombo'] ??
                  '')
              .toString(),
    );
    _descriptionCtrl = TextEditingController(
      text: (widget.initialData['descripcion'] ?? '').toString(),
    );
    _priceCtrl = TextEditingController(
      text:
          (widget.initialData['precioCombo'] ??
                  widget.initialData['precio'] ??
                  0)
              .toString(),
    );
    _imageUrlCtrl = TextEditingController(
      text: (widget.initialData['fotoUrl'] ?? '').toString(),
    );

    _isActive = _toFlag(widget.initialData['activo'] ?? 1);

    final branches = _toStringList(widget.initialData['sucursales_asignadas']);
    _selectedBranchIds.addAll(
      branches.where(
        (id) => widget.branchOptions.any((b) => b['value']?.toString() == id),
      ),
    );

    final initialItems = _extractInitialItems(widget.initialData);
    for (final item in initialItems) {
      final productId = item['productoId']?.toString().trim() ?? '';
      if (productId.isEmpty) continue;
      if (_items.any((i) => i.productId == productId)) continue;

      final qtyRaw = item['cantidad'];
      final quantity = qtyRaw is num
          ? qtyRaw.toString()
          : (double.tryParse(qtyRaw?.toString() ?? '')?.toString() ?? '1');
      final unit = _normalizeComboUnit(
        (item['tipounidad'] ?? item['tipoUnidad'] ?? 'UNIDAD').toString(),
      );
      _items.add(
        _ComboItemDraft(
          productId: productId,
          quantityCtrl: TextEditingController(text: quantity),
          unit: unit,
          idComboItem: item['idComboItem']?.toString(),
          variantId: item['variantId']?.toString(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final item in _items) {
      item.quantityCtrl.dispose();
    }
    super.dispose();
  }

  bool _toFlag(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue > 0;
    final text = rawValue?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si';
  }

  List<String> _toStringList(dynamic rawValue) {
    final values = <String>[];

    void addValue(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !values.contains(text)) {
        values.add(text);
      }
    }

    if (rawValue == null) return values;

    if (rawValue is Iterable) {
      for (final item in rawValue) {
        addValue(item);
      }
      return values;
    }

    final text = rawValue.toString().trim();
    if (text.startsWith('[') && text.endsWith(']')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Iterable) {
          for (final item in decoded) {
            addValue(item);
          }
          return values;
        }
      } catch (_) {}
    }

    addValue(rawValue);
    return values;
  }

  List<Map<String, dynamic>> _extractInitialItems(Map<String, dynamic> data) {
    final result = <Map<String, dynamic>>[];

    void addFromIterable(dynamic raw) {
      if (raw is! Iterable) return;
      for (final item in raw) {
        if (item is Map) {
          result.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }

    addFromIterable(data['combo_items_editor']);
    if (result.isNotEmpty) return result;

    addFromIterable(data['items']);
    if (result.isNotEmpty) return result;

    final productIds = _toStringList(data['productos_combo']);
    for (final productId in productIds) {
      result.add({
        'productoId': productId,
        'cantidad': 1,
        'tipounidad': 'UNIDAD',
      });
    }

    return result;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingImageBytes = bytes;
      _imageUrlCtrl.clear();
    });
  }

  bool _isPreviewableUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<String?> _uploadPendingImageIfNeeded(
    Map<String, dynamic> result,
  ) async {
    if (_pendingImageBytes == null) return _imageUrlCtrl.text.trim();

    if (widget.onUploadImage == null) {
      return null;
    }

    setState(() => _isUploading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final empresaId =
          (result['empresaId'] ?? widget.initialData['empresaId'] ?? '')
              .toString();
      final comboId = (result['id'] ?? widget.initialData['id'] ?? '')
          .toString();
      final storagePath =
          'combos/${empresaId.isEmpty ? 'global' : empresaId}/${comboId.isEmpty ? ts : comboId}/$ts.jpg';
      return await widget.onUploadImage!(_pendingImageBytes!, storagePath);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _addSelectedProduct() {
    final productId = _productToAdd?.trim() ?? '';
    if (productId.isEmpty) return;
    if (_items.any((item) => item.productId == productId)) return;

    setState(() {
      _items.add(
        _ComboItemDraft(
          productId: productId,
          quantityCtrl: TextEditingController(text: '1'),
          unit: 'UNIDAD',
        ),
      );
      _productToAdd = null;
    });
  }

  void _removeProduct(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index < 0) return;
    setState(() {
      final item = _items.removeAt(index);
      item.quantityCtrl.dispose();
    });
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

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar al menos un producto al combo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    for (final item in _items) {
      final qty = double.tryParse(item.quantityCtrl.text.trim());
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cantidad invalida para ${_productNameById[item.productId] ?? item.productId}.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    final result = Map<String, dynamic>.from(widget.initialData)
      ..['nombre'] = _nameCtrl.text.trim()
      ..['descripcion'] = _descriptionCtrl.text.trim()
      ..['precioCombo'] = price
      ..['activo'] = _isActive ? 1 : 0
      ..['sucursales_asignadas'] = _selectedBranchIds.toList()
      ..['productos_combo'] = _items.map((e) => e.productId).toList()
      ..['combo_items_editor'] = _items
          .map(
            (item) => {
              'productoId': item.productId,
              'cantidad': double.tryParse(item.quantityCtrl.text.trim()) ?? 1,
              'tipounidad': _normalizeComboUnit(item.unit),
              if (item.idComboItem != null &&
                  item.idComboItem!.trim().isNotEmpty)
                'idComboItem': item.idComboItem,
              if (item.variantId != null && item.variantId!.trim().isNotEmpty)
                'variantId': item.variantId,
            },
          )
          .toList();

    try {
      final uploadedUrl = await _uploadPendingImageIfNeeded(result);
      if (_pendingImageBytes != null && uploadedUrl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La subida de imagen no esta disponible.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      result['fotoUrl'] = uploadedUrl ?? _imageUrlCtrl.text.trim();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final safeProductToAdd =
        widget.productOptions.any(
          (option) => option['value']?.toString() == _productToAdd,
        )
        ? _productToAdd
        : null;

    final canAddSelectedProduct =
        safeProductToAdd != null &&
        safeProductToAdd.isNotEmpty &&
        !_items.any((item) => item.productId == safeProductToAdd);

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoCols = constraints.maxWidth >= 760;
                          if (!twoCols) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Nombre del combo'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: _decoration(
                                    'Ej: Almuerzo ejecutivo',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa el nombre del combo';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _label('Precio'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _decoration('0.00'),
                                  validator: (v) {
                                    final parsed = double.tryParse(
                                      (v ?? '').trim(),
                                    );
                                    if (parsed == null || parsed < 0) {
                                      return 'Ingresa un precio valido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Nombre del combo'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _nameCtrl,
                                      decoration: _decoration(
                                        'Ej: Almuerzo ejecutivo',
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Ingresa el nombre del combo';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Precio'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _priceCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: _decoration('0.00'),
                                      validator: (v) {
                                        final parsed = double.tryParse(
                                          (v ?? '').trim(),
                                        );
                                        if (parsed == null || parsed < 0) {
                                          return 'Ingresa un precio valido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _label('Descripcion'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: _decoration('Describe el combo'),
                      ),
                      const SizedBox(height: 12),
                      _label('Sucursales asignadas'),
                      const SizedBox(height: 6),
                      if (widget.branchOptions.isEmpty)
                        Text(
                          'No hay sucursales disponibles para la empresa seleccionada.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.branchOptions.map((option) {
                            final value = option['value']?.toString() ?? '';
                            final label = option['label']?.toString() ?? value;
                            final selected = _selectedBranchIds.contains(value);
                            return FilterChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (isSelected) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedBranchIds.add(value);
                                  } else {
                                    _selectedBranchIds.remove(value);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      _label('Imagen'),
                      const SizedBox(height: 6),
                      if (_pendingImageBytes != null)
                        Container(
                          height: 110,
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _pendingImageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else if (_isPreviewableUrl(_imageUrlCtrl.text))
                        Container(
                          height: 110,
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrlCtrl.text,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_rounded),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _imageUrlCtrl,
                              decoration: _decoration(
                                'URL de imagen (opcional)',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _pickImage,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_search_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isUploading ? 'Subiendo' : 'Seleccionar',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _label('Productos del combo'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: safeProductToAdd,
                              decoration: _decoration('Selecciona un producto'),
                              items: widget.productOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option['value']?.toString() ?? '',
                                      child: Text(
                                        option['label']?.toString() ?? '',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _productToAdd = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: canAddSelectedProduct
                                ? _addSelectedProduct
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Agregar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        Text(
                          'Aun no has agregado productos.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        )
                      else
                        Column(
                          children: _items.map((item) {
                            final name =
                                _productNameById[item.productId] ??
                                item.productId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.quantityCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: _decoration('Cantidad'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _normalizeComboUnit(item.unit),
                                      decoration: _decoration('Unidad'),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'UNIDAD',
                                          child: Text('UNIDAD'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'LIBRA',
                                          child: Text('LIBRA'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          item.unit = _normalizeComboUnit(v);
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () =>
                                        _removeProduct(item.productId),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 4),
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
                              ? 'Combo visible en la app'
                              : 'Combo inactivo',
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
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
                      onPressed: _isUploading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(widget.isEdit ? 'Guardar cambios' : 'Crear'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboItemDraft {
  final String productId;
  final TextEditingController quantityCtrl;
  String unit;
  final String? idComboItem;
  final String? variantId;

  _ComboItemDraft({
    required this.productId,
    required this.quantityCtrl,
    required this.unit,
    this.idComboItem,
    this.variantId,
  });
}
