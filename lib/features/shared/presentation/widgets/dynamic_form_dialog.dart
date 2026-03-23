import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';

import 'dynamic_form_field_schema.dart';

class DynamicFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;
  final Map<String, DynamicFormFieldSchema>? fieldSchemas;

  /// Campos que deben omitirse visualmente pero cuyo valor se envía al guardado.
  /// Usados para campos de contexto automático (empresaId, sucursalId, etc.)
  /// y campos de sistema (activo, last_modified, SYNC_STATUS, etc.).
  final List<String> hiddenFields;

  /// Callback para subir una imagen. Recibe los bytes y la ruta de Storage.
  /// Debe devolver la URL de descarga. Si es null, el botón de subida no aparece.
  final Future<String> Function(List<int> bytes, String storagePath)?
  onUploadImage;

  const DynamicFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
    this.fieldSchemas,
    this.hiddenFields = const [],
    this.onUploadImage,
  });

  @override
  State<DynamicFormDialog> createState() => _DynamicFormDialogState();
}

class _DynamicFormDialogState extends State<DynamicFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _formData;
  late Map<String, TextEditingController> _controllers;
  static const Set<String> _nativeArrayFields = {'allowed_categories'};
  static const String _saleModeFieldKey = 'ModoVventa';
  static const Set<String> _unitPriceFieldKeys = {
    'preciounidad',
    'precioUnidad',
    'precio_unidad',
  };
  static const Set<String> _lbPriceFieldKeys = {
    'precioLibra',
    'precio_lb',
    'precio_libra',
  };
  static const Set<String> _promoToggleFieldKeys = {'is_promo'};
  static const Set<String> _promoPriceFieldKeys = {
    'promo_price',
    'promo_price_lb',
  };
  static const Color _accentColor = Color(0xFF4F46E5);
  static const Color _labelColor = Color(0xFF334155);
  static const Color _inputTextColor = Color(0xFF0F172A);
  static const Color _inputBorderColor = Color(0xFFCBD5E1);

  /// Campos detectados como JSON arrays (String → List).
  /// Clave: fieldName, Valor: lista mutable de items.
  final Map<String, List<String>> _jsonArrayFields = {};

  /// Controller temporal para añadir un nuevo item a un JSON array field.
  final Map<String, TextEditingController> _arrayAddControllers = {};

  /// Imágenes seleccionadas localmente que se subirán al presionar Guardar.
  final Map<String, Uint8List> _pendingImageBytes = {};
  final Set<String> _autoSaleModeListenerKeys = {};

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData);
    _controllers = {};

    for (final entry in _formData.entries) {
      final key = entry.key;
      final value = entry.value;

      // Si el valor es una Lista directa → no editar (objetos complejos)
      if (value is Map) continue;

      // Si el valor es un String que se parece a un JSON array → tratar especial
      if (value is String &&
          value.trim().startsWith('[') &&
          value.trim().endsWith(']')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            _jsonArrayFields[key] = decoded.map((e) => e.toString()).toList();
            _arrayAddControllers[key] = TextEditingController();
            continue; // No crear TextEditingController para este campo
          }
        } catch (_) {
          // No es JSON válido, tratar como string normal
        }
      }

      // Si el valor es una Lista nativa → tratar como campo array editable.
      if (value is List) {
        _jsonArrayFields[key] = value.map((e) => e.toString()).toList();
        _arrayAddControllers[key] = TextEditingController();
        continue;
      }

      _controllers[key] = TextEditingController(text: value?.toString() ?? '');
    }

    _configureAutoSaleModeCalculation();
  }

  @override
  void dispose() {
    for (final key in _autoSaleModeListenerKeys) {
      _controllers[key]?.removeListener(_handlePriceFieldChanged);
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _arrayAddControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _configureAutoSaleModeCalculation() {
    if (!_controllers.containsKey(_saleModeFieldKey)) return;

    final unitPriceKey = _findFirstExistingControllerKey(_unitPriceFieldKeys);
    final lbPriceKey = _findFirstExistingControllerKey(_lbPriceFieldKeys);

    if (unitPriceKey == null && lbPriceKey == null) return;

    if (unitPriceKey != null && _autoSaleModeListenerKeys.add(unitPriceKey)) {
      _controllers[unitPriceKey]?.addListener(_handlePriceFieldChanged);
    }

    if (lbPriceKey != null && _autoSaleModeListenerKeys.add(lbPriceKey)) {
      _controllers[lbPriceKey]?.addListener(_handlePriceFieldChanged);
    }

    _updateSaleModeFromPrices(notifyUi: false);
  }

  String? _findFirstExistingControllerKey(Set<String> candidates) {
    for (final key in candidates) {
      if (_controllers.containsKey(key)) return key;
    }
    return null;
  }

  void _handlePriceFieldChanged() {
    _updateSaleModeFromPrices();
  }

  void _updateSaleModeFromPrices({bool notifyUi = true}) {
    final saleModeController = _controllers[_saleModeFieldKey];
    if (saleModeController == null) return;

    final unitPriceText =
        _controllers[_findFirstExistingControllerKey(_unitPriceFieldKeys)]
            ?.text;
    final lbPriceText =
        _controllers[_findFirstExistingControllerKey(_lbPriceFieldKeys)]?.text;

    final hasUnitPrice = _hasPositiveNumber(unitPriceText);
    final hasLbPrice = _hasPositiveNumber(lbPriceText);

    String? nextMode;
    if (hasUnitPrice && hasLbPrice) {
      nextMode = 'AMBOS';
    } else if (hasLbPrice) {
      nextMode = 'LB';
    } else if (hasUnitPrice) {
      nextMode = 'UNIDAD';
    }

    if (nextMode == null || saleModeController.text == nextMode) return;

    saleModeController.text = nextMode;
    if (notifyUi && mounted) {
      setState(() {});
    }
  }

  bool _hasPositiveNumber(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return false;
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return false;
    return parsed > 0;
  }

  bool _isPromotionEnabled() {
    String? rawValue;
    for (final key in _promoToggleFieldKeys) {
      final controller = _controllers[key];
      if (controller != null) {
        rawValue = controller.text.trim();
        break;
      }
    }

    if (rawValue == null || rawValue.isEmpty) return false;
    final normalized = rawValue.toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'si' ||
        normalized == 'sí' ||
        normalized == 'yes';
  }

  List<String> _applyConditionalVisibility(List<String> allFieldKeys) {
    final hasPromoToggle = _promoToggleFieldKeys.any(_controllers.containsKey);
    if (!hasPromoToggle) return allFieldKeys;

    final isPromoEnabled = _isPromotionEnabled();
    if (isPromoEnabled) return allFieldKeys;

    return allFieldKeys
        .where((fieldKey) => !_promoPriceFieldKeys.contains(fieldKey))
        .toList();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final result = Map<String, dynamic>.from(_formData);

    // Campos de texto normales
    for (final entry in _controllers.entries) {
      final key = entry.key;
      final textValue = entry.value.text;
      final originalValue = widget.initialData[key];

      if (originalValue is int) {
        result[key] = int.tryParse(textValue) ?? 0;
      } else if (originalValue is double) {
        result[key] = double.tryParse(textValue) ?? 0.0;
      } else if (originalValue is bool) {
        final lowercase = textValue.toLowerCase().trim();
        result[key] =
            lowercase == 'true' ||
            lowercase == '1' ||
            lowercase == 'sí' ||
            lowercase == 'si';
      } else {
        result[key] = textValue;
      }
    }

    // Campos JSON array: por defecto se serializan a JSON string para compatibilidad.
    // Excepción: algunos campos deben persistirse como Array nativo en Firestore.
    for (final entry in _jsonArrayFields.entries) {
      if (_nativeArrayFields.contains(entry.key)) {
        result[entry.key] = List<String>.from(entry.value);
      } else {
        result[entry.key] = jsonEncode(entry.value);
      }
    }

    // Subir imágenes pendientes al guardar.
    if (_pendingImageBytes.isNotEmpty) {
      if (widget.onUploadImage == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La subida de imágenes no está disponible.'),
          ),
        );
        return;
      }

      setState(() => _isUploading = true);
      try {
        for (final entry in _pendingImageBytes.entries) {
          final key = entry.key;
          final bytes = entry.value;
          final schema = widget.fieldSchemas?[key];

          final ts = DateTime.now().millisecondsSinceEpoch;
          final empresaId =
              (result['empresaId'] ?? widget.initialData['empresaId'] ?? '')
                  .toString();
          final docId = (result['id'] ?? widget.initialData['id'] ?? '')
              .toString();
          final rawPath = schema?.storagePath ?? 'uploads/{timestamp}.jpg';
          final resolvedPath = rawPath
              .replaceAll('{timestamp}', ts.toString())
              .replaceAll(
                '{empresaId}',
                empresaId.isNotEmpty ? empresaId : 'global',
              )
              .replaceAll('{id}', docId.isNotEmpty ? docId : ts.toString());

          final downloadUrl = await widget.onUploadImage!(bytes, resolvedPath);
          result[key] = downloadUrl;
        }
        _pendingImageBytes.clear();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
        return;
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isReadOnly = false,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(
        fontSize: 12,
        color: const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isReadOnly ? const Color(0xFFEFF4FA) : const Color(0xFFF8FAFC),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconColor: const Color(0xFF1E293B),
      suffixIconColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _inputBorderColor, width: 1.1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _inputBorderColor, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accentColor, width: 1.7),
      ),
    );
  }

  TextStyle _fieldLabelStyle() {
    return GoogleFonts.outfit(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _labelColor,
      letterSpacing: 0.1,
    );
  }

  static const Map<String, String> _friendlyFieldLabels = {
    'id': 'ID',
    'empresaId': 'Empresa',
    'adminId': 'Administrador',
    'sucursalId': 'Sucursal',
    'IdSucursal': 'Sucursal',
    'IdSucursalesAsignadas': 'Sucursales Asignadas',
    'selected_categories': 'Categorías Permitidas',
    'allowed_categories': 'Categorías Permitidas',
    'assigned_seller_ids': 'Vendedores Asignados',
    'seller_id': 'Vendedor',
    'Idvendedor': 'Vendedor',
    'IdUsuario': 'Usuario',
    'CodigoUsuario': 'Código de Usuario',
    'Nombre': 'Nombre',
    'NombreCompleto': 'Nombre Completo',
    'nombreComercial': 'Nombre Comercial',
    'razonSocial': 'Razón Social',
    'telefono_contacto': 'Teléfono de Contacto',
    'direccion_referencia': 'Dirección de Referencia',
    'NombreCategoria': 'Categoría',
    'IdCategoria': 'Categoría',
    'NombreProducto': 'Nombre del Producto',
    'IdProducto': 'Producto',
    'NombreCombo': 'Nombre del Combo',
    'IdCombo': 'Combo',
    'IdCliente': 'Cliente',
    'IdProveedor': 'Proveedor',
    'IdInventario': 'Inventario',
    'IdTransaccion': 'Transacción',
    'IdVenta': 'Venta',
    'Color': 'Color',
    'logoUrl': 'Logo',
    'fotoUrl': 'Foto',
    'ModoVventa': 'Modo de Venta',
    'esGlobal': 'Alcance del Proveedor',
    'activo': 'Estado',
    'sync_status': 'Estado de Sincronización',
  };

  String _resolveFieldLabel(String key, {String? explicitLabel}) {
    if (explicitLabel != null && explicitLabel.trim().isNotEmpty) {
      return explicitLabel.trim();
    }

    final direct =
        _friendlyFieldLabels[key] ?? _friendlyFieldLabels[key.toLowerCase()];
    if (direct != null) return direct;

    return _humanizeKey(key);
  }

  String _humanizeKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return key;

    final withSpaces = trimmed
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])([A-Z])'),
          (m) => ' ${m.group(1)}',
        );

    final words = withSpaces
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    const acronyms = {
      'id': 'ID',
      'url': 'URL',
      'uid': 'UID',
      'rtn': 'RTN',
      'pin': 'PIN',
      'api': 'API',
      'lb': 'LB',
    };

    return words
        .map((word) {
          final lower = word.toLowerCase();
          final acronym = acronyms[lower];
          if (acronym != null) return acronym;
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  Widget _buildFieldCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: child,
    );
  }

  Widget _buildFieldWidget(String key, DynamicFormFieldSchema? schema) {
    if (schema != null && schema.type == DynamicFormFieldType.dropdown) {
      return _buildSingleDropdownField(key, schema);
    }

    if (schema != null &&
        schema.type == DynamicFormFieldType.multiselectDropdown) {
      return _buildMultiDropdownField(key, schema);
    }

    if (schema != null && schema.type == DynamicFormFieldType.radioSelect) {
      return _buildRadioSelectField(key, schema);
    }

    if (schema != null && schema.type == DynamicFormFieldType.colorPicker) {
      return _buildColorPickerField(key, schema);
    }

    if (schema != null && schema.type == DynamicFormFieldType.imageUpload) {
      return _buildImageUploadField(key, schema);
    }

    if (_jsonArrayFields.containsKey(key)) {
      return _buildArrayField(key);
    }

    return _buildTextField(key, schema);
  }

  Widget _buildResponsiveFields(List<String> allFieldKeys) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 760 ? 2 : 1;
        const spacing = 14.0;
        const horizontalPadding = 24.0;
        final availableWidth = (width - (horizontalPadding * 2)).clamp(
          0.0,
          double.infinity,
        );
        final itemWidth = columns == 1
            ? availableWidth
            : (availableWidth - spacing * (columns - 1)) / columns;

        if (allFieldKeys.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No hay campos disponibles para editar en este formulario.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(horizontalPadding),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: allFieldKeys.map((key) {
              final schema = widget.fieldSchemas?[key];
              return SizedBox(
                width: itemWidth,
                child: _buildFieldCard(_buildFieldWidget(key, schema)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Orden de campos: primero los de texto simple, luego los arrays.
    // Se excluyen los campos ocultos (contexto + sistema).
    final hiddenSet = {...widget.hiddenFields, 'id'};
    final allFieldKeys = [
      ..._controllers.keys.where((k) => !hiddenSet.contains(k)),
      ..._jsonArrayFields.keys.where((k) => !hiddenSet.contains(k)),
    ];
    final visibleFieldKeys = _applyConditionalVisibility(allFieldKeys);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 1400
        ? 1180.0
        : screenWidth >= 1024
        ? 980.0
        : screenWidth >= 780
        ? 760.0
        : screenWidth * 0.94;

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      size: 20,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.grey.shade400,
                      backgroundColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Content ──
            Expanded(
              child: Form(
                key: _formKey,
                child: _buildResponsiveFields(visibleFieldKeys),
              ),
            ),

            // ── Footer / Actions ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        color: _labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isUploading
                          ? 'Subiendo...'
                          : (widget.isEdit
                                ? 'Guardar Cambios'
                                : 'Crear Documento'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Campo de texto estándar ──
  Widget _buildTextField(String key, DynamicFormFieldSchema? schema) {
    final controller = _controllers[key]!;
    final isReadOnly =
        widget.isEdit && (key == 'id') || (schema?.isReadOnly == true);
    final label = _resolveFieldLabel(key, explicitLabel: schema?.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle()),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          maxLines:
              key.toLowerCase().contains('url') ||
                  key.toLowerCase().contains('descripcion')
              ? 3
              : 1,
          minLines: 1,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: isReadOnly ? const Color(0xFF64748B) : _inputTextColor,
          ),
          decoration: _fieldDecoration(isReadOnly: isReadOnly),
        ),
      ],
    );
  }

  // ── Campo de JSON array editable con chips ──
  Widget _buildArrayField(String key) {
    final items = _jsonArrayFields[key]!;
    final addController = _arrayAddControllers[key]!;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + badge de tipo
            Row(
              children: [
                Text(_resolveFieldLabel(key), style: _fieldLabelStyle()),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LISTA',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chips de items existentes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _inputBorderColor),
              ),
              child: items.isEmpty
                  ? Text(
                      'Lista vacía — agrega elementos abajo',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(items.length, (i) {
                        return Chip(
                          label: Text(
                            items[i],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                          backgroundColor: const Color(0xFFE0F2FE),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          deleteIcon: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.red.shade400,
                          ),
                          onDeleted: () {
                            setInnerState(() {
                              items.removeAt(i);
                            });
                            setState(() {});
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        );
                      }),
                    ),
            ),

            const SizedBox(height: 8),

            // Input para agregar nuevo item
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addController,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: _inputTextColor,
                    ),
                    decoration: _fieldDecoration(
                      hintText: 'Nuevo elemento...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (val) {
                      final trimmed = val.trim();
                      if (trimmed.isNotEmpty) {
                        setInnerState(() {
                          items.add(trimmed);
                        });
                        setState(() {});
                        addController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final trimmed = addController.text.trim();
                    if (trimmed.isNotEmpty) {
                      setInnerState(() {
                        items.add(trimmed);
                      });
                      setState(() {});
                      addController.clear();
                    }
                  },
                  icon: const Icon(Icons.add_circle_rounded),
                  color: _accentColor,
                  tooltip: 'Agregar elemento',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Combo Box Búsqueda de Única Selección ──
  Widget _buildSingleDropdownField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final isReadOnly = widget.isEdit && (key == 'id') || schema.isReadOnly;
    final label = _resolveFieldLabel(key, explicitLabel: schema.label);
    // Resolve options lazily at render time to always get the latest state
    final options = schema.resolveOptions();

    Map<String, dynamic>? selectedItem;
    if (controller.text.isNotEmpty) {
      try {
        selectedItem = options.firstWhere(
          (o) => o['value'].toString() == controller.text,
        );
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle()),
        const SizedBox(height: 6),
        DropdownSearch<Map<String, dynamic>>(
          enabled: !isReadOnly,
          items: (filter, loadProps) => options,
          compareFn: (item1, item2) => item1['value'] == item2['value'],
          itemAsString: (item) => item['label']?.toString() ?? '',
          selectedItem: selectedItem,
          dropdownBuilder: (context, item) {
            final text = item?['label']?.toString() ?? 'Seleccionar...';
            final hasValue = item != null;
            return Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                color: hasValue
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            );
          },
          suffixProps: DropdownSuffixProps(
            dropdownButtonProps: DropdownButtonProps(
              iconClosed: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: Color(0xFF1E293B),
              ),
              iconOpened: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 22,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          onChanged: (val) {
            if (val != null) {
              controller.text = val['value']?.toString() ?? '';
            } else {
              controller.clear();
            }
          },
          popupProps: PopupProps.menu(
            showSearchBox: true,
            showSelectedItems: true,
            menuProps: const MenuProps(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            searchFieldProps: TextFieldProps(
              decoration: _fieldDecoration(
                hintText: 'Buscar...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
            itemBuilder: (context, item, isSelected, isHovered) {
              final background = isSelected
                  ? const Color(0xFFE0E7FF)
                  : (isHovered ? const Color(0xFFF8FAFC) : Colors.white);
              return Container(
                color: background,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isSelected
                        ? const Color(0xFF3730A3)
                        : const Color(0xFF64748B),
                  ),
                  title: Text(
                    item['label']?.toString() ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            },
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: _fieldDecoration(isReadOnly: isReadOnly),
          ),
        ),
      ],
    );
  }

  // ── Combo Box de Selección Múltiple (Multiselect) ──
  Widget _buildMultiDropdownField(String key, DynamicFormFieldSchema schema) {
    if (!_jsonArrayFields.containsKey(key)) {
      // Fallback seguro si por alguna razón no se parseó como JSON array list nativa en initState
      _jsonArrayFields[key] = [];
    }

    final items = _jsonArrayFields[key]!;
    final isReadOnly = widget.isEdit && (key == 'id') || schema.isReadOnly;
    final label = _resolveFieldLabel(key, explicitLabel: schema.label);
    final options = schema.resolveOptions();

    List<Map<String, dynamic>> selectedItems = [];
    for (String id in items) {
      try {
        selectedItems.add(
          options.firstWhere((o) => o['value'].toString() == id),
        );
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: _fieldLabelStyle()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'MÚLTIPLE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>.multiSelection(
          enabled: !isReadOnly,
          items: (filter, loadProps) => options,
          compareFn: (item1, item2) => item1['value'] == item2['value'],
          itemAsString: (item) => item['label']?.toString() ?? '',
          selectedItems: selectedItems,
          dropdownBuilder: (context, vals) {
            if (vals.isEmpty) {
              return Text(
                'Selecciona opciones...',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              );
            }

            final visible = vals.take(2).toList();
            final overflow = vals.length - visible.length;

            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...visible.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      item['label']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E1B4B),
                      ),
                    ),
                  );
                }),
                if (overflow > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      '+$overflow',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3730A3),
                      ),
                    ),
                  ),
              ],
            );
          },
          suffixProps: DropdownSuffixProps(
            dropdownButtonProps: DropdownButtonProps(
              iconClosed: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: Color(0xFF1E293B),
              ),
              iconOpened: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 22,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          onChanged: (vals) {
            setState(() {
              _jsonArrayFields[key] = vals
                  .map((e) => e['value'].toString())
                  .toList();
            });
          },
          popupProps: PopupPropsMultiSelection.menu(
            showSearchBox: true,
            showSelectedItems: true,
            menuProps: const MenuProps(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            searchFieldProps: TextFieldProps(
              decoration: _fieldDecoration(
                hintText: 'Buscar...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
            itemBuilder: (context, item, isSelected, isHovered) {
              final background = isSelected
                  ? const Color(0xFFE0E7FF)
                  : (isHovered ? const Color(0xFFF8FAFC) : Colors.white);
              return Container(
                color: background,
                child: ListTile(
                  dense: true,
                  title: Text(
                    item['label']?.toString() ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            },
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: _fieldDecoration(isReadOnly: isReadOnly),
          ),
        ),
      ],
    );
  }

  // ── Radio Select (dropdown estático de opciones predefinidas texto/valor) ──
  Widget _buildRadioSelectField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final isReadOnly = widget.isEdit && (key == 'id') || schema.isReadOnly;
    final label = _resolveFieldLabel(key, explicitLabel: schema.label);
    final options = schema.options ?? [];
    String? currentVal = controller.text.isNotEmpty ? controller.text : null;
    // Normalizar: si el valor guardado no está en el listado de values, resetear
    if (currentVal != null &&
        !options.any((o) => o['value'].toString() == currentVal)) {
      currentVal = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle()),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: currentVal,
          iconEnabledColor: const Color(0xFF1E293B),
          iconDisabledColor: const Color(0xFF94A3B8),
          dropdownColor: Colors.white,
          items: options.map((o) {
            return DropdownMenuItem<String>(
              value: o['value'].toString(),
              child: Text(
                o['label']?.toString() ?? o['value'].toString(),
                style: GoogleFonts.outfit(fontSize: 14, color: _inputTextColor),
              ),
            );
          }).toList(),
          onChanged: isReadOnly
              ? null
              : (val) {
                  setState(() => controller.text = val ?? '');
                },
          style: GoogleFonts.outfit(fontSize: 14, color: _inputTextColor),
          decoration: _fieldDecoration(isReadOnly: isReadOnly),
        ),
      ],
    );
  }

  // ── Color Picker (swatch + campo de texto hex) ──
  Widget _buildColorPickerField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final label = _resolveFieldLabel(key, explicitLabel: schema.label);

    // Colores predefinidos frecuentes
    final predefined = [
      '0xFFE74C3C',
      '0xFFE67E22',
      '0xFFF1C40F',
      '0xFF2ECC71',
      '0xFF1ABC9C',
      '0xFF3498DB',
      '0xFF9B59B6',
      '0xFF34495E',
      '0xFF95A5A6',
      '0xFF2C3E50',
      '0xFFFF6B6B',
      '0xFFA8E6CF',
      '0xFFFFD93D',
      '0xFF6C5CE7',
      '0xFFFD79A8',
    ];

    Color _parseHex(String hex) {
      try {
        final clean = hex
            .replaceAll('#', '')
            .replaceAll('0x', '')
            .replaceAll('0X', '')
            .padLeft(6, '0');
        if (clean.length == 8) {
          return Color(int.parse(clean, radix: 16));
        }
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return Colors.grey;
      }
    }

    return StatefulBuilder(
      builder: (ctx, setInner) {
        final current = controller.text.isNotEmpty
            ? controller.text
            : '0xFFCCCCCC';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _fieldLabelStyle()),
            const SizedBox(height: 6),
            // Swatches predefinidos
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: predefined.map((hex) {
                final isSelected = current.toUpperCase() == hex.toUpperCase();
                return GestureDetector(
                  onTap: () {
                    controller.text = hex;
                    setInner(() {});
                    setState(() {});
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _parseHex(hex),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? _accentColor : _inputBorderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Campo de texto hex manual
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _parseHex(current),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _inputBorderColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: _inputTextColor,
                    ),
                    decoration: _fieldDecoration(hintText: '0xFFRRGGBB'),
                    onChanged: (_) => setInner(() {}),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool _isPreviewableNetworkImageUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  // ── Image Upload (URL + nota de subida) ──
  Widget _buildImageUploadField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final label = _resolveFieldLabel(key, explicitLabel: schema.label);

    return StatefulBuilder(
      builder: (ctx, setInner) {
        final pendingBytes = _pendingImageBytes[key];
        final hasPendingLocal = pendingBytes != null;
        final currentUrl = controller.text.trim();
        final hasUrl = currentUrl.isNotEmpty;
        final hasPreviewableRemote = _isPreviewableNetworkImageUrl(currentUrl);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _fieldLabelStyle()),
            const SizedBox(height: 6),
            // Preview local pendiente (aún no subida) o URL ya guardada
            if (hasPendingLocal) ...[
              Container(
                height: 96,
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    pendingBytes,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (hasPreviewableRemote) ...[
              Container(
                height: 96,
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    currentUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: _inputTextColor,
                    ),
                    decoration: _fieldDecoration(
                      hintText: hasPendingLocal
                          ? 'Imagen lista para subir al guardar'
                          : 'Selecciona una imagen con el botón',
                      prefixIcon: const Icon(
                        Icons.image_rounded,
                        size: 18,
                        color: _accentColor,
                      ),
                      suffixIcon: (hasUrl || hasPendingLocal)
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                              tooltip: 'Quitar imagen',
                              onPressed: () {
                                controller.clear();
                                _pendingImageBytes.remove(key);
                                setInner(() {});
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setInner(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isUploading || widget.onUploadImage == null
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (image == null) return;

                          try {
                            final bytes = await image.readAsBytes();
                            _pendingImageBytes[key] = bytes;
                            // Limpiar URL previa para reflejar reemplazo.
                            controller.clear();
                            setInner(() {});
                            setState(() {});
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al seleccionar imagen: $e',
                                ),
                              ),
                            );
                          }
                        },
                  icon: _isUploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.image_search_rounded, size: 18),
                  label: Text(_isUploading ? 'Subiendo' : 'Seleccionar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
