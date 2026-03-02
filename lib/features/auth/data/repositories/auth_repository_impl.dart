import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl(this._firebaseAuth);

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          return Right(
            UserEntity(uid: user.uid, email: user.email ?? email, token: token),
          );
        }
      }
      return const Left(AuthFailure('No se pudo obtener el token de usuario.'));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return const Left(AuthFailure('Correo o contraseña incorrectos.'));
      }
      return Left(AuthFailure(e.message ?? 'Error de autenticación.'));
    } catch (e) {
      return const Left(
        ServerFailure('Ocurrió un error inesperado al iniciar sesión.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _firebaseAuth.signOut();
      return const Right(null);
    } catch (e) {
      return const Left(ServerFailure('Error al cerrar sesión.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          return Right(
            UserEntity(uid: user.uid, email: user.email ?? '', token: token),
          );
        }
      }
      return const Left(AuthFailure('Usuario no autenticado.'));
    } catch (e) {
      return const Left(AuthFailure('Error verificando la sesión actual.'));
    }
  }
}
