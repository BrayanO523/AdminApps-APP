
enum DynamicFormFieldType {
  /// Campo de texto libre (default).
  text,
  /// Campo numérico.
  number,
  /// Switch o checkbox booleano.
  boolean,
  /// Dropdown de una sola selección con lista de opciones.
  dropdown,
  /// Dropdown de múltiple selección con lista de opciones.
  multiselectDropdown,
  /// Campo de texto + botón para subir imagen a Firebase Storage.
  imageUpload,
  /// Dropdown de opciones predefinidas (pares valor/etiqueta).
  radioSelect,
  /// Color picker (retorna el color como string hex #RRGGBB).
  colorPicker,
}

/// Metadatos (Esquema) para renderizar un campo específico en `DynamicFormDialog`
class DynamicFormFieldSchema {
  final DynamicFormFieldType type;

  /// Lista de opciones para dropdowns. Formato esperado: `{ 'value': 'ID', 'label': 'Nombre' }`
  final List<Map<String, dynamic>>? options;

  /// Título a mostrar sobre el campo. Si es nulo, usará la Key original.
  final String? label;

  /// Texto de ayuda interno en el input.
  final String? hintText;

  /// Si es true, el campo será de sólo lectura.
  final bool isReadOnly;

  const DynamicFormFieldSchema({
    required this.type,
    this.options,
    this.label,
    this.hintText,
    this.isReadOnly = false,
  });
}
