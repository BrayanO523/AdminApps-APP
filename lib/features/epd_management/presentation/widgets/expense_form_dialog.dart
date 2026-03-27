import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpenseFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final bool isEdit;
  final String title;
  final List<Map<String, dynamic>> branchOptions;
  final List<Map<String, dynamic>> categoryOptions;
  final List<Map<String, dynamic>> userOptions;

  const ExpenseFormDialog({
    super.key,
    required this.initialData,
    required this.isEdit,
    required this.title,
    required this.branchOptions,
    required this.categoryOptions,
    required this.userOptions,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descriptionCtrl;

  String? _branchId;
  String? _categoryId;
  String? _registeredByUserId;
  late DateTime _selectedDate;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: (widget.initialData['amount'] ?? 0).toString(),
    );
    _descriptionCtrl = TextEditingController(
      text: (widget.initialData['description'] ?? '').toString(),
    );

    _branchId = _pickExisting(
      (widget.initialData['branchId'] ?? '').toString(),
      widget.branchOptions,
    );
    _categoryId = _pickExisting(
      (widget.initialData['categoryId'] ?? '').toString(),
      widget.categoryOptions,
    );
    _registeredByUserId = _pickExisting(
      (widget.initialData['registeredByUserId'] ?? '').toString(),
      widget.userOptions,
    );

    _selectedDate = _parseDate(widget.initialData['date']?.toString());
    _isActive = _toFlag(widget.initialData['estado'] ?? 1);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String? _pickExisting(String value, List<Map<String, dynamic>> options) {
    if (value.trim().isEmpty) return null;
    final exists = options.any((o) => o['value']?.toString() == value);
    return exists ? value : null;
  }

  DateTime _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    final parsed = DateTime.tryParse(raw.trim());
    return parsed ?? DateTime.now();
  }

  bool _toFlag(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue > 0;
    final text = rawValue?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final result = Map<String, dynamic>.from(widget.initialData)
      ..['branchId'] = _branchId ?? ''
      ..['categoryId'] = _categoryId ?? ''
      ..['registeredByUserId'] = _registeredByUserId ?? ''
      ..['description'] = _descriptionCtrl.text.trim()
      ..['amount'] = amount
      ..['date'] = _selectedDate.toIso8601String()
      ..['estado'] = _isActive ? 1 : 0;

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
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
                      'Sucursal',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _branchId,
                      decoration: _decoration('Selecciona sucursal'),
                      items: _toItems(widget.branchOptions),
                      onChanged: (v) => setState(() => _branchId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona una sucursal'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tipo de gasto',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: _decoration('Selecciona categoria'),
                      items: _toItems(widget.categoryOptions),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona una categoria'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Registrado por',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _registeredByUserId,
                      decoration: _decoration('Selecciona usuario'),
                      items: _toItems(widget.userOptions),
                      onChanged: (v) => setState(() => _registeredByUserId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona un usuario'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Monto',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decoration('0.00'),
                      validator: (v) {
                        final parsed = double.tryParse((v ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Ingresa un monto valido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fecha',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _decoration('Selecciona fecha'),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF475569),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(_formatDate(_selectedDate)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Descripcion',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionCtrl,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _decoration('Detalle del gasto'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa una descripcion';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _isActive,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activo',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Gasto visible y vigente'
                            : 'Gasto inactivo',
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
