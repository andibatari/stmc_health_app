import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:stmc_health_app/main.dart';
import 'package:stmc_health_app/services/mcu_service.dart';
import '../../global_notification.dart';
import '../../services/auth_service.dart';
import '../notification/notification_page.dart';
import 'lingkungan_page.dart';
import 'mcu_page.dart';
import 'package:intl/intl.dart';

const Color primaryRed = Color(0xFFC00000);
const Color darkRed = Color(0xFF8B0000);
const Color lightRed = Color(0xFFFBECEC);
const Color bgGrey = Color(0xFFF8F9FA);

typedef TabChangeCallback = void Function(int index);

// =========================================================
// 1. HOMEPAGE & FIREBASE LOGIC
// =========================================================
class HomePage extends StatefulWidget {
  final TabChangeCallback onTabChange;

  const HomePage({super.key, required this.onTabChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isNotificationSetupRunning = false;

  @override
  void initState() {
    super.initState();
    setupPushNotification();
  }

  void setupPushNotification() async {
    if (_isNotificationSetupRunning) return;
    _isNotificationSetupRunning = true;

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Minta Izin ke Pengguna HP
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      // 2. Jika Diizinkan, Ambil Token dan Kirim ke Server
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        sendTokenToLaravel(token);
      }

    } catch (e) {
      debugPrint("Error setup FCM: $e");
    } finally {
      _isNotificationSetupRunning = false;
    }
  }

  void sendTokenToLaravel(String? token) async {
    if (token == null) return;

    final myApp = context.findAncestorWidgetOfExactType<MyApp>();
    final accessToken = myApp?.userStateNotifier.value.accessToken;

    if (accessToken != null) {
      final url = Uri.parse("https://stmc-health.my.id/api/update-fcm-token");
      try {
        await http.post(
          url,
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: {'fcm_token': token},
        );
        debugPrint("✅ FCM Token berhasil di-update dengan autentikasi!");
      } catch (e) {
        debugPrint("Gagal kirim FCM Token: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myApp = context.findAncestorWidgetOfExactType<MyApp>();
    if (myApp == null) return const SizedBox.shrink();

    final userStateNotifier = myApp.userStateNotifier;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        return Scaffold(
          backgroundColor: bgGrey,
          body: RefreshIndicator(
            color: primaryRed,
            backgroundColor: Colors.white,
            onRefresh: () async {
              try {
                final authService = AuthService();
                final loginData = await authService.getPersistedLoginData();

                if (loginData != null) {
                  final userData = loginData['userData'];
                  dynamic isEmployeeRaw = userData['is_employee'] ?? userData['isEmployee'];
                  bool isEmployee = (isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString() == 'true');
                  String updatedRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

                  String? updatedName = userData['nama'];
                  String? updatedSap = userData['no_sap'] ?? userData['nik'];

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
                  HomeHeader(userState: userState, onTabChange: widget.onTabChange),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayananLainnya(onTabChange: widget.onTabChange, userState: userState),
                        const SizedBox(height: 30),
                        JadwalMedicalCheckUpAPI(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// 2. HEADER MODERN BERGRADIEN
// =========================================================
class HomeHeader extends StatelessWidget {
  final UserState userState;
  final TabChangeCallback onTabChange;

  const HomeHeader({super.key, required this.userState, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final McuService mcuService = McuService();
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryRed, darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPadding + 15, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Image.asset(
                  'assets/images/logo-stmc.png',
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                ),
              ),
              ValueListenableBuilder<bool>(
                  valueListenable: hasUnreadNotifNotifier,
                  builder: (context, hasUnread, child) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          onTap: () {
                            hasUnreadNotifNotifier.value = false;
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const NotificationPage()),
                                );
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                          ),
                        ),

                        if (hasUnread)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryRed, width: 2),
                              ),
                            ),
                          )
                      ],
                    );
                  }
              )
            ],
          ),

          const SizedBox(height: 25),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _buildWelcomeCardModern(userState)),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
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
          ),

          const SizedBox(height: 20),
          _buildRegistrationButtonModern(context, onTabChange),
        ],
      ),
    );
  }

  Widget _buildWelcomeCardModern(UserState userState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lightRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Together We Build a Better Future",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: primaryRed,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Selamat Datang,", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            userState.displayText ?? "Pengguna",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget _buildQueueCardModern(String noAntrean) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("ANTREAN", style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                  noAntrean,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: primaryRed)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationButtonModern(BuildContext context, TabChangeCallback onTabChange) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF5F5F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const McuPendaftaranPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          highlightColor: lightRed,
          splashColor: lightRed.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: primaryRed, size: 24),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text("Pendaftaran Medical Check Up", style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 3. MENU LAYANAN WIDGET (TAMPILAN DIPERBAIKI)
// =========================================================
class LayananLainnya extends StatelessWidget {
  final TabChangeCallback onTabChange;
  final UserState userState;

  const LayananLainnya({super.key, required this.onTabChange, required this.userState});

  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: primaryRed, size: 28),
              SizedBox(width: 10),
              Text("Akses Ditolak", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Fitur Pemantauan Lingkungan hanya tersedia untuk Karyawan PT Semen Tonasa. Anda tidak memiliki hak akses.",
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              child: const Text("Mengerti", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
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
          'Menu Layanan', // 🌟 Teks "Layanan Lainnya" diubah menjadi "Menu Layanan"
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.start, // 🌟 Diubah dari spaceBetween ke start agar rapat
          children: <Widget>[
            _buildServiceIcon(
              icon: Icons.monitor_heart_rounded,
              label: 'MCU',
              backgroundColor: lightRed,
              iconColor: primaryRed,
              onTap: () => onTabChange(1),
            ),
            const SizedBox(width: 32), // 🌟 Diberi jarak statis yang ideal
            _buildServiceIcon(
              icon: Icons.eco_rounded,
              label: 'Lingkungan',
              backgroundColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              onTap: () {
                if (isKaryawan) {
                  onTabChange(2);
                } else {
                  _showAccessDeniedDialog(context);
                }
              },
            ),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: backgroundColor.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}

// =========================================================
// 4. KARTU JADWAL MEDICAL CHECK UP
// =========================================================
class JadwalMedicalCheckUp extends StatelessWidget {
  final List<McuData> mcuList;

  const JadwalMedicalCheckUp({super.key, required this.mcuList});

  @override
  Widget build(BuildContext context) {
    final activeSchedule = mcuList.firstWhere(
          (m) => m.status == 'Scheduled',
      orElse: () => McuData(id: 0, checkUpNumber: '#', noAntrean: '-', date: 'Tidak Ada', doctorName: 'N/A', status: 'N/A', category: 'N/A', resume: null, downloadUrl: null, qrCodeId: '-'),
    );

    final hasActiveSchedule = activeSchedule.id != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Jadwal Medical Check Up',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            InkWell(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 16.0, color: primaryRed),
              ),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: hasActiveSchedule ? primaryRed.withOpacity(0.3) : Colors.transparent, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15.0, offset: const Offset(0, 5))
              ],
            ),
            child: hasActiveSchedule
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Medical Check Up ${activeSchedule.checkUpNumber}',
                        style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Text("Aktif", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    )
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: lightRed, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_today_rounded, size: 16, color: primaryRed),
                    ),
                    const SizedBox(width: 12),
                    Text(activeSchedule.date, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.medical_information_rounded, size: 16, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dokter Pemeriksa', style: TextStyle(fontSize: 11.0, color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text(activeSchedule.doctorName, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Belum ada jadwal MCU aktif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Silakan lakukan pendaftaran terlebih dahulu.', style: TextStyle(fontSize: 13, color: Colors.black38)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}