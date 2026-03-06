import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class DioClient {
  late final Dio dio;

  DioClient({required String baseUrl, Future<String?> Function()? getToken}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (getToken != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            // Inyectar token de Firebase App Check
            try {
              final appCheckToken = await FirebaseAppCheck.instance.getToken(
                true,
              );
              if (appCheckToken != null) {
                options.headers['X-Firebase-AppCheck'] = appCheckToken;
              }
            } catch (e) {
              // Si falla (ej. ambiente dev sin configurar), continuar petición
              // Será el backend el responsable de rechazar si es obligatorio.
            }
            return handler.next(options);
          },
          onError: (DioException e, handler) {
            // Log global error o un unauthorized event
            return handler.next(e);
          },
        ),
      );
    }
  }

  Dio get instance => dio;
}
