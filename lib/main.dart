import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:stmc_health_app/services/auth_service.dart';
import 'package:stmc_health_app/views/main_wrapper.dart';
import 'views/login/login_page.dart'; // Import halaman Login
import 'dart:convert'; // Diperlukan untuk jsonDecode
import 'package:shared_preferences/shared_preferences.dart'; // Diperlukan untuk persistency
import 'global_notification.dart';
import 'firebase_options.dart'; // Wajib di-import!

// Definisikan warna yang digunakan di theme (sesuaikan dengan yang Anda gunakan)
const Color primaryRed = Color(0xFFC00000);

// Data Model untuk menyimpan state pengguna
class UserState {
  final bool isLoggedIn;
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? userData;
  final String? displayText;
  final String? sap;
  final String? name;
  final String? role;
  final String? email;
  final String? jobTitle;
  final String? nik;
  final String? no_hp;
  final String? tinggi_badan;
  final String? berat_badan;
  final String? alamat;
  final String? provinsi;
  final String? kabupaten;
  final String? kecamatan;

  UserState({
    required this.isLoggedIn,
    this.accessToken,
    this.refreshToken,
    this.userData,
    this.displayText,
    this.sap,
    this.name,
    this.role,
    this.email,
    this.jobTitle,
    this.nik,
    this.no_hp,
    this.tinggi_badan,
    this.berat_badan,
    this.alamat,
    this.provinsi,
    this.kabupaten,
    this.kecamatan,
  });

  // Constructor factory yang diperbaiki untuk initial state
  factory UserState.initial() => UserState(
    isLoggedIn: false,
    name: "Tamu",
    role: "GUEST",
    displayText: "Selamat Datang",
    accessToken: null, userData: null, sap: null, email: null, jobTitle: null,
    nik: null, no_hp: null, tinggi_badan: null, berat_badan: null, refreshToken: null, alamat: null,
    provinsi: null, kabupaten: null, kecamatan: null,
  );
}

// Ini adalah fungsi agar HP tetap bisa menerima notifikasi meski aplikasi sedang ditutup
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Notifikasi Masuk (Background): ${message.notification?.title}");
}

void main() async {
  // Wajib dipanggil sebelum menggunakan SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  // NYALAKAN TELINGA GLOBAL SEBELUM APLIKASI JALAN
  await GlobalNotificationService().initPusher();

  // Menyalakan mesin Firebase menggunakan konfigurasi otomatis dari FlutterFire CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Mendaftarkan fungsi background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final AuthService authService = AuthService();
  UserState initialUserState = UserState.initial();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');
  final userDataJson = prefs.getString('userData');

  if (token != null && userDataJson != null) {
    try {
      final Map<String, dynamic> userData = jsonDecode(userDataJson);

      // --- PERBAIKAN LOGIKA ROLE ---
      // Pastikan mengecek is_employee dengan benar sesuai output backend
      dynamic isEmployeeRaw = userData['is_employee'];
      bool isEmployee = (isEmployeeRaw == true ||
          isEmployeeRaw == 1 ||
          isEmployeeRaw.toString().toLowerCase() == 'true');

      String userRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      // --- Membuat OBJEK UserState BARU (Karena UserState bersifat final) ---
      initialUserState = UserState(
        isLoggedIn: true,
        accessToken: token,
        userData: userData,
        sap: userData['no_sap'] ?? userData['nik'],
        name: userData['nama'],
        displayText: '${userData['no_sap'] ?? userData['nik']} - ${userData['nama']}',
        role: userRole,
        // Ambil data detail lainnya (pastikan kunci cocok dengan API)
        email: userData['email'],
        jobTitle: userData['jabatan'], // Asumsi kunci 'jabatan'
        nik: userData['nik'],
        no_hp: userData['no_hp'],
        tinggi_badan: userData['tinggi_badan']?.toString(),
        berat_badan: userData['berat_badan']?.toString(), // Asumsi kunci ada
        refreshToken: null, // Jika tidak ada, set null
        alamat: userData['alamat'],
        provinsi: userData['provinsi'],
        kabupaten: userData['kabupaten'],
        kecamatan: userData['kecamatan'],
      );

    } catch (e) {
      // Jika parsing gagal, bersihkan data login agar user harus login lagi
      await authService.clearLoginData();
      print('Error loading persisted user data: $e'); // Debugging
    }
  }

  // Meneruskan state awal ke MyApp
  runApp(MyApp(initialUserState: initialUserState));
}

class MyApp extends StatelessWidget {
  final UserState initialUserState;

  // KOREKSI SINTAKSIS: Deklarasi dan inisialisasi ValueNotifier di constructor
  final ValueNotifier<UserState> userStateNotifier;

  MyApp({super.key, required this.initialUserState})
      : userStateNotifier = ValueNotifier<UserState>(initialUserState); // <-- KOREKSI UTAMA

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, //
      title: 'STMC Health',
      home: ValueListenableBuilder<UserState>(
        valueListenable: userStateNotifier,
        builder: (context, userState, child) {
          // Logika Penentu: Jika isLoggedIn true ke Wrapper, jika false ke Login
          if (userState.isLoggedIn) {
            return const MainWrapper();
          } else {
            return LoginPage(userStateNotifier: userStateNotifier);
          }
        },
      ),
    );
  }
}