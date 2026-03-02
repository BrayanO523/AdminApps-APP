/// Interfaz que deben implementar los estados de dashboard
/// para que DynamicDataTable pueda resolver IDs a nombres.
abstract class ResolvableState {
  /// Resuelve un ID a un nombre legible según el campo.
  String resolveId(String fieldName, String rawValue);

  /// Verifica si un campo es un ID que se puede resolver.
  bool isResolvableField(String fieldName);
}
