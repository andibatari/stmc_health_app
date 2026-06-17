import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:stmc_health_app/views/notification/notification_page.dart';

// KUNCI GLOBAL
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ID JADWAL GLOBAL
int? globalActiveJadwalId;
final ValueNotifier<int> globalRefreshTrigger = ValueNotifier<int>(0);

class GlobalNotificationService {
  static final GlobalNotificationService _instance = GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  int _playCount = 0;
  bool _isAlarmActive = false;
  bool _isInitialized = false;

  Future<void> initPusher() async {
    if (_isInitialized) return;

    try {
      _audioPlayer.onPlayerComplete.listen((event) {
        if (_isAlarmActive && _playCount < 2) {
          _playCount++;
          _audioPlayer.play(AssetSource('audio/ding-dong.wav'));
        } else {
          _isAlarmActive = false;
        }
      });

      await _pusher.init(
        apiKey: "c04c6e0bc13266555594",
        cluster: "ap1",
        onEvent: _onPusherEvent,
      );
      await _pusher.subscribe(channelName: 'mcu-channel');
      await _pusher.connect();
      _isInitialized = true;
      debugPrint("✅ Global Pusher Berhasil Terhubung!");
    } catch (e) {
      debugPrint("❌ ERROR PUSHER: $e");
    }
  }

  void _onPusherEvent(PusherEvent event) {
    debugPrint("PUSHER EVENT DITERIMA: ${event.eventName}");
    debugPrint("DATA: ${event.data}");

    if (event.eventName == 'PanggilPasienEvent' || event.eventName == '.PanggilPasienEvent') {
      try {
        Map<String, dynamic> data = jsonDecode(event.data.toString());

        debugPrint("EVENT ID: ${data['jadwalId']} | GLOBAL ID: $globalActiveJadwalId");
        globalRefreshTrigger.value++;

        if (globalActiveJadwalId != null && data['jadwalId'].toString() == globalActiveJadwalId.toString()) {
          _playCount = 0;
          _isAlarmActive = true;
          _audioPlayer.setReleaseMode(ReleaseMode.release);
          _audioPlayer.play(AssetSource('audio/ding-dong.wav'));

          // 🌟 PERBAIKAN: Format notifikasi baru disesuaikan dengan standar Brankas Anti-Duplikat
          final newNotif = {
            'messageId': 'pusher_${DateTime.now().millisecondsSinceEpoch}', // ID unik buatan sendiri
            'title': 'Panggilan Pemeriksaan',
            'body': 'Giliran Anda! Silakan segera masuk ke ruangan ${data['namaPoli']}.',
            'action_link': '',
            'recipient_sap': activeUserIdentifier ?? 'ALL', // Ambil dari notification_page.dart
            'time': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          };

          // 🌟 Panggil fungsi khusus untuk notifikasi lokal/Pusher
          NotificationManager.saveLocalNotification(newNotif);

          // MUNCULKAN POP-UP SECARA GLOBAL
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
                    Text("PANGGILAN", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  "Giliran Anda!\nSilakan segera masuk ke ruangan ${data['namaPoli']}.",
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
                      Navigator.pop(context); // Tutup dialog
                    },
                    child: const Text("SAYA MENUJU KE SANA"),
                  )
                ],
              ),
            );
          }
        } else {
          debugPrint("⚠️ ID tidak cocok, alarm dan pop-up khusus tidak dibunyikan.");
        }
      } catch (e) {
        debugPrint("Error parse Pusher data: $e");
      }
    }

    if (event.eventName == 'StatusPoliUpdatedEvent' || event.eventName == '.StatusPoliUpdatedEvent') {
      try {
        Map<String, dynamic> data = jsonDecode(event.data.toString());
        int updatedJadwalId = int.parse(data['jadwalId'].toString());

        debugPrint("Sinyal Update Status Diterima untuk Jadwal ID: $updatedJadwalId");
        globalRefreshTrigger.value++;
      } catch (e) {
        debugPrint("Error parse StatusPoliUpdatedEvent: $e");
      }
    }
  }
}