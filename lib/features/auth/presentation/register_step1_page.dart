import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as event_bus;
import 'package:sahabat_sos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';

class RegisterStep1Page extends StatefulWidget {
  const RegisterStep1Page({super.key});

  @override
  State<RegisterStep1Page> createState() => _RegisterStep1PageState();
}

class _RegisterStep1PageState extends State<RegisterStep1Page> {
  static const Color primaryDark = Color(0xFF006D77);
  static const Color accentTeal = Color(0xFF0E9F6E);
  static const Color mutedText = Color(0xFF6B7080);

  bool _agreedToTerms = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6F8),
      resizeToAvoidBottomInset: false,
      body: Container(
        color: const Color(0xFFF5F6F8),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressSection(),
                          const SizedBox(height: 12),
                          _buildBrandRow(),
                          const SizedBox(height: 6),
                          const Text(
                            'Daftar Akun Sahabat SOS',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Lengkapi data untuk perlindungan darurat\nterpadu dan respons relawan cepat.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: mutedText,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGoogleCard(),
                          const SizedBox(height: 16),
                          _buildDemoButtons(),
                          const SizedBox(height: 24),
                          _buildTermsCheckbox(),
                          const Spacer(),
                          const SizedBox(height: 20),
                          _buildLoginPrompt(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandRow() {
    return Row(
      children: [Image.asset('assets/images/logo_full.png', height: 40)],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(CupertinoIcons.person_add, size: 15, color: accentTeal),
            SizedBox(width: 6),
            Text(
              'Langkah 1 dari 2: Registrasi Akun',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 0.5),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: const Color(0xFFDCE6DF),
                valueColor: const AlwaysStoppedAnimation<Color>(primaryDark),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isLoading = false;

  Widget _buildGoogleCard() {
    return InkWell(
      onTap: _isLoading
          ? null
          : () async {
              setState(() {
                _isLoading = true;
              });
              try {
                final authDataSource =
                    get_it.GetIt.instance<AuthRemoteDataSource>();
                final result = await authDataSource.signInWithGoogle();

                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                });

                if (result != null) {
                  final bool isProfileComplete =
                      result['is_profile_complete'] ?? false;

                  if (isProfileComplete) {
                    if (!mounted) return;
                    context.go(AppRoutes.dashboard);
                  } else {
                    if (!mounted) return;
                    context.push(AppRoutes.registerStep2);
                  }
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registrasi dibatalkan oleh user.'),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Gagal Registrasi: $e')));
              }
            },
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                _isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CupertinoActivityIndicator(radius: 12),
                      )
                    : Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                        width: 26,
                        height: 26,
                        errorBuilder: (_, _, _) => const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 26,
                          color: Colors.red,
                        ),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Lanjutkan dengan Akun Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Otomatis terhubung dengan email & nama\nterverifikasi',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: mutedText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: primaryDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A2E),
                height: 1.4,
              ),
              children: [
                TextSpan(text: 'Saya menyetujui '),
                TextSpan(
                  text: 'Ketentuan Layanan',
                  style: TextStyle(
                    color: accentTeal,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' &\n'),
                TextSpan(
                  text: 'Perlindungan Data Pribadi',
                  style: TextStyle(
                    color: accentTeal,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' Sahabat SOS untuk\npenyelamatan darurat.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: GestureDetector(
        onTap: () {
          context.go(AppRoutes.login);
        },
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: mutedText),
            children: [
              TextSpan(text: 'Sudah memiliki akun? '),
              TextSpan(
                text: 'Masuk di Sini',
                style: TextStyle(
                  color: primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginDemo(String email, String password) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final authDataSource = get_it.GetIt.instance<AuthRemoteDataSource>();
      final result = await authDataSource.loginWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) return;

      final token = result['token'];
      final prefs = get_it.GetIt.instance<SharedPreferences>();

      final dio = get_it.GetIt.instance<Dio>();
      final profileRes = await dio.get(
        ApiConstants.me,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      setState(() {
        _isLoading = false;
      });

      if (profileRes.statusCode == 200 && profileRes.data['user'] != null) {
        final userData = profileRes.data['user'];
        final role = userData['role'].toString().toLowerCase();
        await prefs.setString('user_role', role);
        if (role == 'relawan') {
          if (userData['id'] != null) {
            await prefs.setInt(
              'volunteer_id',
              (userData['id'] is int)
                  ? userData['id']
                  : int.tryParse(userData['id'].toString()) ?? 0,
            );
          }
          final verificationStatus =
              (userData['status_verifikasi'] ?? 'pending').toString().toLowerCase();
          await prefs.setString('verification_status', verificationStatus);
          event_bus.GlobalEventBus.volunteerVerificationStatus.value =
              (verificationStatus == 'terverifikasi');
          final isActive = (userData['is_active'] == true ||
              userData['is_active'] == 1 ||
              userData['is_active'] == '1');
          await prefs.setBool('user_is_active', isActive);
          event_bus.GlobalEventBus.volunteerActiveStatus.value = isActive;
          if (!mounted) return;
          context.go(AppRoutes.homeVolunteer);
        } else {
          if (!mounted) return;
          context.go(AppRoutes.dashboard);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal Login: $msg')),
      );
    }
  }

  Widget _buildDemoButtons() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFFD1D5DB))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ATAU LOGIN PENGUJIAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFD1D5DB))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _loginDemo('budi@sahabatsos.test', 'password123'),
                icon: const Icon(CupertinoIcons.person_fill, size: 16),
                label: const Text(
                  'Pengguna\n(Budi)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006D77),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _loginDemo('relawan1@sahabatsos.test', 'password123'),
                icon: const Icon(CupertinoIcons.shield_fill, size: 16),
                label: const Text(
                  'Relawan\n(Rian)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E9F6E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
