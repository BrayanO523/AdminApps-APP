import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DynamicFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;

  const DynamicFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
  });

  @override
  State<DynamicFormDialog> createState() => _DynamicFormDialogState();
}

class _DynamicFormDialogState extends State<DynamicFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _formData;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    // Clonamos para no mutar el original antes de guardar
    _formData = Map<String, dynamic>.from(widget.initialData);
    _controllers = {};

    for (final entry in _formData.entries) {
      final key = entry.key;
      final value = entry.value;

      // No editamos objetos anidados complejos por ahora
      if (value is Map || value is List) continue;

      _controllers[key] = TextEditingController(text: value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      // Reconstruir el map final
      final result = Map<String, dynamic>.from(_formData);

      for (final entry in _controllers.entries) {
        final key = entry.key;
        final textValue = entry.value.text;

        // Tratar de inferir el tipo original
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

      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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

            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: _controllers.entries.map((entry) {
                    final key = entry.key;
                    final controller = entry.value;

                    // Si es edición y el campo es un ID principal y se parece a UUID o ref propia
                    final isReadOnly = widget.isEdit && (key == 'id');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key.toUpperCase(),
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
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
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
                  }).toList(),
                ),
              ),
            ),

            // Footer / Actions
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
}
