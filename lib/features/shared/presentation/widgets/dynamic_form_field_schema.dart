
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
  /// Editor de mapa clave -> número, útil para precios por tipo.
  keyValueNumberMap,
}

/// Metadatos (Esquema) para renderizar un campo específico en `DynamicFormDialog`
class DynamicFormFieldSchema {
  final DynamicFormFieldType type;

  /// Lista de opciones para dropdowns. Formato esperado: `{ 'value': 'ID', 'label': 'Nombre' }`
  /// Puede ser null si se provee [optionsResolver].
  final List<Map<String, dynamic>>? options;

  /// Callback que retorna las opciones en tiempo de render (lazy).
  /// Tiene prioridad sobre [options]. Permite que el dropdown siempre
  /// obtenga el estado más actualizado sin depender del momento de
  /// construcción del diálogo.
  final List<Map<String, dynamic>> Function()? optionsResolver;

  /// Título a mostrar sobre el campo. Si es nulo, usará la Key original.
  final String? label;

  /// Texto de ayuda interno en el input.
  final String? hintText;

  /// Si es true, el campo será de sólo lectura.
  final bool isReadOnly;

  /// Ruta de destino en Firebase Storage para campos de tipo [imageUpload].
  /// Soporta las siguientes variables interpolables con los datos del formulario:
  /// - `{id}`        → doc.id (disponible en edición, vacío en creación)
  /// - `{empresaId}` → valor del campo empresaId en initialData
  /// - `{timestamp}` → DateTime.now().millisecondsSinceEpoch
  ///
  /// Si se omite, se usa el path por defecto: `uploads/{timestamp}.jpg`
  ///
  /// Ejemplos:
  ///   `'companies/{empresaId}/logo.jpg'`  (edición de empresa)
  ///   `'products/{empresaId}/{timestamp}.jpg'` (producto nuevo)
  final String? storagePath;
  final bool allowCustomEntries;

  const DynamicFormFieldSchema({
    required this.type,
    this.options,
    this.optionsResolver,
    this.label,
    this.hintText,
    this.isReadOnly = false,
    this.storagePath,
    this.allowCustomEntries = false,
  });

  /// Retorna las opciones resolviendo el provider si está disponible,
  /// de lo contrario usa la lista estática.
  List<Map<String, dynamic>> resolveOptions() =>
      optionsResolver != null ? optionsResolver!() : (options ?? []);
}
