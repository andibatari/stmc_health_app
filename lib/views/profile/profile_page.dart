import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart'; // 🌟 TAMBAHAN IMPORT
import 'package:stmc_health_app/views/login/login_page.dart';
import 'package:stmc_health_app/views/profile/tentang_aplikasi_page.dart';
import 'package:stmc_health_app/views/notification/notification_page.dart'; // 🌟 TAMBAHAN IMPORT
import '../../main.dart';
import '../../services/auth_service.dart';
import 'data_pribadi_page.dart';
import 'package:stmc_health_app/constants.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

const Color primaryRed = Color(0xFFC00000);
const Color bgGrey = Color(0xFFF8F9FA);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _uploadFotoProfil(BuildContext context, UserState userState) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
      if (pickedImage == null) return;

      if (context.mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: primaryRed)));
      }

      var request = http.MultipartRequest('POST', Uri.parse('$KBaseUrl/update-profile'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${userState.accessToken}';
      request.files.add(await http.MultipartFile.fromPath('foto_profil', pickedImage.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final updatedProfile = responseData['user_profile'];
          final newFotoUrl = updatedProfile['foto'];

          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(newFotoUrl == null ? "⚠️ Foto Ditolak" : "✅ Berhasil"),
                content: Text(newFotoUrl == null ? "Ukuran foto terlalu besar melebihi batas 'upload_max_filesize' server Anda." : "Foto profil berhasil diperbarui!"),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)))],
              ),
            );
          }

          final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
          Map<String, dynamic> newUserData = Map.from(userState.userData ?? {});
          newUserData['foto'] = updatedProfile['foto'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(newUserData));

          userStateNotifier.value = UserState(
            isLoggedIn: userState.isLoggedIn, accessToken: userState.accessToken, refreshToken: userState.refreshToken, userData: newUserData, displayText: userState.displayText, sap: userState.sap, name: userState.name, role: userState.role, email: userState.email, jobTitle: userState.jobTitle, nik: userState.nik, no_hp: userState.no_hp, tinggi_badan: userState.tinggi_badan, berat_badan: userState.berat_badan, alamat: userState.alamat, provinsi: userState.provinsi, kabupaten: userState.kabupaten, kecamatan: userState.kecamatan,
          );
        } else {
          if (context.mounted) {
            showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("⚠️ Gagal"), content: Text(responseData['message'] ?? "Gagal menyimpan foto"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))]));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("🔥 Error"), content: Text("Terjadi kesalahan sistem: $e"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))]));
      }
    }
  }

  void _logout(BuildContext context, UserState userState) async {
    // 🌟 1. Tampilkan loading agar proses tidak terpotong
    if (context.mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: primaryRed)));
    }

    try {
      // 🌟 2. HAPUS TOKEN FIREBASE DARI HP
      // Ini memastikan notifikasi user lama (M. Taufik) tidak masuk lagi setelah logout
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint("Gagal hapus FCM token: $e");
    }

    final AuthService authService = AuthService();
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    await authService.logout();

    // 🌟 3. BERSIHKAN BRANKAS NOTIFIKASI LOKAL
    NotificationManager.clearSession();

    userStateNotifier.value = UserState.initial();

    if (context.mounted) {
      Navigator.pop(context); // Tutup loading
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginPage(userStateNotifier: userStateNotifier)), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: ValueListenableBuilder<UserState>(
        valueListenable: userStateNotifier,
        builder: (context, userState, child) {
          return RefreshIndicator(
            color: primaryRed,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 30.0, bottom: 40.0),
                    decoration: const BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Builder(
                                builder: (context) {
                                  final rawFotoUrl = userState.userData?['foto'];
                                  String validUrl = '';
                                  bool hasValidFoto = false;

                                  if (rawFotoUrl != null && rawFotoUrl.toString().trim().isNotEmpty) {
                                    String tempUrl = rawFotoUrl.toString().trim();
                                    if (!tempUrl.startsWith('http')) {
                                      final uri = Uri.parse(KBaseUrl);
                                      final domain = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
                                      tempUrl = tempUrl.startsWith('/') ? '$domain$tempUrl' : '$domain/$tempUrl';
                                    }
                                    validUrl = '$tempUrl${tempUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}';
                                    hasValidFoto = true;
                                  }

                                  return Container(
                                    width: 100, height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 4),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                                    ),
                                    child: ClipOval(
                                      child: hasValidFoto
                                          ? Image.network(
                                          validUrl,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.person_rounded, color: primaryRed, size: 55);
                                          }
                                      )
                                          : const Icon(Icons.person_rounded, color: primaryRed, size: 55),
                                    ),
                                  );
                                }
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => _uploadFotoProfil(context, userState),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))]),
                                  child: const Icon(Icons.camera_alt_rounded, color: primaryRed, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          userState.name ?? "Nama Pengguna",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            userState.jobTitle ?? "Jabatan Tidak Tersedia",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          _buildProfileMenu(
                            icon: Icons.person_rounded,
                            title: 'Data Pribadi',
                            subtitle: 'Ubah profil, email, sandi & alamat',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => DataPribadiPage(userState: userState)));
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildProfileMenu(
                            icon: Icons.info_rounded,
                            title: 'Tentang Aplikasi',
                            subtitle: 'Versi aplikasi, S&K, Bantuan',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const TentangAplikasiPage()));
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildProfileMenu(
                            icon: Icons.logout_rounded,
                            title: 'Keluar',
                            subtitle: 'Akhiri sesi aplikasi',
                            isLogout: true,
                            onTap: () => _logout(context, userState),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileMenu({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isLogout = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10.0, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          splashColor: (isLogout ? Colors.red : primaryRed).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isLogout ? Colors.red : primaryRed).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isLogout ? Colors.red : primaryRed, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isLogout ? Colors.red : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}