import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stmc_health_app/views/login/login_page.dart';
import 'package:stmc_health_app/views/profile/tentang_aplikasi_page.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'data_pribadi_page.dart';
import 'package:stmc_health_app/constants.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

const Color primaryRed = Color(0xFFC00000);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _uploadFotoProfil(BuildContext context, UserState userState) async {
    try {
      final picker = ImagePicker();

      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
      );

      if (pickedImage == null) return;

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );
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

          // 🚨 POP-UP DEBUGGER BARU (PENTING) 🚨
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(newFotoUrl == null ? "⚠️ FOTO DITOLAK SERVER" : "✅ BERHASIL"),
                content: Text(newFotoUrl == null
                    ? "Laravel merespon sukses, tapi API mengembalikan status foto = NULL.\n\nHal ini sering terjadi karena ukuran foto terlalu besar melebihi batas 'upload_max_filesize' di pengaturan php.ini server Anda."
                    : "URL Foto yang diterima Flutter:\n\n$newFotoUrl"),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))],
              ),
            );
          }

          final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
          Map<String, dynamic> newUserData = Map.from(userState.userData ?? {});
          newUserData['foto'] = updatedProfile['foto'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(newUserData));

          userStateNotifier.value = UserState(
            isLoggedIn: userState.isLoggedIn,
            accessToken: userState.accessToken,
            refreshToken: userState.refreshToken,
            userData: newUserData,
            displayText: userState.displayText,
            sap: userState.sap,
            name: userState.name,
            role: userState.role,
            email: userState.email,
            jobTitle: userState.jobTitle,
            nik: userState.nik,
            no_hp: userState.no_hp,
            tinggi_badan: userState.tinggi_badan,
            berat_badan: userState.berat_badan,
            alamat: userState.alamat,
            provinsi: userState.provinsi,
            kabupaten: userState.kabupaten,
            kecamatan: userState.kecamatan,
          );
        } else {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("⚠️ RESPON ANEH DARI SERVER"),
                content: Text("Body:\n\n${response.body}"),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))],
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("❌ SERVER ERROR (${response.statusCode})"),
              content: Text("Pesan Error:\n\n${response.body}"),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("🔥 APLIKASI FLUTTER CRASH"),
            content: Text("Penyebab:\n\n$e"),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup"))],
          ),
        );
      }
    }
  }

  void _logout(BuildContext context, UserState userState) async {
    final AuthService authService = AuthService();
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    await authService.logout();
    userStateNotifier.value = UserState.initial();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginPage(userStateNotifier: userStateNotifier),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return Scaffold(
      backgroundColor: primaryRed,
      appBar: null,
      body: SafeArea(
        child: ValueListenableBuilder<UserState>(
          valueListenable: userStateNotifier,
          builder: (context, userState, child) {
            return Column(
              children: [
                _buildCustomHeader(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                    ),
                    child: RefreshIndicator(
                      color: primaryRed,
                      onRefresh: () async {
                        await Future.delayed(const Duration(seconds: 1));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildProfileHeader(context, userState),
                            const SizedBox(height: 10),
                            _buildProfileMenu(
                              icon: Icons.person_outline,
                              title: 'Data Pribadi',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => DataPribadiPage(userState: userState)),
                                );
                              },
                            ),
                            _buildProfileMenu(
                              icon: Icons.info_outline,
                              title: 'Tentang Aplikasi',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const TentangAplikasiPage()),
                                );
                              },
                            ),
                            _buildProfileMenu(
                              icon: Icons.logout,
                              title: 'Logout',
                              onTap: () => _logout(context, userState),
                            ),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 10.0, bottom: 20.0, left: 16.0),
      child: Text(
        'Profile',
        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserState userState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 25.0, bottom: 25.0),
      decoration: const BoxDecoration(color: Colors.white),
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

                      // 🌟 FIX: Jika URL dari server berupa path relatif (misal: /profile_photos/xyz.jpg)
                      if (!tempUrl.startsWith('http')) {
                        final uri = Uri.parse(KBaseUrl);
                        final domain = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
                        tempUrl = tempUrl.startsWith('/') ? '$domain$tempUrl' : '$domain/$tempUrl';
                      }

                      // 🌟 FIX: Pastikan format anti-cache tidak merusak link GCS yang sudah punya query '?'
                      final cacheBuster = tempUrl.contains('?')
                          ? '&t=${DateTime.now().millisecondsSinceEpoch}'
                          : '?t=${DateTime.now().millisecondsSinceEpoch}';

                      validUrl = '$tempUrl$cacheBuster';
                      hasValidFoto = true;
                    }

                    return CircleAvatar(
                      radius: 40,
                      backgroundColor: primaryRed.withOpacity(0.1),
                      backgroundImage: hasValidFoto
                          ? NetworkImage(validUrl)
                          : null,
                      child: !hasValidFoto
                          ? const Icon(Icons.person, color: primaryRed, size: 40)
                          : null,
                    );
                  }
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _uploadFotoProfil(context, userState),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryRed, width: 1.5)
                    ),
                    child: const Icon(Icons.camera_alt, color: primaryRed, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            userState.name ?? "Nama Pengguna",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            userState.jobTitle ?? "Jabatan Tidak Tersedia",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenu({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3.0, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, color: primaryRed, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16.5, color: Colors.black87)),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}