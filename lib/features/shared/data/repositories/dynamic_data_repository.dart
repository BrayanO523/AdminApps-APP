import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';

abstract class DynamicDataRepository {
  /// Obtiene los documentos de una colección dada una app ('carwaspro' | 'eficent').
  /// Utiliza un cursor [lastDocId] y un [limit] para no bloquear la UI web.
  Future<Either<Failure, List<Map<String, dynamic>>>> getCollectionPaginated(
    String appName,
    String collection, {
    int limit = 20,
    String? lastDocId,
  });
}

class _CacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool get isValid =>
      DateTime.now().difference(timestamp).inMinutes < 5; // 5 minutos de caché
}

class DynamicDataRepositoryImpl implements DynamicDataRepository {
  final Dio _dioClient;

  // Caché en memoria para evitar llamadas redundantes de navegación SPA
  final Map<String, _CacheEntry> _cache = {};

  // El token Bearer YA está inyectado automáticamente en este DioClient desde la capa DI.
  DynamicDataRepositoryImpl(this._dioClient);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCollectionPaginated(
    String appName,
    String collection, {
    int limit = 20,
    String? lastDocId,
  }) async {
    try {
      final queryParams = {
        'limite': limit,
        if (lastDocId != null) 'ultimoDocId': lastDocId,
      };

      // Llave única para la caché por consulta exacta
      final cacheKey =
          '/$appName/$collection?limite=$limit&ultimoDocId=${lastDocId ?? 'null'}';

      // 1. Validar si existe en la caché y aún es válido (TTL)
      if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
        return Right(_cache[cacheKey]!.data);
      }

      // Ejemplo de ruta: /api/carwaspro/clientes?limite=20&ultimoDocId=abc123
      final response = await _dioClient.get(
        '/$appName/$collection',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final listMap = data.map((e) => e as Map<String, dynamic>).toList();

        // 2. Guardar en memoria para futuras peticiones
        _cache[cacheKey] = _CacheEntry(listMap, DateTime.now());

        return Right(listMap);
      } else {
        return Left(ServerFailure('Código inesperado: ${response.statusCode}'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return Left(AuthFailure('No autorizado. Token expirado.'));
      }
      return Left(ServerFailure(e.message ?? 'Error de conexión HTTP'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
