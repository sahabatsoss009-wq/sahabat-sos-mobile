import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../features/sos/data/datasources/emergency_contact_remote_data_source.dart';
import '../../features/sos/data/datasources/sos_remote_data_source.dart';
import '../../features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import '../../features/reports/data/datasources/report_remote_data_source.dart';
import '../../features/history/data/datasources/history_remote_data_source.dart';
import '../services/location_service.dart';
import '../services/accessibility_service.dart';
import '../services/sos_rejection_storage.dart';
import '../errors/app_error_handler.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../features/tuya_device/data/services/emergency_trigger_service.dart';
import '../../features/tuya_device/data/services/tuya_background_listener.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  await AccessibilityService.instance.init(sharedPreferences);
  await SosRejectionStorage.init(sharedPreferences);
  sl.registerLazySingleton<AccessibilityService>(
    () => AccessibilityService.instance,
  );
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final prefs = sl<SharedPreferences>();
          final token = prefs.getString('auth_token');
          if (token != null &&
              token.isNotEmpty &&
              !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException err, handler) async {
          final reqPath = err.requestOptions.path;
          final isAuthEndpoint = reqPath.contains('/auth/login') ||
              reqPath.contains('/auth/google') ||
              reqPath.contains('/auth/register') ||
              reqPath.contains('/auth/send-otp') ||
              reqPath.contains('/auth/verify-otp');

          if (!isAuthEndpoint && err.response?.statusCode == 401) {
            final prefs = sl<SharedPreferences>();
            final currentToken = prefs.getString('auth_token');
            if (currentToken != null) {
              await prefs.remove('auth_token');
              await prefs.remove('user_role');
              final context = AppRouter.navigatorKey.currentContext;
              if (context != null && context.mounted) {
                AppErrorHandler.showErrorSnackBar(
                  context,
                  'Sesi login Anda telah berakhir demi keamanan. Silakan masuk kembali.',
                );
              }
              AppRouter.router.go(AppRoutes.login);
            }
          }
          return handler.next(err);
        },
      ),
    );

    return dio;
  });

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<VolunteerRemoteDataSource>(
    () => VolunteerRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<EmergencyContactRemoteDataSource>(
    () => EmergencyContactRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<SosRemoteDataSource>(
    () => SosRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<HistoryRemoteDataSource>(
    () => HistoryRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );

  // Services
  sl.registerLazySingleton<LocationService>(
    () => LocationService(dio: sl(), prefs: sl()),
  );

  // Tuya Services
  sl.registerLazySingleton<TuyaChannelService>(() => TuyaChannelService());
  sl.registerLazySingleton<EmergencyTriggerService>(
    () =>
        EmergencyTriggerService(dio: sl(), prefs: sl(), locationService: sl()),
  );
  sl.registerLazySingleton<TuyaBackgroundListener>(
    () => TuyaBackgroundListener(
      tuyaService: sl(),
      emergencyService: sl(),
      prefs: sl(),
    ),
  );
}
