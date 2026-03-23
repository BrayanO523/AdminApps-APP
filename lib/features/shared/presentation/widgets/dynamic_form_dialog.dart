import 'dart:convert';

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
  final Future<String> Function(List<int> bytes, String storagePath)? onUploadImage;

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

  /// Campos detectados como JSON arrays (String → List).
  /// Clave: fieldName, Valor: lista mutable de items.
  final Map<String, List<String>> _jsonArrayFields = {};

  /// Controller temporal para añadir un nuevo item a un JSON array field.
  final Map<String, TextEditingController> _arrayAddControllers = {};

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
      if (value is String && value.trim().startsWith('[') && value.trim().endsWith(']')) {
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

      // Si el valor es una Lista nativa → tampoco editamos con TextField
      if (value is List) continue;

      _controllers[key] = TextEditingController(text: value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _arrayAddControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
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

      // Campos JSON array → reserializar como String JSON para el backend
      for (final entry in _jsonArrayFields.entries) {
        result[entry.key] = jsonEncode(entry.value);
      }

      Navigator.pop(context, result);
    }
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

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
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
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      size: 20,
                      color: const Color(0xFF8B5CF6),
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
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: allFieldKeys.map((key) {
                    final schema = widget.fieldSchemas?[key];

                    // Si hay schema de dropdown
                    if (schema != null && schema.type == DynamicFormFieldType.dropdown) {
                       return _buildSingleDropdownField(key, schema);
                    }

                    // Si hay schema de multiselect dropdown
                    if (schema != null && schema.type == DynamicFormFieldType.multiselectDropdown) {
                       return _buildMultiDropdownField(key, schema);
                    }

                    // Opciones predefinidas en dropdown (radio_select)
                    if (schema != null && schema.type == DynamicFormFieldType.radioSelect) {
                       return _buildRadioSelectField(key, schema);
                    }

                    // Color picker
                    if (schema != null && schema.type == DynamicFormFieldType.colorPicker) {
                       return _buildColorPickerField(key, schema);
                    }

                    // Image upload
                    if (schema != null && schema.type == DynamicFormFieldType.imageUpload) {
                       return _buildImageUploadField(key, schema);
                    }

                    // Verificar si es un campo de array (fallback original)
                    if (_jsonArrayFields.containsKey(key)) {
                      return _buildArrayField(key);
                    }

                    // Si es bool (y quisieramos soportar un switch mas adelante, pero por ahora TextField default)
                    return _buildTextField(key, schema);
                  }).toList(),
                ),
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
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _onSave,
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
                      widget.isEdit ? 'Guardar Cambios' : 'Crear Documento',
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
    final isReadOnly = widget.isEdit && (key == 'id') || (schema?.isReadOnly == true);
    final label = schema?.label ?? key.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
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
              color: isReadOnly
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isReadOnly
                  ? const Color(0xFFF8FAFC)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
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
                  color: Color(0xFF8B5CF6),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Campo de JSON array editable con chips ──
  Widget _buildArrayField(String key) {
    final items = _jsonArrayFields[key]!;
    final addController = _arrayAddControllers[key]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: StatefulBuilder(
        builder: (context, setInnerState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + badge de tipo
              Row(
                children: [
                  Text(
                    key.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: items.isEmpty
                    ? Text(
                        'Lista vacía — agrega elementos abajo',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
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
                            side: const BorderSide(
                              color: Color(0xFFBAE6FD),
                            ),
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
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Nuevo elemento...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
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
                            color: Color(0xFF8B5CF6),
                            width: 1.5,
                          ),
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
                    color: const Color(0xFF8B5CF6),
                    tooltip: 'Agregar elemento',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
  // ── Combo Box Búsqueda de Única Selección ──
  Widget _buildSingleDropdownField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final isReadOnly = widget.isEdit && (key == 'id') || schema.isReadOnly;
    final label = schema.label ?? key.toUpperCase();
    // Resolve options lazily at render time to always get the latest state
    final options = schema.resolveOptions();

    Map<String, dynamic>? selectedItem;
    if (controller.text.isNotEmpty) {
      try {
        selectedItem = options.firstWhere(
            (o) => o['value'].toString() == controller.text);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          DropdownSearch<Map<String, dynamic>>(
            enabled: !isReadOnly,
            items: (filter, loadProps) => options,
            compareFn: (item1, item2) => item1['value'] == item2['value'],
            itemAsString: (item) => item['label']?.toString() ?? '',
            selectedItem: selectedItem,
            onChanged: (val) {
              if (val != null) {
                controller.text = val['value']?.toString() ?? '';
              } else {
                controller.clear();
              }
            },
            popupProps: PopupProps.menu(
              showSearchBox: options.length > 5,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              itemBuilder: (context, item, isSelected, isHovered) {
                 return ListTile(
                   title: Text(item['label']?.toString() ?? '', style: GoogleFonts.outfit(fontSize: 14)),
                   selected: isSelected,
                 );
              }
            ),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                filled: true,
                fillColor: isReadOnly ? const Color(0xFFF8FAFC) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final label = schema.label ?? key.toUpperCase();
    final options = schema.resolveOptions();

    List<Map<String, dynamic>> selectedItems = [];
    for (String id in items) {
      try {
        selectedItems.add(options.firstWhere((o) => o['value'].toString() == id));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'MÚLTIPLE',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0369A1)),
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
            onChanged: (vals) {
              setState(() {
                _jsonArrayFields[key] = vals.map((e) => e['value'].toString()).toList();
              });
            },
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: options.length > 5,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                filled: true,
                fillColor: isReadOnly ? const Color(0xFFF8FAFC) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Radio Select (dropdown estático de opciones predefinidas texto/valor) ──
  Widget _buildRadioSelectField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final label = schema.label ?? key.toUpperCase();
    final options = schema.options ?? [];
    String? currentVal = controller.text.isNotEmpty ? controller.text : null;
    // Normalizar: si el valor guardado no está en el listado de values, resetear
    if (currentVal != null && !options.any((o) => o['value'].toString() == currentVal)) {
      currentVal = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentVal,
            items: options.map((o) {
              return DropdownMenuItem<String>(
                value: o['value'].toString(),
                child: Text(o['label']?.toString() ?? o['value'].toString(), style: GoogleFonts.outfit(fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => controller.text = val ?? '');
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Color Picker (swatch + campo de texto hex) ──
  Widget _buildColorPickerField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final label = schema.label ?? key.toUpperCase();

    // Colores predefinidos frecuentes
    final predefined = [
      '0xFFE74C3C', '0xFFE67E22', '0xFFF1C40F', '0xFF2ECC71', '0xFF1ABC9C',
      '0xFF3498DB', '0xFF9B59B6', '0xFF34495E', '0xFF95A5A6', '0xFF2C3E50',
      '0xFFFF6B6B', '0xFFA8E6CF', '0xFFFFD93D', '0xFF6C5CE7', '0xFFFD79A8',
    ];

    Color _parseHex(String hex) {
      try {
        final clean = hex.replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '').padLeft(6, '0');
        if (clean.length == 8) {
          return Color(int.parse(clean, radix: 16));
        }
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return Colors.grey;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StatefulBuilder(
        builder: (ctx, setInner) {
          final current = controller.text.isNotEmpty ? controller.text : '0xFFCCCCCC';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _parseHex(hex),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Campo de texto hex manual
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _parseHex(current), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '0xFFRRGGBB',
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
                      ),
                      onChanged: (_) => setInner(() {}),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Image Upload (URL + nota de subida) ──
  Widget _buildImageUploadField(String key, DynamicFormFieldSchema schema) {
    final controller = _controllers[key]!;
    final label = schema.label ?? key.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StatefulBuilder(
        builder: (ctx, setInner) {
          final hasUrl = controller.text.trim().isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              const SizedBox(height: 6),
              // Preview si ya hay URL
              if (hasUrl) ...
                [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      controller.text.trim(),
                      height: 120, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              // Row con el input URL y botón de subir
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Selecciona una imagen con el botón →',
                        suffixIcon: hasUrl
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                tooltip: 'Quitar imagen',
                                onPressed: () { controller.clear(); setInner(() {}); },
                              )
                            : null,
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: const Icon(Icons.image_rounded, size: 18, color: Color(0xFF8B5CF6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
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

                            setInner(() => _isUploading = true);
                            try {
                              final bytes = await image.readAsBytes();

                              // Resolver ruta dinámica desde schema.storagePath
                              final ts = DateTime.now().millisecondsSinceEpoch;
                              final empresaId = widget.initialData['empresaId']?.toString() ?? 'global';
                              final docId = widget.initialData['id']?.toString() ?? '';
                              final rawPath = schema.storagePath ?? 'uploads/{timestamp}.jpg';
                              final resolvedPath = rawPath
                                  .replaceAll('{timestamp}', ts.toString())
                                  .replaceAll('{empresaId}', empresaId.isNotEmpty ? empresaId : 'global')
                                  .replaceAll('{id}', docId.isNotEmpty ? docId : ts.toString());

                              // Delegar la subida al callback provisto por el llamador
                              final downloadUrl = await widget.onUploadImage!(bytes, resolvedPath);

                              controller.text = downloadUrl;
                              setInner(() {});
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al subir imagen: $e')),
                              );
                            } finally {
                              setInner(() => _isUploading = false);
                            }
                          },
                    icon: _isUploading 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_isUploading ? 'Subiendo' : 'Subir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
