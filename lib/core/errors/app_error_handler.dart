import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilitas terpusat untuk menerjemahkan error teknis (DioException, SocketException,
/// HTTP Status Code, dan Exception sistem) menjadi pesan bahasa Indonesia yang
/// ramah, empatik, dan mudah dipahami oleh pengguna umum / lansia / difabel.
class AppErrorHandler {
  AppErrorHandler._();

  /// Mengonversi error apapun menjadi kalimat bahasa Indonesia yang ramah pengguna.
  static String getFriendlyMessage(dynamic error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'Terjadi kendala yang tidak terduga. Silakan coba kembali.';
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi internet lambat atau terputus. Mohon periksa sinyal ponsel Anda.';

        case DioExceptionType.connectionError:
          if (error.error is SocketException) {
            return 'Tidak dapat terhubung ke server. Pastikan perangkat Anda terhubung ke internet.';
          }
          return 'Gangguan jaringan. Mohon periksa koneksi Wi-Fi atau data seluler Anda.';

        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final dynamic data = error.response?.data;

          // 1. Cek apakah ada pesan error dari backend dalam bentuk Map (JSON aman)
          if (data is Map) {
            // Cek 'message'
            if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
              final rawMsg = data['message'].toString().trim();
              final translated = _translateKnownMessage(rawMsg);
              if (translated != null) return translated;
              return rawMsg;
            }

            // Cek validation errors dari Laravel
            if (data['errors'] is Map) {
              final errorsMap = data['errors'] as Map;
              if (errorsMap.isNotEmpty) {
                final firstErrVal = errorsMap.values.first;
                if (firstErrVal is List && firstErrVal.isNotEmpty) {
                  final rawMsg = firstErrVal.first.toString();
                  final translated = _translateKnownMessage(rawMsg);
                  return translated ?? rawMsg;
                } else if (firstErrVal != null) {
                  return firstErrVal.toString();
                }
              }
            }

            // Cek key 'error'
            if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
              final rawMsg = data['error'].toString().trim();
              final translated = _translateKnownMessage(rawMsg);
              return translated ?? rawMsg;
            }
          }

          // 2. Fallback berdasarkan HTTP Status Code
          if (statusCode == 400) {
            return 'Permintaan data tidak valid. Silakan periksa kembali.';
          } else if (statusCode == 401) {
            return 'Sesi login Anda telah berakhir demi keamanan. Silakan masuk kembali.';
          } else if (statusCode == 403) {
            return 'Anda tidak memiliki hak akses untuk melakukan tindakan ini.';
          } else if (statusCode == 404) {
            return 'Data atau layanan yang diminta tidak ditemukan.';
          } else if (statusCode == 422) {
            return 'Data yang dimasukkan belum lengkap atau belum sesuai.';
          } else if (statusCode != null && statusCode >= 500) {
            return 'Server kami sedang dalam perbaikan sementara. Mohon coba beberapa saat lagi.';
          }
          return defaultMessage ?? 'Terjadi kendala pada server. Silakan coba kembali.';

        case DioExceptionType.cancel:
          return 'Proses dibatalkan oleh pengguna.';

        case DioExceptionType.badCertificate:
          return 'Koneksi keamanan tidak valid. Pastikan pengaturan tanggal dan jam perangkat sudah benar.';

        case DioExceptionType.unknown:
        default:
          if (error.error is SocketException) {
            return 'Tidak ada koneksi internet. Pastikan perangkat Anda terhubung ke internet.';
          }
          return defaultMessage ?? 'Terjadi kendala yang tidak terduga. Silakan coba beberapa saat lagi.';
      }
    }

    if (error is SocketException) {
      return 'Tidak dapat terhubung ke internet. Mohon periksa koneksi Wi-Fi atau paket data Anda.';
    }

    if (error is FormatException) {
      return 'Format data tidak sesuai. Silakan muat ulang halaman.';
    }

    // Bersihkan prefix 'Exception: ' jika ada
    final str = error.toString().replaceFirst('Exception: ', '').trim();
    if (str.isEmpty ||
        str.contains('TypeError') ||
        str.contains('NullCheck') ||
        str.contains('NoSuchMethodError')) {
      return defaultMessage ?? 'Terjadi kendala sistem. Silakan muat ulang halaman.';
    }

    final translated = _translateKnownMessage(str);
    return translated ?? str;
  }

  /// Menerjemahkan pesan error umum dalam bahasa Inggris (bawaan Laravel/Firebase/Dio)
  static String? _translateKnownMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower == 'unauthenticated.' || lower == 'unauthenticated') {
      return 'Sesi login Anda telah berakhir. Silakan masuk kembali.';
    }
    if (lower.contains('the given data was invalid')) {
      return 'Data yang dimasukkan belum lengkap atau belum sesuai.';
    }
    if (lower.contains('the email has already been taken')) {
      return 'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau login.';
    }
    if (lower.contains('these credentials do not match our records') ||
        lower.contains('invalid credentials') ||
        lower.contains('password salah')) {
      return 'Email atau kata sandi yang Anda masukkan salah.';
    }
    if (lower.contains('user not found')) {
      return 'Akun tidak ditemukan. Silakan periksa kembali email Anda.';
    }
    if (lower.contains('server error') || lower.contains('internal server error')) {
      return 'Server sedang mengalami gangguan sementara. Silakan coba kembali nanti.';
    }
    if (lower.contains('too many requests') || lower.contains('too many attempts')) {
      return 'Terlalu banyak percobaan. Mohon tunggu beberapa saat sebelum mencoba lagi.';
    }
    return null;
  }

  /// Menampilkan SnackBar error yang ramah pengguna, berdesain elegan & aksesibel
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    String? prefix,
    String? defaultMessage,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    final friendlyMsg = getFriendlyMessage(error, defaultMessage: defaultMessage);
    final fullText = prefix != null && prefix.isNotEmpty
        ? '$prefix: $friendlyMsg'
        : friendlyMsg;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Pesan yang aman untuk dibaca oleh Text-to-Speech (TTS) tanpa istilah teknis
  static String getFriendlyTtsMessage(dynamic error, {String prefix = 'Gagal'}) {
    final friendlyMsg = getFriendlyMessage(error);
    return '$prefix. $friendlyMsg';
  }

  /// Dialog Kegagalan Darurat Khusus untuk Tombol SOS:
  /// Jika server mati atau offline saat darurat, segera tawarkan panggilan langsung ke 112
  static Future<void> showEmergencyFailureDialog(
    BuildContext context, {
    dynamic error,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Color(0xFFDC2626),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sinyal Darurat Belum Terhubung',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi tidak dapat terhubung ke server atau internet saat ini. Jangan panik, segera hubungi nomor panggilan darurat nasional.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.phone_fill, color: Color(0xFF00695C), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Panggilan Darurat: 112 (Bebas Pulsa)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (onRetry != null) onRetry();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final uri = Uri.parse('tel:112');
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                        return;
                      }
                    } catch (_) {}
                    if (context.mounted) {
                      showErrorSnackBar(
                        context,
                        'Tidak dapat membuka aplikasi telepon secara otomatis. Silakan hubungi 112 secara langsung.',
                      );
                    }
                  },
                  icon: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 16),
                  label: const Text(
                    'Panggil 112',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
