import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tuya-Only Device & SOS Payload Tests', () {
    test('AppRouter exposes Tuya routes and does not register /smartband', () {
      final paths = AppRouter.router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(paths, contains(AppRoutes.tuyaDevices));
      expect(paths, contains(AppRoutes.tuyaDeviceScan));
      expect(paths, contains(AppRoutes.tuyaDeviceWifiScan));
      expect(paths, isNot(contains('/smartband')));
    });

    test(
      'DashboardRemoteDataSource.triggerEmergency sends mobile + tuya payload without smartwatch fields',
      () async {
        SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
        final prefs = await SharedPreferences.getInstance();

        Map<String, dynamic>? capturedPayload;
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPayload = Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'data': {'id': 123},
                  },
                ),
              );
            },
          ),
        );

        final dataSource = DashboardRemoteDataSourceImpl(
          dio: dio,
          prefs: prefs,
        );

        final sosId = await dataSource.triggerEmergency(
          latitude: -7.7925,
          longitude: 110.3658,
          address: 'Jl. Malioboro',
          telemetryData: {
            'battery_level': 88,
            'signal_strength': '4G / Wi-Fi',
            'device_info': {
              'brand': 'Samsung',
              'model': 'Galaxy A54',
              'battery_level': 88,
            },
          },
          tuyaDeviceInfo: {
            'device_id': 'tuya_btn_1',
            'device_name': 'Tombol SOS',
            'is_online': true,
          },
        );

        expect(sosId, 123);
        expect(capturedPayload, isNotNull);
        expect(capturedPayload!['trigger_source'], 'app_button');
        expect(capturedPayload!.containsKey('heart_rate'), isFalse);

        final deviceInfo =
            Map<String, dynamic>.from(capturedPayload!['device_info'] as Map);
        expect(deviceInfo.containsKey('mobile'), isTrue);
        expect(deviceInfo['tuya']['device_id'], 'tuya_btn_1');
        expect(deviceInfo.containsKey('smartwatch'), isFalse);
        expect(deviceInfo.containsKey('smartband'), isFalse);
      },
    );
  });
}
