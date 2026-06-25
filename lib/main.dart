import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:stmc_health_app/services/auth_service.dart';
import 'package:stmc_health_app/views/main_wrapper.dart';
import 'package:stmc_health_app/views/notification/notification_page.dart';
import 'package:stmc_health_app/views/home/mcu_page.dart';
import 'views/login/login_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_notification.dart';
import 'firebase_options.dart';

const Color primaryRed = Color(0xFFC00000);

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

// --- 🌟 1. BACKGROUND HANDLER (SAAT APLIKASI TERTUTUP/MATI) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notifikasi Masuk (Background): ${message.messageId}");

  final FlutterLocalNotificationsPlugin backgroundLocalNotif = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await backgroundLocalNotif.initialize(const InitializationSettings(android: androidSettings));

  await NotificationManager.saveIncomingMessage(message);

  // 1. LOGIKA UNTUK ALARM PANGGILAN POLI
  if (message.data['tipe'] == 'panggilan_poli') {
    const String channelId = 'channel_panggilan_poli_v6';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'Panggilan Antrean Poli',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ding_dong'),
      enableVibration: true,
      fullScreenIntent: true,
    );

    final String title = message.data['title'] ?? 'PANGGILAN PEMERIKSAAN';
    final String body = message.data['body'] ?? 'Giliran Anda! Silakan masuk ke ruangan.';

    await backgroundLocalNotif.show(
      message.hashCode, title, body,
      const NotificationDetails(android: androidDetails),
    );

    // 🌟 2. TAMBAHKAN LOGIKA INI AGAR PENGINGAT MCU / UMUM MUNCUL SAAT BACKGROUND
  }
}

// --- FUNGSI MUNCULKAN ALARM CUSTOM SOUND FOREGROUND ---
Future<void> _tampilkanAlarmPanggilanForeground(RemoteMessage message) async {
  const String channelId = 'channel_panggilan_poli_v6';
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId, 'Panggilan Antrean Poli',
    importance: Importance.max, priority: Priority.high, playSound: true,
    sound: RawResourceAndroidNotificationSound('ding_dong'),
    enableVibration: true, fullScreenIntent: true,
  );

  final String title = message.notification?.title ?? message.data['title'] ?? 'PANGGILAN PEMERIKSAAN';
  final String body = message.notification?.body ?? message.data['body'] ?? 'Giliran Anda! Silakan masuk ke ruangan.';

  await flutterLocalNotificationsPlugin.show(
    message.hashCode, title, body,
    const NotificationDetails(android: androidDetails),
  );
}

