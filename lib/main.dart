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

// --- 🌟 1. BACKGROUND HANDLER (SAAT HP DI-LOCK/APLIKASI TERTUTUP) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notifikasi Masuk (Background): ${message.messageId}");

  // Serahkan semua urusan ke fungsi sakti!
  await NotificationManager.saveIncomingMessage(message);
}

// --- FUNGSI POP-UP FOREGROUND (MENGGANTUNG DARI ATAS) ---
Future<void> _tampilkanNotifikasiSuaraKeras(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_panggilan_poli',
    'Panggilan Antrean',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? message.data['title'] ?? 'Notifikasi',
    message.notification?.body ?? message.data['body'] ?? '',
    platformDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalNotificationService().initPusher();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- 🌟 2. FOREGROUND HANDLER (SAAT APLIKASI DIBUKA) ---
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint("Notifikasi Masuk (Foreground): ${message.messageId}");
    await NotificationManager.saveIncomingMessage(message);
    _tampilkanNotifikasiSuaraKeras(message);
  });

  // --- 🌟 3. ON MESSAGE OPENED APP (SAAT NOTIF DIKLIK DARI BACKGROUND) ---
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    debugPrint("Notifikasi Diklik (Background->Foreground): ${message.messageId}");

    // Panggil fungsi simpan untuk menambal Link (jika sebelumnya hilang karena OS)
    await NotificationManager.saveIncomingMessage(message);

    String? link = message.data['action_link'];
    if (link != null && link.toString().startsWith('route:')) {
      String routeName = link.toString().replaceFirst('route:', '');
      navigatorKey.currentState?.pushNamed(routeName);
    }
  });

  // --- 🌟 4. GET INITIAL MESSAGE (SAAT NOTIF DIKLIK DARI TERMINATED) ---
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      debugPrint("Notifikasi Diklik (Terminated->Foreground): ${message.messageId}");

      Future.delayed(const Duration(milliseconds: 1000), () async {
        // Panggil fungsi simpan untuk memastikan Link tidak hilang
        await NotificationManager.saveIncomingMessage(message);

        String? link = message.data['action_link'];
        if (link != null && link.toString().startsWith('route:')) {
          String routeName = link.toString().replaceFirst('route:', '');
          navigatorKey.currentState?.pushNamed(routeName);
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
        refreshToken: null, alamat: userData['alamat'], provinsi: userData['provinsi'],
        kabupaten: userData['kabupaten'], kecamatan: userData['kecamatan'],
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