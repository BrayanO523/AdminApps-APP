import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpenseCategoryFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;

  const ExpenseCategoryFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
  });

  @override
  State<ExpenseCategoryFormDialog> createState() =>
      _ExpenseCategoryFormDialogState();
}

class _ExpenseCategoryFormDialogState extends State<ExpenseCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _colorCtrl;
  late String _selectedIcon;
  late bool _isActive;

  static const _iconOptions = [
    {'value': 'receipt_long', 'label': 'Recibo'},
    {'value': 'payments', 'label': 'Pago'},
    {'value': 'shopping_bag', 'label': 'Compra'},
    {'value': 'local_shipping', 'label': 'Logistica'},
    {'value': 'build', 'label': 'Mantenimiento'},
    {'value': 'inventory_2', 'label': 'Inventario'},
  ];

  static const _colorPresets = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#06B6D4',
    '#3B82F6',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: (widget.initialData['name'] ?? '').toString(),
    );
    _colorCtrl = TextEditingController(
      text: _normalizeColor(
        (widget.initialData['color'] ?? '#EF4444').toString(),
      ),
    );
    _selectedIcon = (widget.initialData['icon'] ?? 'receipt_long').toString();
    _isActive = _toFlag(widget.initialData['isActive'] ?? 1);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  String _normalizeColor(String input) {
    final value = input.trim().toUpperCase();
    if (RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) return value;
    return '#EF4444';
  }

  bool _toFlag(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue > 0;
    final text = rawValue?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si';
  }

  Color _parseColor(String value) {
    final clean = value.replaceAll('#', '').trim();
    if (clean.length != 6) return const Color(0xFFEF4444);
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) return const Color(0xFFEF4444);
    return Color(0xFF000000 | parsed);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final result = Map<String, dynamic>.from(widget.initialData)
      ..['name'] = _nameCtrl.text.trim()
      ..['color'] = _normalizeColor(_colorCtrl.text)
      ..['icon'] = _selectedIcon
      ..['isActive'] = _isActive ? 1 : 0;

    if (!mounted) return;
    Navigator.pop(context, result);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
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
                    Text(
                      'Nombre',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _decoration('Ej: Transporte'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa el nombre del tipo de gasto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Icono',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedIcon,
                      decoration: _decoration('Selecciona un icono'),
                      items: _iconOptions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e['value'],
                              child: Text(e['label']!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedIcon = v ?? 'receipt_long';
                      }),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Color',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _parseColor(_colorCtrl.text),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _colorCtrl,
                            decoration: _decoration('#RRGGBB'),
                            validator: (v) {
                              final value = (v ?? '').trim().toUpperCase();
                              if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
                                return 'Usa formato #RRGGBB';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _colorPresets.map((c) {
                        final selected = _normalizeColor(_colorCtrl.text) == c;
                        return GestureDetector(
                          onTap: () => setState(() => _colorCtrl.text = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFCBD5E1),
                                width: selected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      value: _isActive,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activo',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Visible para registrar gastos'
                            : 'Inactivo',
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
