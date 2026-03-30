import '../../domain/repositories/carwash_repository.dart';

class CarwashReferenceResolver {
  const CarwashReferenceResolver();

  static const _nameFields = [
    'NombreCategoria',
    'nombre',
    'name',
    'razonSocial',
    'nombreComercial',
    'NombreCompleto',
    'email',
  ];

  String? detectCollection(String fieldNameLower) {
    if (fieldNameLower.contains('uid') ||
        fieldNameLower.contains('creado') ||
        fieldNameLower.contains('modificado') ||
        fieldNameLower.contains('admin') ||
        fieldNameLower.contains('usuario')) {
      return 'usuarios';
    }
    if (fieldNameLower.contains('empresa')) return 'empresas';
    if (fieldNameLower.contains('sucursal')) return 'sucursales';
    if (fieldNameLower.contains('cliente')) return 'clientes';
    if (fieldNameLower.contains('tipolavado') ||
        fieldNameLower.contains('tipo_lavado') ||
        fieldNameLower.contains('servicio')) {
      return 'tiposLavados';
    }
    if (fieldNameLower.contains('categor') ||
        fieldNameLower.contains('category') ||
        fieldNameLower.contains('categories')) {
      return 'categorias';
    }
    return null;
  }

  String? extractName(Map<String, dynamic> doc) {
    for (final field in _nameFields) {
      final value = doc[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  Future<Map<String, Map<String, String>>> resolveMissingReferences({
    required List<Map<String, dynamic>> data,
    required CarwashRepository repository,
    required Map<String, Map<String, String>> cache,
  }) async {
    final idsToResolve = <String, Set<String>>{};

    for (final row in data) {
      for (final entry in row.entries) {
        final lower = entry.key.toLowerCase();
        if (_shouldSkipField(lower)) continue;

        final collection = detectCollection(lower);
        if (collection == null) continue;

        final cached = cache[collection] ?? const {};
        final value = entry.value;
        if (value is String && value.isNotEmpty && value.length > 10) {
          if (!cached.containsKey(value)) {
            idsToResolve.putIfAbsent(collection, () => {}).add(value);
          }
        } else if (value is Iterable) {
          for (final item in value) {
            final id = item?.toString() ?? '';
            if (id.isNotEmpty && id.length > 10 && !cached.containsKey(id)) {
              idsToResolve.putIfAbsent(collection, () => {}).add(id);
            }
          }
        }
      }
    }

    if (idsToResolve.isEmpty) return cache;

    final resolved = {
      for (final entry in cache.entries)
        entry.key: Map<String, String>.from(entry.value),
    };

    for (final entry in idsToResolve.entries) {
      final collection = entry.key;
      final target = resolved.putIfAbsent(collection, () => <String, String>{});
      final ids = entry.value.take(30);
      await Future.wait(
        ids.map((id) async {
          final result = await repository.getDocumentById(collection, id);
          result.fold((_) {}, (doc) {
            if (doc == null) return;
            final name = extractName(doc);
            if (name != null) {
              target[id] = name;
            }
          });
        }),
      );
    }

    return resolved;
  }

  bool _shouldSkipField(String lower) {
    return lower == 'id' ||
        lower == 'activo' ||
        lower == 'rol' ||
        lower == 'nombre' ||
        lower == 'name' ||
        lower == 'nombrecompleto' ||
        lower.contains('fecha') ||
        lower.contains('date') ||
        lower.contains('time') ||
        lower.contains('creado_offline') ||
        lower.contains('token') ||
        lower.contains('telefono') ||
        lower.contains('direccion') ||
        lower.contains('correo') ||
        lower.contains('precio') ||
        lower.contains('cantidad') ||
        lower.contains('total') ||
        lower.contains('monto');
  }
}
