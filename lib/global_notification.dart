import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:stmc_health_app/views/notification/notification_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// KUNCI GLOBAL NAVIGATION
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> globalRefreshTrigger = ValueNotifier<int>(0);
// 🌟 VARIABEL YANG HILANG SUDAH DIKEMBALIKAN DI SINI 🌟
int? globalActiveJadwalId;

class GlobalNotificationService {
  static final GlobalNotificationService _instance = GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  int _playCount = 0;
  bool _isAlarmActive = false;

  void pemicuAlarmInteraktifForeground(RemoteMessage message) {
    globalRefreshTrigger.value++;

    _playCount = 0;
    _isAlarmActive = true;

    // Putar ulang audio ding_dong lokal maksimal 3 kali (agar berfungsi seperti alarm)
    _audioPlayer.onPlayerComplete.listen((event) {
      if (_isAlarmActive && _playCount < 2) {
        _playCount++;
        _audioPlayer.play(AssetSource('audio/ding_dong.wav'));
      } else {
        _isAlarmActive = false;
      }
    });

    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _audioPlayer.play(AssetSource('audio/ding_dong.wav'));

    // TAMPILKAN DIALOG POP-UP SAAT APLIKASI SEDANG DIBUKA
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text("PANGGILAN ANTREAN", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "${message.notification?.body ?? message.data['body'] ?? 'Giliran Anda! Silakan masuk ke ruangan.'}",
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _isAlarmActive = false;
                _audioPlayer.stop();
                Navigator.pop(context); // Tutup dialog setelah pasien klik
              },
              child: const Text("SAYA MENUJU KE SANA"),
            )
          ],
        ),
      );
    }
  }
}