// --- FUNGSI MUNCULKAN SPANDUK PENGUMUMAN FOREGROUND (SUARA DEFAULT) ---
Future<void> _tampilkanNotifikasiPengumumanForeground(RemoteMessage message) async {
  const String channelId = 'channel_pengumuman_v1';
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId, 'Pengumuman Umum',
    importance: Importance.high, priority: Priority.high, playSound: true,
    // Tidak menyebutkan 'sound', jadi akan otomatis pakai suara default HP
  );

  final String title = message.notification?.title ?? message.data['title'] ?? 'Notifikasi STMC';
  final String body = message.notification?.body ?? message.data['body'] ?? '';

  await flutterLocalNotificationsPlugin.show(
    message.hashCode, title, body,
    const NotificationDetails(android: androidDetails),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 🌟 1. CHANNEL ALARM PANGGILAN POLI (Suara Ding-Dong)
  const AndroidNotificationChannel channelAlarm = AndroidNotificationChannel(
    'channel_panggilan_poli_v6',
    'Panggilan Antrean Poli',
    description: 'Alarm notifikasi untuk panggilan antrean pasien',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ding_dong'),
    enableVibration: true,
  );

  // 🌟 2. CHANNEL PENGUMUMAN & PENGINGAT (Suara Default HP)
  const AndroidNotificationChannel channelPengumuman = AndroidNotificationChannel(
    'channel_pengumuman_v1',
    'Pengumuman Umum',
    description: 'Notifikasi untuk pengingat jadwal dan informasi',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Daftarkan KEDUA channel tersebut ke OS Android
  final platformPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  await platformPlugin?.createNotificationChannel(channelAlarm);
  await platformPlugin?.createNotificationChannel(channelPengumuman);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- FOREGROUND HANDLER (SAAT APLIKASI SEDANG DIBUKA) ---
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint("🔥 Notifikasi Masuk (Foreground): ${message.messageId}");

    // 🌟 LOGIKA MENERIMA SINYAL SILUMAN
    if (message.data['tipe'] == 'silent_update') {
      debugPrint("🔄 Sinyal Silent Update Diterima! Merefresh layar...");
      // Ini akan memicu _refreshMcuDataFromServer secara otomatis!
      globalRefreshTrigger.value++;
      return; // Berhenti di sini, JANGAN simpan ke kotak masuk pesan!
    }

    // Jika bukan siluman, simpan pesan ke brankas
    await NotificationManager.saveIncomingMessage(message);

    if (message.data['tipe'] == 'panggilan_poli') {
      // 1. Munculkan Notifikasi Pop up (Heads Up) dengan suara ding-dong
      await _tampilkanAlarmPanggilanForeground(message);
      // 2. Munculkan Alert Dialog & Mainkan Audio interaktif
      GlobalNotificationService().pemicuAlarmInteraktifForeground(message);
    } else {
      // Jika aplikasi sedang dibuka, munculkan spanduk pengumuman secara manual
      await _tampilkanNotifikasiPengumumanForeground(message);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    await NotificationManager.saveIncomingMessage(message);
    String? link = message.data['action_link'];
    if (link != null && link.startsWith('route:')) {
      navigatorKey.currentState?.pushNamed(link.replaceFirst('route:', ''));
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      Future.delayed(const Duration(milliseconds: 1000), () async {
        await NotificationManager.saveIncomingMessage(message);
        String? link = message.data['action_link'];
        if (link != null && link.startsWith('route:')) {
          navigatorKey.currentState?.pushNamed(link.replaceFirst('route:', ''));
        }
      });
    }
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
      bool isEmployee = (isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString().toLowerCase() == 'true');
      String userRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      initialUserState = UserState(
        isLoggedIn: true, accessToken: token, userData: userData,
        sap: userData['no_sap'] ?? userData['nik'], name: userData['nama'],
        displayText: '${userData['no_sap'] ?? userData['nik']} - ${userData['nama']}',
        role: userRole, email: userData['email'], jobTitle: userData['jabatan'],
        nik: userData['nik'], no_hp: userData['no_hp'],
        tinggi_badan: userData['tinggi_badan']?.toString(), berat_badan: userData['berat_badan']?.toString(),
      );
      String initialIdentifier = initialUserState.sap ?? initialUserState.nik ?? 'unknown';
      await NotificationManager.loadUserNotifications(initialIdentifier);
    } catch (e) {
      await authService.clearLoginData();
    }
  }

  final ValueNotifier<UserState> uStateNotifier = ValueNotifier<UserState>(initialUserState);
  uStateNotifier.addListener(() async {
    final state = uStateNotifier.value;
    if (state.isLoggedIn) {
      String identifier = state.sap ?? state.nik ?? 'unknown';
      await NotificationManager.loadUserNotifications(identifier);
    } else {
      NotificationManager.clearSession();
    }
  });

  runApp(MyApp(initialUserState: initialUserState, userStateNotifier: uStateNotifier));
}

class MyApp extends StatelessWidget {
  final UserState initialUserState;
  final ValueNotifier<UserState> userStateNotifier;

  MyApp({super.key, required this.initialUserState, required this.userStateNotifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'STMC Health',
      routes: {
        '/informasi-mcu': (context) => const McuInformasiPage(),
        '/pengajuan-mcu': (context) => const McuPendaftaranPage(),
      },
      home: ValueListenableBuilder<UserState>(
        valueListenable: userStateNotifier,
        builder: (context, userState, child) {
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