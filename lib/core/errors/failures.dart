import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Ha ocurrido un error en el servidor.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Credenciales inválidas o expiradas.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No hay conexión a internet.']);
}

class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'No se encontró la información en caché.',
  ]);
}
