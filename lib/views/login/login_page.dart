import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../main.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../main_wrapper.dart';

const Color primaryRed = Color(0xFFC00000);
const Color secondaryRed = Color(0xFF8B0000);

class LoginPage extends StatefulWidget {
  final ValueNotifier<UserState> userStateNotifier;

  const LoginPage({super.key, required this.userStateNotifier});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscureText = true;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  // 🌟 PERBAIKAN: Fungsi untuk mengambil token dengan *retry* (jika pertama kali null)
  Future<String?> _getFcmTokenWithRetry() async {
    String? token = await FirebaseMessaging.instance.getToken();

    // Jika masih null, tunggu 2 detik (mungkin Firebase sedang inisialisasi)
    if (token == null) {
      await Future.delayed(const Duration(seconds: 2));
      token = await FirebaseMessaging.instance.getToken();
    }
    return token;
  }

  // 🌟 FUNGSI BARU: MENANGANI TOMBOL LUPA PASSWORD DENGAN INTERAKSI PREMIUM
  void _showForgotPasswordBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 25),
              const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: primaryRed, size: 28),
                  SizedBox(width: 12),
                  Text("Pemulihan Kata Sandi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Untuk alasan keamanan data rekam medis (MCU), reset kata sandi akun karyawan dan pasien wajib melalui sistem verifikasi internal.",
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: primaryRed, size: 20),
                        SizedBox(width: 10),
                        Text("Langkah Pemulihan:", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Silakan kunjungi Ruang Admin IT / K3LL Semen Tonasa Medical Centre dengan membawa NIK/KTP untuk mencocokkan identitas fisik Anda.",
                      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Mengerti", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final String identifier = _identifierController.text;
    final String password = _passwordController.text;

    // 🌟 Gunakan fungsi retry
    String? fcmToken = await _getFcmTokenWithRetry();
    debugPrint("FCM Token yang akan dikirim: $fcmToken");

    // Kirim ke server
    final result = await _authService.login(identifier, password, fcmToken: fcmToken);
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final Map<String, dynamic> userData = result['userData'] as Map<String, dynamic>;
      final String accessToken = result['accessToken'] as String;

      final String? noSap = userData['no_sap'] ?? userData['nik'];
      final String? nama = userData['nama'];
      final String? email = userData['email'];
      final String? jobTitle = userData['jabatan'];
      final String? nik = userData['nik'];
      final String? noHp = userData['no_hp'];

      dynamic isEmployeeRaw = userData['isEmployee'] ?? userData['is_employee'];
      final bool isEmployee = isEmployeeRaw != null &&
          (isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString().toLowerCase() == 'true');
      final String userRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      widget.userStateNotifier.value = UserState(
        isLoggedIn: true,
        accessToken: accessToken,
        userData: userData,
        sap: noSap,
        name: nama,
        displayText: '$noSap - $nama',
        role: userRole,
        email: email,
        jobTitle: jobTitle,
        nik: nik,
        no_hp: noHp,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainWrapper()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: secondaryRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: primaryRed.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                    ]
                ),
                child: Image.asset('assets/images/logo-stmc.png', height: 70),
              ),
              const SizedBox(height: 15),
              const Text("STMC HEALTH", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryRed, letterSpacing: 1.2)),
              const Text("Semen Tonasa Medical Centre", style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              const Text("\"Together We Build a Better Future\"", style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
              const SizedBox(height: 45),

              Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text("Masuk ke Akun Anda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                      ),
                      const SizedBox(height: 30),

                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(Icons.badge_rounded, "SAP / NIK / Email"),
                        validator: (value) => value == null || value.isEmpty ? 'Identitas wajib diisi' : null,
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          Icons.lock_rounded, "Kata Sandi",
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey[500], size: 22),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Kata sandi wajib diisi' : null,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordBottomSheet(context), // 🌟 DIHUBUNGKAN KE BOTTOM SHEET
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), alignment: Alignment.centerRight),
                          child: const Text("Lupa Password?", style: TextStyle(color: primaryRed, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(IconData icon, String label, {Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[100],
      prefixIcon: Icon(icon, color: primaryRed.withOpacity(0.8), size: 22),
      hintText: label,
      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
    );
  }
}