import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../main_wrapper.dart'; // Import untuk mengakses UserState dan MyApp

const Color primaryRed = Color(0xFFC00000);
const Color secondaryRed = Color(0xFF8B0000); // Warna merah tua untuk tombol

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

  bool _obscureText = true; // Untuk toggle visibility password
  bool _isLoading = false; // Status loading untuk tombol

  // Inisiasi service
  final AuthService _authService = AuthService();

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true; // Mulai loading
    });


    final String identifier = _identifierController.text; // SAP/NIK/Email
    final String password = _passwordController.text;

    // --- LOGIKA API LOGIN ---
    final result = await _authService.login(identifier, password);

    setState(() {
      _isLoading = false; // Selesai loading
    });

    if (result['success'] == true) {
      // Ambil data yang dikembalikan dari AuthService
      final Map<String, dynamic> userData = result['userData'] as Map<String, dynamic>;
      final String accessToken = result['accessToken'] as String;
      // final String refreshToken = result['refreshToken'] as String; // Jika ada

      // Asumsi: Kita masih mengambil data profil dari model lama,
      // tetapi data yang lebih lengkap harus ada di `userData`.
      // Ambil data penting dari userData untuk tampilan cepat
      final String? noSap = userData['no_sap'] ?? userData['nik'];
      final String? nama = userData['nama'];
      final String? email = userData['email'];
      final String? jobTitle = userData['jabatan'];
      final String? nik = userData['nik'];
      final String? noHp = userData['no_hp'];
      // final String userRole = (userData['isEmployee'] == true) ? 'KARYAWAN' : 'NON_KARYAWAN';
      dynamic isEmployeeRaw = userData['isEmployee'] ?? userData['is_employee'];

      // Konversi nilai mentah menjadi boolean yang pasti
      final bool isEmployee = isEmployeeRaw != null &&
          (isEmployeeRaw == true ||
              isEmployeeRaw == 1 ||
              isEmployeeRaw.toString().toLowerCase() == 'true');

      final String userRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      // --- Update state aplikasi (UserState) DENGAN TOKEN & DATA LENGKAP ---
      widget.userStateNotifier.value = UserState(
        isLoggedIn: true,
        // Data Penting untuk Otorisasi API
        accessToken: accessToken,           // <--- SIMPAN TOKEN
        // refreshToken: refreshToken,       // SIMPAN REFRESH TOKEN (jika ada)
        userData: userData,                 // <--- SIMPAN DATA LENGKAP DARI API

        // Data untuk Tampilan Cepat
        sap: userData['no_sap'] ?? userData['nik'],
        name: userData['nama'],
        displayText: '${userData['no_sap'] ?? userData['nik']} - ${userData['nama']}',
        role: userRole,
        email: email,
        jobTitle: jobTitle,
        nik: nik,
        no_hp: noHp,
      );

      // Navigasi ke MainWrapper setelah login berhasil
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainWrapper()),
        );
      }

    } else {
      // Tampilkan error (Tetap sama)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: secondaryRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 60.0, left: 32.0, right: 32.0, bottom: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Logo dan Tagline ---
              Image.asset(
                'assets/images/logo-stmc.png', // Ganti dengan path logo Anda yang benar
                height: 60,
              ),
              const SizedBox(height: 5),
              const Text(
                "STMC",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  height: 0.9, // Untuk mendekatkan teks
                ),
              ),
              const Text(
                "Semen Tonasa Medical Centre",
                style: TextStyle(
                  fontSize: 12,
                  color: primaryRed,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Together We Build a Better Future",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryRed,
                    fontStyle: FontStyle.italic
                ),
              ),

              const SizedBox(height: 60),

              // --- Kartu Login ---
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: primaryRed.withOpacity(0.5))
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "LOGIN",
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: primaryRed,
                            letterSpacing: 1.5
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Input No. SAP ---
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.text,
                        decoration: _buildInputDecoration(
                          Icons.person, "SAP/NIK/Email",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nomor identitas harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Input Password ---
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: _buildInputDecoration(
                          Icons.lock, "Password",
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscureText ? Icons.visibility_off : Icons.visibility,
                                color: primaryRed.withOpacity(0.7),
                                size: 20
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 5),

                      // --- Lupa Password ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implementasi navigasi Lupa Password
                          },
                          child: const Text(
                            "Lupa Password?",
                            style: TextStyle(
                              color: primaryRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // --- Tombol LOGIN ---
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin, // Non-aktifkan saat loading
                          style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryRed,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5
                          ),
                          child: _isLoading
                              ? const SizedBox( // Tampilkan indicator saat loading
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                              : const Text(
                            "LOGIN",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // // --- Sign Up ---
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     const Text(
                      //       "Belum punya akun? ",
                      //       style: TextStyle(color: Colors.black54),
                      //     ),
                      //     InkWell(
                      //       onTap: () {
                      //         // TODO: Implementasi navigasi Sign Up
                      //       },
                      //       child: const Text(
                      //         "Sign Up",
                      //         style: TextStyle(
                      //           color: primaryRed,
                      //           fontWeight: FontWeight.bold,
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
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
      prefixIcon: Icon(icon, color: primaryRed.withOpacity(0.7)),
      hintText: label,
      hintStyle: TextStyle(color: Colors.grey[700]),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}