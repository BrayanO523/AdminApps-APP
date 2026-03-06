import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

// Provider del cliente Dio que inyecta el Bearer Token automáticamente
final dioClientProvider = Provider<DioClient>((ref) {
  const String baseUrl = 'https://admin-apps-api.sapinf.com/api';
  // const String baseUrl = 'http://localhost:3000/api';
  return DioClient(
    baseUrl: baseUrl,
    getToken: () async {
      final authState = ref.read(authViewModelProvider);
      return authState.user?.token;
    },
  );
});
