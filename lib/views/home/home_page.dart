import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // IMPORT FCM BARU
import 'package:http/http.dart' as http; // IMPORT HTTP BARU
import 'package:stmc_health_app/main.dart';
import 'package:stmc_health_app/services/mcu_service.dart';
import '../../global_notification.dart';
import '../../services/auth_service.dart';
import 'lingkungan_page.dart'; // Asumsi file ini ada
import 'mcu_page.dart'; // Asumsi file ini ada

// Definisi warna utama yang digunakan dalam desain
const Color primaryRed = Color(0xFFC00000);
const Color lightRed = Color(0xFFFBECEC); // Untuk latar belakang icon MCU
// Definisikan tipe callback
typedef TabChangeCallback = void Function(int index);

// =========================================================
// 1. UBAH HOMEPAGE MENJADI STATEFUL WIDGET AGAR BISA INITSTATE
// =========================================================
class HomePage extends StatefulWidget {
  final TabChangeCallback onTabChange;

  const HomePage({super.key, required this.onTabChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1. TAMBAHKAN VARIABEL PENGAMAN INI DI ATAS initState
  bool _isNotificationSetupRunning = false;

  @override
  void initState() {
    super.initState();
    // 2. Panggil fungsi Firebase saat Beranda dimuat
    setupPushNotification();
  }

  // =========================================================
  // 3. LOGIKA INTI FIREBASE CLOUD MESSAGING (FCM)
  // =========================================================
  void setupPushNotification() async {
    // 2. CEK JIKA PROSES SEDANG BERJALAN, JANGAN JALANKAN LAGI
    if (_isNotificationSetupRunning) return;

    // Tandai bahwa proses sedang berjalan
    _isNotificationSetupRunning = true;

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Minta izin ke pengguna (Wajib untuk Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Ambil FCM Token HP
        String? token = await messaging.getToken();
        debugPrint("===== INI ADALAH FCM TOKEN HP KAMU =====");
        debugPrint(token);
        debugPrint("========================================");

        // Kirim token ke API Laravel jika user sudah terautentikasi
        sendTokenToLaravel(token);
      }

      // Tangkap Notifikasi saat aplikasi sedang dibuka (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(message.notification!.title ?? "Pengumuman"),
              content: Text(message.notification!.body ?? ""),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup", style: TextStyle(color: primaryRed)),
                )
              ],
            ),
          );
        }
      });

    } catch (e) {
      debugPrint("Error setup FCM: $e");
    } finally {
      // 3. SETELAH SELESAI (SUKSES/GAGAL), BUKA KEMBALI KUNCI PENGAMAN
      _isNotificationSetupRunning = false;
    }
  }

  void sendTokenToLaravel(String? token) async {
    if (token == null) return;

    // Ambil ID Karyawan dari Global State yang ada di MyApp
    final myApp = context.findAncestorWidgetOfExactType<MyApp>();
    final userId = myApp?.userStateNotifier.value.userData?['id'];

    if (userId != null) {
      final url = Uri.parse("https://stmc-health.my.id/api/update-fcm-token");
      try {
        await http.post(url, body: {
          'karyawan_id': userId.toString(),
          'fcm_token': token,
        });
        debugPrint("FCM Token berhasil dikirim ke server!");
      } catch (e) {
        debugPrint("Gagal kirim FCM Token: $e");
      }
    }
  }
  // =========================================================

  @override
  Widget build(BuildContext context) {
    /// Pastikan MyApp sudah terbungkus dengan benar di main.dart
    final myApp = context.findAncestorWidgetOfExactType<MyApp>();
    if (myApp == null) return const SizedBox.shrink();

    final userStateNotifier = myApp.userStateNotifier;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        return RefreshIndicator(
          color: primaryRed,
          onRefresh: () async {
            try {
              // 1. Ambil data terbaru dari penyimpanan lokal (SharedPreferences)
              final authService = AuthService();
              final loginData = await authService.getPersistedLoginData();

              if (loginData != null) {
                final userData = loginData['userData'];

                // 2. Logika penentuan role (Karyawan/Non-Karyawan)
                dynamic isEmployeeRaw = userData['is_employee'] ?? userData['isEmployee'];
                bool isEmployee = (isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString() == 'true');
                String updatedRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

                String? updatedName = userData['nama'];
                String? updatedSap = userData['no_sap'] ?? userData['nik'];

                // 3. Update state global
                userStateNotifier.value = UserState(
                  isLoggedIn: true,
                  accessToken: loginData['accessToken'],
                  userData: userData,
                  name: updatedName,
                  sap: updatedSap,
                  displayText: '$updatedSap - $updatedName',
                  role: updatedRole,
                  jobTitle: userData['jabatan'],
                  email: userData['email'],
                  nik: userData['nik'],
                  no_hp: userData['no_hp'],
                  tinggi_badan: userData['tinggi_badan']?.toString(),
                  berat_badan: userData['berat_badan']?.toString(),
                  alamat: userData['alamat'],
                  provinsi: userData['provinsi'],
                  kabupaten: userData['kabupaten'],
                  kecamatan: userData['kecamatan'],
                );
              }

              await Future.delayed(const Duration(seconds: 1));

              if (context.mounted) {
                (context as Element).markNeedsBuild();
              }
            } catch (e) {
              debugPrint("Error saat refresh: $e");
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PERHATIKAN: Karena ini StatefulWidget, akses fungsi dari luar harus menggunakan 'widget.'
                HomeHeader(userState: userState, onTabChange: widget.onTabChange),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      LayananLainnya(onTabChange: widget.onTabChange, userState: userState),
                      const SizedBox(height: 25),
                      JadwalMedicalCheckUpAPI(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET UNTUK BAGIAN HEADER---

class HomeHeader extends StatelessWidget {
  // Tambahkan parameter untuk menerima data user
  final UserState userState;
  final TabChangeCallback onTabChange;

  const HomeHeader({super.key, required this.userState, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final McuService mcuService = McuService();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: primaryRed),
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/images/logo-stmc.png',
                width: 55,
                height: 55,
                fit: BoxFit.contain,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none,
                    color: Colors.white, size: 26),
              )
            ],
          ),

          SizedBox(height: 22),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 2,
                  child: _buildWelcomeCardModern(userState)),
              const SizedBox(width: 14),
              Expanded(
                flex: 1,
                // ✅ BUNGKUS DENGAN ValueListenableBuilder
                child: ValueListenableBuilder<int>(
                  valueListenable: globalRefreshTrigger,
                  builder: (context, triggerValue, child) {
                    return FutureBuilder<Map<String, dynamic>>(
                      future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
                      builder: (context, snapshot) {
                        String antreanUser = "-";
                        if (snapshot.hasData && snapshot.data!['success'] == true) {
                          List aktif = snapshot.data!['aktif'];
                          if (aktif.isNotEmpty) {
                            antreanUser = aktif.first['no_antrean'] ?? "-";
                          }
                        }
                        return _buildQueueCardModern(antreanUser);
                      },
                    );
                  },
                ),
              )
            ],
          ),

          SizedBox(height: 18),
          _buildRegistrationButtonModern(context, onTabChange),
        ],
      ),
    );
  }

  Widget _buildWelcomeCardModern(UserState userState) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Together We Build a Better Future",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: primaryRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text("Selamat Datang,", style: TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            // Tampilkan data user yang login
            userState.displayText ?? "Pengguna",

            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQueueCardModern(String noAntrean) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          const Text("ANTREAN", style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 4),
          FittedBox( // Agar teks panjang tidak overflow
            child: Text(noAntrean, style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: primaryRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationButtonModern(BuildContext context, TabChangeCallback onTabChange) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const McuPendaftaranPage()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded, color: primaryRed, size: 27),
                SizedBox(width: 13),
                Expanded(
                  child: Text("Registration Medical Check Up", style: TextStyle(
                      fontSize: 15.8, fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET UNTUK BAGIAN LAYANAN LAINNYA ---

class LayananLainnya extends StatelessWidget {
  final TabChangeCallback onTabChange;
  final UserState userState;

  LayananLainnya({super.key, required this.onTabChange, required this.userState});

  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: primaryRed, size: 28),
              SizedBox(width: 10),
              Text("Akses Ditolak", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Fitur Pemantauan Lingkungan hanya tersedia untuk Karyawan PT Semen Tonasa. Anda tidak memiliki hak akses.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              child: const Text("Tutup", style: TextStyle(color: primaryRed)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKaryawan = userState.role == 'KARYAWAN';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Layanan Lainnya',
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () {
                onTabChange(1);
              },
              child: _buildServiceIcon(
                icon: Icons.favorite,
                label: 'MCU',
                backgroundColor: lightRed,
                iconColor: primaryRed,
              ),
            ),

            const SizedBox(width: 15),

            InkWell(
              onTap: () {
                if (isKaryawan) {
                  onTabChange(2);
                } else {
                  _showAccessDeniedDialog(context);
                }
              },
              child: _buildServiceIcon(
                icon: Icons.eco_sharp,
                label: 'Lingkungan',
                backgroundColor: const Color(0xFFE6F5E8),
                iconColor: const Color(0xFF388E3C),
              ),
            ),

            const SizedBox(width: 15),
            _buildPlaceholderIcon(),
            const SizedBox(width: 15),
            _buildPlaceholderIcon(),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceIcon({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12.0)),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Icon(Icons.add, color: Colors.grey[600], size: 30),
        ),
        const SizedBox(height: 5),
        const Text('', style: TextStyle(fontSize: 12.0)),
      ],
    );
  }
}

