import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';

typedef PaginatedResponse = ({List<Map<String, dynamic>> data, int total});
typedef EitherFailurePaginated = Either<Failure, PaginatedResponse>;
typedef EitherFailureDocument = Either<Failure, Map<String, dynamic>?>;
typedef EitherFailureMutation = Either<Failure, Map<String, dynamic>>;
typedef EitherFailureVoid = Either<Failure, void>;

class CarwashRemoteDataSource {
  final DioClient _dioClient;

  CarwashRemoteDataSource(this._dioClient);

  /// Obtiene todos los documentos de [coleccion] desde la API, paginados y filtrados.
  Future<Either<Failure, PaginatedResponse>> getCollection(
    String collectionPath, {
    int limit = 20,
    String? ultimoDocId,
    String? searchField,
    String? searchValue,
    String? searchOperator,
    String? empresaId,
  }) async {
    try {
      final queryParams = {
        'limite': limit,
        if (ultimoDocId != null) 'ultimoDocId': ultimoDocId,
        if (searchField != null && searchField.isNotEmpty) 'campo': searchField,
        if (searchValue != null && searchValue.isNotEmpty) 'valor': searchValue,
        if (searchOperator != null) 'operador': searchOperator,
        if (empresaId != null && empresaId.isNotEmpty) 'empresa_id': empresaId,
      };

      final response = await _dioClient.instance.get(
        '/carwaspro/$collectionPath',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawData = response.data['data'] ?? [];
        final int totalCount = response.data['total'] ?? 0;

        // Evitar CastList iterables usando asignación en memoria explícita
        final listData = rawData.map((e) => e as Map<String, dynamic>).toList();
        final result = (data: listData, total: totalCount);

        return Right(result);
      }

      return const Left(ServerFailure('Respuesta inesperada del servidor.'));
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return const Left(NetworkFailure('No se pudo conectar con el servidor.'));
    }
  }

  /// Obtiene un solo documento por su ID desde la API.
  Future<Either<Failure, Map<String, dynamic>?>> getDocumentById(
    String collectionPath,
    String docId,
  ) async {
    try {
      final response = await _dioClient.instance.get(
        '/carwaspro/$collectionPath/$docId',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return Right(data);
        }
        return const Right(null);
      }
      return const Right(null);
    } on DioException {
      return const Right(null);
    } catch (_) {
      return const Right(null);
    }
  }

  /// Crea un nuevo documento en la colección.
  Future<Either<Failure, Map<String, dynamic>>> createDocument(
    String coleccion,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.instance.post(
        '/carwaspro/$coleccion',
        data: data,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      }
      return const Left(ServerFailure('Respuesta inesperada al crear.'));
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return const Left(NetworkFailure('No se pudo conectar con el servidor.'));
    }
  }

  /// Actualiza un documento existente.
  Future<Either<Failure, Map<String, dynamic>>> updateDocument(
    String coleccion,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.instance.put(
        '/carwaspro/$coleccion/$id',
        data: data,
      );
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      }
      return const Left(ServerFailure('Respuesta inesperada al actualizar.'));
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return const Left(NetworkFailure('No se pudo conectar con el servidor.'));
    }
  }

  /// Elimina por completo un documento.
  Future<Either<Failure, void>> deleteDocument(
    String coleccion,
    String id,
  ) async {
    try {
      final response = await _dioClient.instance.delete(
        '/carwaspro/$coleccion/$id',
      );
      if (response.statusCode == 200) {
        return const Right(null);
      }
      return const Left(ServerFailure('Respuesta inesperada al eliminar.'));
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return const Left(NetworkFailure('No se pudo conectar con el servidor.'));
    }
  }

  Either<Failure, T> _handleDioException<T>(DioException e) {
    if (e.response?.statusCode == 401) {
      return const Left(
        AuthFailure('Sesión expirada. Inicia sesión de nuevo.'),
      );
    }
    if (e.response?.statusCode == 403) {
      return const Left(AuthFailure('No tienes permisos de administrador.'));
    }
    final data = e.response?.data;
    final msg =
        (data is Map ? data['error']?.toString() : null) ??
        'Error de conexión con la API.';
    return Left(ServerFailure(msg));
  }
}
