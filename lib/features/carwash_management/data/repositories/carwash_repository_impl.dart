import '../../domain/repositories/carwash_repository.dart';
import '../datasources/carwash_remote_datasource.dart';

class CarwashRepositoryImpl implements CarwashRepository {
  final CarwashRemoteDataSource _remoteDataSource;

  CarwashRepositoryImpl(this._remoteDataSource);

  @override
  Future<EitherFailurePaginated> getCollection(
    String collectionPath, {
    int limit = 20,
    String? ultimoDocId,
    String? searchField,
    String? searchValue,
    String? searchOperator,
    String? empresaId,
  }) {
    return _remoteDataSource.getCollection(
      collectionPath,
      limit: limit,
      ultimoDocId: ultimoDocId,
      searchField: searchField,
      searchValue: searchValue,
      searchOperator: searchOperator,
      empresaId: empresaId,
    );
  }

  @override
  Future<EitherFailureDocument> getDocumentById(
    String collectionPath,
    String docId,
  ) {
    return _remoteDataSource.getDocumentById(collectionPath, docId);
  }

  @override
  Future<EitherFailureMutation> createDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) {
    return _remoteDataSource.createDocument(collectionPath, data);
  }

  @override
  Future<EitherFailureMutation> updateDocument(
    String collectionPath,
    String id,
    Map<String, dynamic> data,
  ) {
    return _remoteDataSource.updateDocument(collectionPath, id, data);
  }

  @override
  Future<EitherFailureVoid> deleteDocument(String collectionPath, String id) {
    return _remoteDataSource.deleteDocument(collectionPath, id);
  }
}