class JadwalMedicalCheckUp extends StatelessWidget {
  final List<McuData> mcuList;

  const JadwalMedicalCheckUp({super.key, required this.mcuList});

  @override
  Widget build(BuildContext context) {
    final activeSchedule = mcuList.firstWhere(
            (m) => m.status == 'Scheduled',
        orElse: () => McuData(id: 0, checkUpNumber: '#', noAntrean: '-', date: 'Tidak Ada', doctorName: 'N/A', status: 'N/A', category: 'N/A', resume: null, downloadUrl: null, qrCodeId: '-'));

    final hasActiveSchedule = activeSchedule.id != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Jadwal Medical Check Up',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: () {
                // TODO: Navigasi ke halaman utama Jadwal MCU
              },
              child: const Icon(Icons.arrow_forward_ios, size: 16.0, color: primaryRed),
            ),
          ],
        ),
        const SizedBox(height: 15),

        InkWell(
          onTap: () {
            if (hasActiveSchedule) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => McuDetailPage(mcu: activeSchedule)),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: primaryRed.withOpacity(hasActiveSchedule ? 1.0 : 0.2), width: hasActiveSchedule ? 1.5 : 1.0),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5.0, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Check Up ${activeSchedule.checkUpNumber}',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Divider(height: 15, color: Colors.transparent),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: primaryRed),
                    SizedBox(width: 8),
                    Text(activeSchedule.date, style: TextStyle(fontSize: 14.0)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text('Dokter: ', style: TextStyle(fontSize: 14.0, color: Colors.black54)),
                    Text(activeSchedule.doctorName, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}