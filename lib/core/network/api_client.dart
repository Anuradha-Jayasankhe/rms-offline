import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }

  // Auth-specific
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  // Sync-specific
  Future<Map<String, dynamic>> pushSync(
    String restaurantId,
    List<Map<String, dynamic>> changes,
  ) async {
    final response = await post(
      '/sync/push',
      data: {'restaurantId': restaurantId, 'changes': changes},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pullSync(
    String restaurantId,
    DateTime? lastSync,
  ) async {
    final response = await get(
      '/sync/pull',
      queryParameters: {
        'restaurantId': restaurantId,
        if (lastSync != null) 'since': lastSync.toIso8601String(),
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
