import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'sos_alert_channel_v2';
  static const String channelName = 'Peringatan Darurat SOS';
  static const String channelDescription =
      'Notifikasi saat ada panggilan SOS masuk';

<<<<<<< HEAD
  static const String laporanChannelId = 'laporan_alert_channel_v1';
  static const String laporanChannelName = 'Laporan Masuk Warga';
  static const String laporanChannelDescription =
      'Notifikasi saat ada laporan baru dari warga';
=======
  static const String reportChannelId = 'laporan_alert_channel';
  static const String reportChannelName = 'Laporan Bantuan Komunitas';
  static const String reportChannelDescription =
      'Notifikasi saat ada laporan permohonan bantuan cepat dari warga';
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _localNotif.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final data = jsonDecode(payload);
              debugPrint('🔔 Notifikasi diklik, payload: $data');
              if (data is Map<String, dynamic>) {
                if (data.containsKey('kategori_laporan') || data.containsKey('lokasi_laporan')) {
                  // Laporan notification diklik -> refresh peta
                  GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
                } else {
                  GlobalEventBus.showSosAssignmentPopup.value = data;
                }
              }
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final alertChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('siren'),
        );
        await androidPlugin.createNotificationChannel(alertChannel);

<<<<<<< HEAD
        final laporanChannel = AndroidNotificationChannel(
          laporanChannelId,
          laporanChannelName,
          description: laporanChannelDescription,
=======
        const reportChannel = AndroidNotificationChannel(
          reportChannelId,
          reportChannelName,
          description: reportChannelDescription,
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
<<<<<<< HEAD
        await androidPlugin.createNotificationChannel(laporanChannel);
=======
        await androidPlugin.createNotificationChannel(reportChannel);
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService berhasil diinisialisasi');
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  Future<void> showEmergencyNotification(Map<String, dynamic> sosData) async {
    await init();

    try {
      final dynamic rawId = sosData['id'];
      final int notifId =
          (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '999') ?? 999;

      final pengguna = sosData['pengguna'] is Map
          ? sosData['pengguna'] as Map<String, dynamic>
          : <String, dynamic>{};
      final user = sosData['user'] is Map
          ? sosData['user'] as Map<String, dynamic>
          : <String, dynamic>{};

      final String victimName = pengguna['name'] ??
          user['nama'] ??
          user['name'] ??
          sosData['nama'] ??
          sosData['nama_pelapor'] ??
          'Warga Membutuhkan Bantuan';

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'Panggilan Darurat Masuk',
          fullScreenIntent: true,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('siren'),
          category: AndroidNotificationCategory.alarm,
        ),
      );

      await _localNotif.show(
        id: notifId,
        title: '🚨 PANGGILAN DARURAT SOS!',
        body: '$victimName membutuhkan bantuan segera di dekat Anda!',
        notificationDetails: notificationDetails,
        payload: jsonEncode(sosData),
      );

      debugPrint('📢 Heads-up Notification SOS #$notifId berhasil ditampilkan untuk: $victimName');
    } catch (e) {
      debugPrint('❌ Gagal menampilkan notifikasi darurat: $e');
    }
  }

  Future<void> showLaporanNotification(Map<String, dynamic> laporanData) async {
    await init();

    try {
      final dynamic rawId = laporanData['id'];
<<<<<<< HEAD
      final int notifId =
          (rawId is int) ? (rawId + 10000) : (int.tryParse(rawId?.toString() ?? '888') ?? 888) + 10000;

      final String kategori = (laporanData['kategori_laporan'] ?? 'Darurat').toString().toUpperCase();
      final String pelapor = laporanData['pengguna_nama'] ?? 'Warga';
      final String lokasi = laporanData['lokasi_laporan'] ?? 'di sekitar Anda';
      final String deskripsi = laporanData['deskripsi'] ?? '';

      final bodyText = deskripsi.isNotEmpty
          ? '$pelapor melaporkan $kategori di $lokasi: $deskripsi'
          : '$pelapor melaporkan kejadian $kategori di $lokasi.';

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          laporanChannelId,
          laporanChannelName,
          channelDescription: laporanChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Laporan Masuk',
=======
      final int notifId = (rawId is int)
          ? rawId
          : int.tryParse(rawId?.toString() ?? '888') ?? 888;

      final String reporterName = laporanData['pengguna_nama'] ??
          (laporanData['pengguna'] is Map
              ? laporanData['pengguna']['name']
              : null) ??
          'Warga';
      final String kategori =
          laporanData['kategori_laporan'] ?? 'Bantuan Cepat';
      final String lokasi = laporanData['lokasi_laporan'] ?? '';

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          reportChannelId,
          reportChannelName,
          channelDescription: reportChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8
          enableVibration: true,
          playSound: true,
        ),
      );

      await _localNotif.show(
        id: notifId,
<<<<<<< HEAD
        title: '📋 LAPORAN BARU: $kategori',
        body: bodyText,
=======
        title: '📋 Laporan Bantuan Baru: $kategori',
        body: '$reporterName membutuhkan pendampingan di $lokasi',
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8
        notificationDetails: notificationDetails,
        payload: jsonEncode(laporanData),
      );

<<<<<<< HEAD
      debugPrint('📢 Heads-up Notification Laporan #$notifId berhasil ditampilkan ($kategori)');
=======
      debugPrint('📢 Notification Laporan #$notifId berhasil ditampilkan');
>>>>>>> 403a24feee2e07598e6617b5218949e6922914e8
    } catch (e) {
      debugPrint('❌ Gagal menampilkan notifikasi laporan: $e');
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _localNotif.cancel(id: id);
    } catch (e) {
      debugPrint('Error cancel notification: $e');
    }
  }
}
