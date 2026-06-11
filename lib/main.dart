import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🌟 TAMBAHAN UNTUK ALARM
import 'package:stmc_health_app/services/auth_service.dart';
import 'package:stmc_health_app/views/main_wrapper.dart';
import 'package:stmc_health_app/views/notification/notification_page.dart';
import 'views/login/login_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_notification.dart';
import 'firebase_options.dart';

const Color primaryRed = Color(0xFFC00000);

// --- 🌟 1. INISIALISASI PLUGIN NOTIFIKASI GLOBAL ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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

// --- 🌟 2. FUNGSI BACKGROUND FIREBASE (SAAT APLIKASI DITUTUP) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Notifikasi Masuk (Background): ${message.notification?.title}");

  // Panggil fungsi alarm keras saat ada pesan masuk di background
  await _tampilkanNotifikasiSuaraKeras(message);
}

// --- 🌟 3. FUNGSI PEMBUAT ALARM & POP-UP KERAS ---
Future<void> _tampilkanNotifikasiSuaraKeras(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_panggilan_poli', // ID Channel (Harus sama dengan di Laravel dan AndroidManifest)
    'Panggilan Antrean', // Nama Channel
    channelDescription: 'Channel khusus untuk panggilan masuk dengan suara keras',
    importance: Importance.max, // 🚨 WAJIB MAX: Memaksa pop-up muncul di atas layar
    priority: Priority.high,    // 🚨 WAJIB HIGH
    playSound: true,            // Bunyikan suara
    enableVibration: true,      // Getarkan HP
    fullScreenIntent: true,     // 🚨 WAJIB TRUE: Memaksa layar HP menyala
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  final String title = message.notification?.title ?? message.data['title'] ?? 'PANGGILAN POLI!';
  final String body = message.notification?.body ?? message.data['body'] ?? 'Giliran Anda telah tiba. Silakan masuk.';

  await flutterLocalNotificationsPlugin.show(
    0, // 🌟 PERBAIKAN: Ubah dari DateTime.now().millisecond menjadi 0 agar selalu menimpa notif lama
    title,
    body,
    platformDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalNotificationService().initPusher();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- 🌟 4. KONFIGURASI NOTIFIKASI LOKAL ---
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Daftarkan fungsi background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- 🌟 5. TANGKAP PESAN SAAT APLIKASI SEDANG DIBUKA (FOREGROUND) ---
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Notifikasi Masuk (Foreground): ${message.notification?.title}");
    _tampilkanNotifikasiSuaraKeras(message);

    // ✅ MASUKKAN NOTIFIKASI FIREBASE KE DALAM HALAMAN NOTIFIKASI
    final newNotif = {
      'title': message.notification?.title ?? message.data['title'] ?? 'Pemberitahuan',
      'body': message.notification?.body ?? message.data['body'] ?? '',
      'link': message.data['link'] ?? '',
      'time': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
    };

    appNotificationsNotifier.value = [newNotif, ...appNotificationsNotifier.value];
    hasUnreadNotifNotifier.value = true;
    NotificationManager.saveUserNotifications(); // Simpan ke HP!
  });

  final AuthService authService = AuthService();
  UserState initialUserState = UserState.initial();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');
  final userDataJson = prefs.getString('userData');

  if (token != null && userDataJson != null) {
    try {
      final Map<String, dynamic> userData = jsonDecode(userDataJson);

      dynamic isEmployeeRaw = userData['is_employee'];
      bool isEmployee = (isEmployeeRaw == true ||
          isEmployeeRaw == 1 ||
          isEmployeeRaw.toString().toLowerCase() == 'true');

      String userRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      initialUserState = UserState(
        isLoggedIn: true,
        accessToken: token,
        userData: userData,
        sap: userData['no_sap'] ?? userData['nik'],
        name: userData['nama'],
        displayText: '${userData['no_sap'] ?? userData['nik']} - ${userData['nama']}',
        role: userRole,
        email: userData['email'],
        jobTitle: userData['jabatan'],
        nik: userData['nik'],
        no_hp: userData['no_hp'],
        tinggi_badan: userData['tinggi_badan']?.toString(),
        berat_badan: userData['berat_badan']?.toString(),
        refreshToken: null,
        alamat: userData['alamat'],
        provinsi: userData['provinsi'],
        kabupaten: userData['kabupaten'],
        kecamatan: userData['kecamatan'],
      );

    } catch (e) {
      await authService.clearLoginData();
      print('Error loading persisted user data: $e');
    }
  }

  runApp(MyApp(initialUserState: initialUserState));
}

class MyApp extends StatelessWidget {
  final UserState initialUserState;
  final ValueNotifier<UserState> userStateNotifier;

  MyApp({super.key, required this.initialUserState})
      : userStateNotifier = ValueNotifier<UserState>(initialUserState);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'STMC Health',
      home: ValueListenableBuilder<UserState>(
        valueListenable: userStateNotifier,
        builder: (context, userState, child) {
          if (userState.isLoggedIn) {
            // ✅ SAAT LOGIN: Panggil brankas khusus NIK user ini
            String identifier = userState.sap ?? userState.nik ?? 'unknown';
            NotificationManager.loadUserNotifications(identifier);

            return const MainWrapper();
          } else {
            // ✅ SAAT LOGOUT: Kunci dan bersihkan brankas dari layar
            NotificationManager.clearSession();

            return LoginPage(userStateNotifier: userStateNotifier);
          }
        },
      ),
    );
  }
}