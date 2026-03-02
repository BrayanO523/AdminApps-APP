import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  // Para obtener el usuario actual de caché o sesión iniciada
  Future<Either<Failure, UserEntity>> getCurrentUser();
}
