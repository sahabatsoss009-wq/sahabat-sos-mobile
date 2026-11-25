import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/background_service.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/widgets/permission_gate.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/core/services/notification_service.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menangkap unhandled Flutter errors agar tidak force close di release mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 Flutter Error caught: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 Uncaught Platform Error: $error\n$stack');
    return true; // Cegah app force close
  };

  // Tampilan fallback ramah pengguna jika terjadi error rendering widget di release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              SizedBox(height: 12),
              Text(
                'Tampilan Mengalami Kendala',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Terjadi kendala saat memuat bagian ini. Silakan muat ulang halaman atau buka kembali aplikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await initInjection();
  } catch (e) {
    debugPrint('initInjection error di main: $e');
  }

  // Inisialisasi notifikasi untuk menangani banner alert dan klik notifikasi SOS
  try {
    final notificationService = NotificationService();
    await notificationService.init();
    final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();

    // Cek apakah aplikasi diluncurkan (cold start) dari klik notifikasi
    final NotificationAppLaunchDetails? launchDetails =
        await localNotif.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        try {
          final sosData = jsonDecode(payload);
          // Delay sedikit agar frame pertama selesai dirender sebelum menampilkan popup
          Future.delayed(const Duration(seconds: 1), () {
            GlobalEventBus.showSosAssignmentPopup.value = sosData;
          });
        } catch (e) {
          debugPrint('Error parsing initial notification payload: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('NotificationService init error di main: $e');
  }

  // Listen to Tuya in UI (foreground) to navigate when app is open
  try {
    final tuyaListener = GetIt.instance<TuyaBackgroundListener>();
    tuyaListener.onSosDetected = (event) {
      final currentPath =
          AppRouter.router.routerDelegate.currentConfiguration.uri.path;
      if (currentPath != AppRoutes.sosStatus) {
        AppRouter.router.push(AppRoutes.sosStatus);
      }
    };
  } catch (e) {
    debugPrint('TuyaListener error di main: $e');
  }

  // Start Background Service
  // (This will also start Tuya and WebSockets in the background isolate)
  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('initializeBackgroundService error di main: $e');
  }

  runApp(const PermissionGate(child: SahabatSosApp()));
}
