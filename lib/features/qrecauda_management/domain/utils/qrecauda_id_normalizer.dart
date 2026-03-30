class QRecaudaIdNormalizer {
  const QRecaudaIdNormalizer._();

  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String municipalidadId(String nombre) => 'MUN-${normalize(nombre)}';

  static String mercadoId(String municipalidadId, String nombre) =>
      'MER-${normalize(municipalidadId)}-${normalize(nombre)}';

  static String localId(String mercadoId, String nombre) =>
      'LOC-$mercadoId-${normalize(nombre)}';

  static String tipoNegocioId(String nombre) => 'TN-${normalize(nombre)}';
}
