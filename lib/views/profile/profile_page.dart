import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // <--- TAMBAH INI
import 'package:stmc_health_app/views/login/login_page.dart';
import 'package:stmc_health_app/views/profile/tentang_aplikasi_page.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'data_pribadi_page.dart';
import 'package:stmc_health_app/constants.dart';

// Definisikan ulang warna yang diperlukan jika file ini berdiri sendiri (jika primaryRed belum diimpor)
const Color primaryRed = Color(0xFFC00000);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Fungsi untuk Logout (Merubah state isLoggedIn menjadi false)
  void _logout(BuildContext context, UserState userState) async {
    final AuthService authService = AuthService();
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    // 1. Jalankan logout (yang di dalamnya sudah memanggil clearLoginData)
    await authService.logout();

    // 2. Reset state notifier SEBELUM navigasi
    userStateNotifier.value = UserState.initial();

    // 3. Navigasi paksa ke halaman login
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginPage(userStateNotifier: userStateNotifier),
        ),
            (route) => false, // Hapus semua history navigasi
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil notifier dari root (MyApp)
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return Scaffold(
      // PERBAIKAN: Set latar belakang Scaffold menjadi merah
      backgroundColor: primaryRed,
      appBar: null,
      body: SafeArea(
        child: ValueListenableBuilder<UserState>(
          valueListenable: userStateNotifier,
          builder: (context, userState, child) {
            return Column(
              children: [
                // 1. Header Kustom Profile (Text "Profile")
                _buildCustomHeader(),

                // 2. Konten Scrollable di dalam Container Putih
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
                        // Aksi saat profil ditarik ke bawah
                        await Future.delayed(const Duration(seconds: 1));

                        // Tips: Anda bisa memanggil API getProfile terbaru di sini
                        // untuk memperbarui userStateNotifier jika ada perubahan data di server
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // PERBAIKAN: Header Profile (Foto di tengah atas)
                            _buildProfileHeader(context, userState),

                            const SizedBox(height: 10),

                            // Menu Data Pribadi
                            _buildProfileMenu(
                              icon: Icons.person_outline,
                              title: 'Data Pribadi',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  // Meneruskan userState untuk mengisi data pribadi
                                  MaterialPageRoute(builder: (context) => DataPribadiPage(userState: userState)),
                                );
                              },
                            ),

                            // Menu Tentang Aplikasi
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

                            // Menu Logout (Fitur Baru)
                            _buildProfileMenu(
                              icon: Icons.logout,
                              title: 'Logout',
                              onTap: () => _logout(context,userState), // Panggil fungsi logout
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

  // Helper Baru: Custom Header Profile (Tulisan "Profile")
  Widget _buildCustomHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 10.0, bottom: 20.0, left: 16.0),
      child: Text(
        'Profile',
        style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  // Widget untuk Header Profile yang telah direvisi
  Widget _buildProfileHeader(BuildContext context, UserState userState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 25.0, bottom: 25.0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // 1. FOTO PROFILE (Dinamis dari Server)
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: primaryRed.withOpacity(0.1),
                // PERBAIKAN: Cek apakah ada URL foto di dalam userData
                backgroundImage: (userState.userData != null && userState.userData?['foto'] != null)
                    ? NetworkImage(userState.userData!['foto'])
                    : null,
                // Tampilkan Icon hanya jika foto tidak ada
                child: (userState.userData == null || userState.userData?['foto'] == null)
                    ? const Icon(Icons.person, color: primaryRed, size: 40)
                    : null,
              ),
              // Tombol visual kamera
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryRed, width: 1.5)
                  ),
                  child: const Icon(Icons.camera_alt, color: primaryRed, size: 16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // 2. NAMA DAN JABATAN
          Text(
            userState.name ?? "Nama Pengguna",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 2),
          Text(
            // Menampilkan Jabatan dari UserState
            userState.jobTitle ?? "Jabatan Tidak Tersedia",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk Item Menu Profile
  Widget _buildProfileMenu({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3.0,
            offset: Offset(0, 2),
          ),
        ],
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
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16.5, color: Colors.black87),
                  ),
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