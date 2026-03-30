enum DynamicFormFieldType {
  /// Free text field.
  text,

  /// Numeric field.
  number,

  /// Date field.
  date,

  /// Boolean switch field.
  boolean,

  /// Single-select dropdown.
  dropdown,

  /// Multi-select dropdown.
  multiselectDropdown,

  /// Image upload field.
  imageUpload,

  /// Predefined options selector.
  radioSelect,

  /// Color picker field.
  colorPicker,
  /// Editor de mapa clave -> número, útil para precios por tipo.
  keyValueNumberMap,
}

/// Schema metadata used by `DynamicFormDialog` to render a field.
class DynamicFormFieldSchema {
  final DynamicFormFieldType type;

  /// Static options for dropdown-like fields.
  /// Format: `{ 'value': 'ID', 'label': 'Display Name' }`
  final List<Map<String, dynamic>>? options;

  /// Lazy options resolver. Takes priority over [options] when provided.
  final List<Map<String, dynamic>> Function()? optionsResolver;

  /// Optional visible field label.
  final String? label;

  /// Optional input hint text.
  final String? hintText;

  /// If true, field is read-only.
  final bool isReadOnly;

  /// If true, field is required.
  final bool isRequired;

  /// Storage path template for [DynamicFormFieldType.imageUpload].
  /// Supported variables:
  /// - `{id}`
  /// - `{empresaId}`
  /// - `{timestamp}`
  final String? storagePath;
  final bool allowCustomEntries;

  const DynamicFormFieldSchema({
    required this.type,
    this.options,
    this.optionsResolver,
    this.label,
    this.hintText,
    this.isReadOnly = false,
    this.isRequired = false,
    this.storagePath,
    this.allowCustomEntries = false,
  });

  /// Resolves dynamic options when available, otherwise returns static options.
  List<Map<String, dynamic>> resolveOptions() {
    if (optionsResolver != null) {
      return optionsResolver!();
    }
    return options ?? [];
  }
}
