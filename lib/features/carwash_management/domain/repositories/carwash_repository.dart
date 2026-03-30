import '../../data/datasources/carwash_remote_datasource.dart';

abstract class CarwashRepository {
  Future<EitherFailurePaginated> getCollection(
    String collectionPath, {
    int limit = 20,
    String? ultimoDocId,
    String? searchField,
    String? searchValue,
    String? searchOperator,
    String? empresaId,
  });

  Future<EitherFailureDocument> getDocumentById(
    String collectionPath,
    String docId,
  );

  Future<EitherFailureMutation> createDocument(
    String collectionPath,
    Map<String, dynamic> data,
  );

  Future<EitherFailureMutation> updateDocument(
    String collectionPath,
    String id,
    Map<String, dynamic> data,
  );

  Future<EitherFailureVoid> deleteDocument(String collectionPath, String id);
}
