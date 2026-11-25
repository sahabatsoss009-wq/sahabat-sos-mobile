import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/models/tuya_device_model.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/models/tuya_dp_event_model.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/emergency_trigger_service.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_channel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEmergencyTriggerService extends EmergencyTriggerService {
  final List<TuyaDpEvent> triggeredEvents = [];

  _FakeEmergencyTriggerService(SharedPreferences prefs)
      : super(
          dio: Dio(),
          prefs: prefs,
          locationService: LocationService(dio: Dio(), prefs: prefs),
        );

  @override
  Future<bool> triggerEmergency(TuyaDpEvent event) async {
    triggeredEvents.add(event);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.sahabatsos.app/tuya_method');
  const eventChannel = MethodChannel('com.sahabatsos.app/tuya_events');

  group('TuyaDeviceModel battery sentinel parsing', () {
    test('treats negative battery sentinel (-1) as null when no battery DP exists', () {
      final model = TuyaDeviceModel.fromJson({
        'device_id': 'sim_device_001',
        'name': 'Unknown Device',
        'is_online': false,
        'battery': -1,
        'signal_strength': 'unknown',
        'dps': <String, dynamic>{'1': true},
      });

      expect(model.batteryLevel, isNull);
    });

    test('resolves valid fallback DP battery when root battery is -1', () {
      final model = TuyaDeviceModel.fromJson({
        'device_id': 'tuya_ble_01',
        'name': 'SOS Button',
        'is_online': true,
        'battery': -1,
        'dps': <String, dynamic>{'3': 88},
      });

      expect(model.batteryLevel, 88);
    });
  });

  group('TuyaChannelService session serialization & devicesNotifier', () {
    late int initCalls;
    late int loginCalls;
    late List<String> listenedDeviceIds;

    setUp(() {
      initCalls = 0;
      loginCalls = 0;
      listenedDeviceIds = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        switch (call.method) {
          case 'initTuya':
            initCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return {'status': 'initialized'};
          case 'loginAnonymous':
            loginCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return {'status': 'logged_in', 'home_id': 101};
          case 'getDeviceList':
            return [
              {
                'device_id': 'tuya_btn_01',
                'name': 'Tombol SOS Utama',
                'product_id': 'prod_1',
                'is_online': true,
                'battery': 95,
                'signal_strength': 'strong',
                'dps': <String, dynamic>{},
              },
            ];
          case 'removeDevice':
            return {'status': 'success'};
          case 'listenDevice':
            listenedDeviceIds.add((call.arguments as Map)['deviceId'] as String);
            return {'status': 'listening'};
          default:
            return {'status': 'ok'};
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventChannel, (call) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventChannel, null);
    });

    test('serializes concurrent ensureSessionInitialized calls and syncs devicesNotifier', () async {
      final service = TuyaChannelService();

      await Future.wait([
        service.ensureSessionInitialized('token-123'),
        service.ensureSessionInitialized('token-123'),
        service.ensureSessionInitialized('token-123'),
      ]);

      expect(initCalls, 1);
      expect(loginCalls, 1);
      expect(service.isListening, isTrue);

      final devices = await service.getDeviceList();
      expect(devices, hasLength(1));
      expect(service.devicesNotifier.value, hasLength(1));
      expect(service.devicesNotifier.value.first.deviceId, 'tuya_btn_01');

      await service.removeDevice('tuya_btn_01');
      expect(service.devicesNotifier.value, isEmpty);

      service.resetSession();
      expect(service.isListening, isFalse);

      await service.ensureSessionInitialized('token-456');
      expect(loginCalls, 2);

      service.dispose();
    });

    test('TuyaBackgroundListener skips relawan role and processes SOS events for pengguna', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'vol-token',
        'user_role': 'relawan',
      });
      final relawanPrefs = await SharedPreferences.getInstance();
      final service = TuyaChannelService();
      final fakeEmergency = _FakeEmergencyTriggerService(relawanPrefs);
      final relawanListener = TuyaBackgroundListener(
        tuyaService: service,
        emergencyService: fakeEmergency,
        prefs: relawanPrefs,
      );

      await relawanListener.start();
      expect(relawanListener.isRunning, isFalse);
      expect(loginCalls, 0);

      SharedPreferences.setMockInitialValues({
        'auth_token': 'user-token',
        'user_role': 'pengguna',
      });
      final userPrefs = await SharedPreferences.getInstance();
      final userEmergency = _FakeEmergencyTriggerService(userPrefs);
      final userListener = TuyaBackgroundListener(
        tuyaService: service,
        emergencyService: userEmergency,
        prefs: userPrefs,
      );

      TuyaDpEvent? detectedEvent;
      userListener.onSosDetected = (e) => detectedEvent = e;

      await userListener.start();
      expect(userListener.isRunning, isTrue);
      expect(loginCalls, 1);
      expect(listenedDeviceIds, contains('tuya_btn_01'));

      // Emit a simulated SOS event through native EventChannel binary messenger
      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'com.sahabatsos.app/tuya_events',
        codec.encodeSuccessEnvelope(
          '{"device_id":"tuya_btn_01","dps":{"23":true},"timestamp":1730000000000,"type":"dp_update","is_simulation":false}',
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(detectedEvent, isNotNull);
      expect(detectedEvent!.deviceId, 'tuya_btn_01');
      expect(userEmergency.triggeredEvents, hasLength(1));

      userListener.stop();
      expect(userListener.isRunning, isFalse);
      // Shared EventChannel remains active for UI screens until resetSession()
      expect(service.isListening, isTrue);

      service.dispose();
    });
  });
}
